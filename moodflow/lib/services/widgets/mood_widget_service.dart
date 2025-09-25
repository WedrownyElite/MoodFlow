import 'package:home_widget/home_widget.dart';
import '../data/mood_data_service.dart';
import '../notifications/enhanced_notification_service.dart';
import '../utils/logger.dart';
import '../navigation_service.dart';
import '../backup/cloud_backup_service.dart';

class MoodWidgetService {
  static const String _widgetName = 'MoodFlowWidget';
  static const String _groupId = 'group.com.oddologyinc.moodflow';

  /// Initialize widget functionality
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_groupId);

      // Set up periodic checks for pending widget moods
      _startPeriodicMoodCheck();

      Logger.moodService('✅ Enhanced widget service initialized');
    } catch (e) {
      Logger.moodService('❌ Widget initialization failed: $e');
    }
  }

  /// Update widget with current mood data and segment information
  static Future<void> updateWidget() async {
    try {
      final today = DateTime.now();
      final currentSegment = await _getCurrentTimeSegment();

      // Get today's mood data for current segment
      final currentSegmentMood = await MoodDataService.loadMood(today, currentSegment);

      // Update widget data
      await HomeWidget.saveWidgetData<int>('current_segment_index', currentSegment);
      await HomeWidget.saveWidgetData<bool>('can_log_current', await _canLogCurrentSegment(currentSegment));

      // Save mood selection state for current segment
      if (currentSegmentMood?['rating'] != null) {
        final rating = (currentSegmentMood!['rating'] as num).toDouble();
        final moodIndex = _convertRatingToMoodIndex(rating);
        await HomeWidget.saveWidgetData<int>('selected_mood_$currentSegment', moodIndex);
      } else {
        await HomeWidget.saveWidgetData<int>('selected_mood_$currentSegment', -1);
      }

      // Update the actual widget
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'MoodFlowWidgetProvider',
        iOSName: 'MoodFlowWidget',
      );

      Logger.moodService('✅ Widget updated: segment=$currentSegment, accessible=${await _canLogCurrentSegment(currentSegment)}');
    } catch (e) {
      Logger.moodService('❌ Widget update failed: $e');
    }
  }

  /// Handle widget interactions
  static Future<void> handleWidgetInteraction(String? action) async {
    if (action == null) return;

    try {
      Logger.moodService('📱 Widget interaction: $action');

      // Handle mood selections (these shouldn't open the app)
      if (action.startsWith('mood_') && action.contains('_segment_')) {
        final parts = action.split('_');
        if (parts.length >= 4) {
          final moodIndex = int.tryParse(parts[1]);
          final segment = int.tryParse(parts[3]);

          if (moodIndex != null && segment != null && moodIndex >= 1 && moodIndex <= 5) {
            await _handleBackgroundMoodSelection(moodIndex, segment);
          }
        }
      }
      // Handle "Open App" button - this SHOULD open the app
      else if (action == 'open_mood_log' || action == 'open_app') {
        final currentSegment = await _getCurrentTimeSegment();

        // Navigate to mood log for current segment
        await NavigationService.navigateToMoodLog(
          segment: currentSegment,
        );

        NavigationService.showNotificationTapInfo('widget');
      }
    } catch (e) {
      Logger.moodService('❌ Widget interaction failed: $e');
    }
  }

  /// Handle background mood selection (saves mood without opening app)
  static Future<void> _handleBackgroundMoodSelection(int moodIndex, int segment) async {
    try {
      final rating = _convertMoodIndexToRating(moodIndex);
      final today = DateTime.now();

      // Check if this segment is accessible
      if (!await _canLogCurrentSegment(segment)) {
        Logger.moodService('⚠️ Attempted to log mood for inaccessible segment: $segment');
        return;
      }

      // Save the mood data with a note indicating it came from widget
      final success = await MoodDataService.saveMood(
          today,
          segment,
          rating,
          'Quick mood from widget'
      );

      if (success) {
        Logger.moodService('✅ Background mood saved from widget: $rating for segment $segment');

        // Update widget to show the new selection
        await updateWidget();

        // Trigger cloud backup if enabled
        await _triggerCloudBackupIfEnabled();
      } else {
        Logger.moodService('❌ Failed to save background mood from widget');
      }
    } catch (e) {
      Logger.moodService('❌ Background mood selection failed: $e');
    }
  }

  /// Start periodic check for pending widget moods (in case app wasn't running)
  static void _startPeriodicMoodCheck() {
    // Check every 30 seconds for pending moods when app is active
    Stream.periodic(const Duration(seconds: 30)).listen((_) async {
      await _checkForPendingWidgetMoods();
    });
  }

  /// Check for pending widget moods and process them
  static Future<void> _checkForPendingWidgetMoods() async {
    try {
      // Check if there are pending widget moods to process
      final pendingMoods = await _getPendingWidgetMoods();

      for (final moodData in pendingMoods) {
        await _processPendingMood(moodData);
      }

      if (pendingMoods.isNotEmpty) {
        // Clear pending flag
        await HomeWidget.saveWidgetData<bool>('widget_mood_pending', false);

        // Update widget to reflect changes
        await updateWidget();
      }
    } catch (e) {
      Logger.moodService('❌ Pending mood check failed: $e');
    }
  }

  /// Get pending widget moods from SharedPreferences
  static Future<List<Map<String, dynamic>>> _getPendingWidgetMoods() async {
    try {
      final isPending = await HomeWidget.getWidgetData<bool>('widget_mood_pending') ?? false;

      if (!isPending) return [];

      final segment = await HomeWidget.getWidgetData<int>('widget_mood_segment') ?? 0;
      final rating = await HomeWidget.getWidgetData<double>('widget_mood_rating_$segment') ?? 6.0;
      final timestamp = await HomeWidget.getWidgetData<int>('widget_mood_timestamp') ?? DateTime.now().millisecondsSinceEpoch;

      return [{
        'segment': segment,
        'rating': rating,
        'timestamp': timestamp,
      }];
    } catch (e) {
      Logger.moodService('❌ Error getting pending moods: $e');
      return [];
    }
  }

  /// Process a pending mood selection
  static Future<void> _processPendingMood(Map<String, dynamic> moodData) async {
    try {
      final segment = moodData['segment'] as int;
      final rating = moodData['rating'] as double;
      final timestamp = moodData['timestamp'] as int;

      final moodDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final today = DateTime.now();

      // Only process if it's for today
      if (moodDate.day == today.day && moodDate.month == today.month && moodDate.year == today.year) {
        final success = await MoodDataService.saveMood(
            today,
            segment,
            rating,
            'Quick mood from widget (processed)'
        );

        if (success) {
          Logger.moodService('✅ Processed pending widget mood: $rating for segment $segment');
        }
      }
    } catch (e) {
      Logger.moodService('❌ Error processing pending mood: $e');
    }
  }

  /// Get current time segment based on notification settings
  static Future<int> _getCurrentTimeSegment() async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final eveningMinutes = settings.eveningTime.hour * 60 + settings.eveningTime.minute;
    final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;

    // Return the highest accessible segment
    if (currentMinutes >= eveningMinutes) return 2; // Evening
    if (currentMinutes >= middayMinutes) return 1; // Midday
    return 0; // Morning
  }

  /// Check if user can log mood for specific segment
  static Future<bool> _canLogCurrentSegment(int segment) async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    switch (segment) {
      case 0:
        return true; // Morning always available
      case 1:
        final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;
        return currentMinutes >= middayMinutes;
      case 2:
        final eveningMinutes = settings.eveningTime.hour * 60 + settings.eveningTime.minute;
        return currentMinutes >= eveningMinutes;
      default:
        return false;
    }
  }

  /// Convert mood index (1-5) to rating (2-10) with good distribution
  static double _convertMoodIndexToRating(int moodIndex) {
    switch (moodIndex) {
      case 1: return 2.0;  // 😢 Very bad
      case 2: return 4.0;  // 🙁 Bad
      case 3: return 6.0;  // 😐 Neutral
      case 4: return 8.0;  // 🙂 Good
      case 5: return 10.0; // 😊 Very good
      default: return 6.0; // Default to neutral
    }
  }

  /// Convert rating (2-10) back to mood index (1-5) for widget display
  static int _convertRatingToMoodIndex(double rating) {
    if (rating <= 3.0) return 1; // Very bad
    if (rating <= 5.0) return 2; // Bad
    if (rating <= 7.0) return 3; // Neutral
    if (rating <= 9.0) return 4; // Good
    return 5; // Very good
  }

  /// Trigger cloud backup if enabled
  static Future<void> _triggerCloudBackupIfEnabled() async {
    try {
      final isEnabled = await RealCloudBackupService.isAutoBackupEnabled();
      final isAvailable = await RealCloudBackupService.isCloudBackupAvailable();

      if (isEnabled && isAvailable) {
        RealCloudBackupService.triggerBackupIfNeeded();
        Logger.moodService('☁️ Cloud backup triggered after widget mood save');
      }
    } catch (e) {
      Logger.moodService('❌ Cloud backup trigger failed: $e');
    }
  }

  /// Get widget analytics data
  static Future<Map<String, dynamic>> getWidgetAnalytics() async {
    try {
      final today = DateTime.now();
      int quickMoodsToday = 0;

      // Count moods logged today with widget note
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(today, segment);
        if (mood?['note']?.contains('widget') == true) {
          quickMoodsToday++;
        }
      }

      return {
        'quick_moods_logged_today': quickMoodsToday,
        'current_segment': await _getCurrentTimeSegment(),
        'segments_accessible': [
          await _canLogCurrentSegment(0),
          await _canLogCurrentSegment(1),
          await _canLogCurrentSegment(2),
        ],
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      Logger.moodService('❌ Widget analytics failed: $e');
      return {};
    }
  }
}