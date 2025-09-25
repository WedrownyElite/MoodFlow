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
      Logger.moodService('✅ Widget service initialized');
    } catch (e) {
      Logger.moodService('❌ Widget initialization failed: $e');
    }
  }

  /// Update widget with current mood data
  static Future<void> updateWidget() async {
    try {
      final today = DateTime.now();
      final currentSegment = await _getCurrentTimeSegment();

      // Get today's mood data for all segments
      final segmentMoods = <int, Map<String, dynamic>?>{};
      for (int i = 0; i < 3; i++) {
        segmentMoods[i] = await MoodDataService.loadMood(today, i);
      }

      // Calculate completion status
      final completedSegments = [
        segmentMoods[0]?['rating'] != null,
        segmentMoods[1]?['rating'] != null,
        segmentMoods[2]?['rating'] != null,
      ];

      final completionCount = completedSegments.where((c) => c).length;
      final completionPercentage = (completionCount / 3 * 100).round();

      // Update widget data
      await HomeWidget.saveWidgetData<int>('current_segment_index', currentSegment);
      await HomeWidget.saveWidgetData<String>('current_segment', MoodDataService.timeSegments[currentSegment]);
      await HomeWidget.saveWidgetData<int>('completion_percentage', completionPercentage);
      await HomeWidget.saveWidgetData<bool>('can_log_current', await _canLogCurrentSegment(currentSegment));

      // Save mood data for each segment
      for (int i = 0; i < 3; i++) {
        final mood = segmentMoods[i];
        if (mood?['rating'] != null) {
          final rating = (mood!['rating'] as num).toDouble();
          final moodIndex = _convertRatingToMoodIndex(rating);
          await HomeWidget.saveWidgetData<int>('selected_mood_$i', moodIndex);
        } else {
          await HomeWidget.saveWidgetData<int>('selected_mood_$i', -1);
        }
      }

      // Update the actual widget
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'MoodFlowWidgetProvider',
        iOSName: 'MoodFlowWidget',
      );

      Logger.moodService('✅ Widget updated: segment=$currentSegment, completion=$completionPercentage%');
    } catch (e) {
      Logger.moodService('❌ Widget update failed: $e');
    }
  }

  /// Handle widget interactions - Updated for multi-segment support
  static Future<void> handleWidgetInteraction(String? action) async {
    if (action == null) return;

    try {
      Logger.moodService('📱 Widget interaction: $action');

      if (action.startsWith('mood_') && action.contains('_segment_')) {
        // Parse mood and segment from action like "mood_3_segment_1"
        final parts = action.split('_');
        if (parts.length >= 4) {
          final moodIndex = int.tryParse(parts[1]);
          final segment = int.tryParse(parts[3]);

          if (moodIndex != null && segment != null && moodIndex >= 1 && moodIndex <= 5) {
            await _handleMoodSelection(moodIndex, segment);
          }
        }
      } else if (action == 'swipe_left') {
        await _handleSwipeLeft();
      } else if (action == 'swipe_right') {
        await _handleSwipeRight();
      } else if (action == 'open_mood_log') {
        final currentSegment = await _getCurrentTimeSegment();
        NavigationService.navigateToMoodLogWithRating(
          segment: currentSegment,
          preSelectedRating: 6.0, // Default neutral
        );
      } else if (action == 'open_app') {
        NavigationService.navigateToHome();
      }
    } catch (e) {
      Logger.moodService('❌ Widget interaction failed: $e');
    }
  }

  /// Convert mood index (1-5) to rating (2-10) for better distribution
  static double _convertMoodIndexToRating(int moodIndex) {
    // Map 1-5 to 2-10 with better spacing:
    // 1 (😢) -> 2.0 (Very bad)
    // 2 (🙁) -> 4.0 (Bad) 
    // 3 (😐) -> 6.0 (Neutral)
    // 4 (🙂) -> 8.0 (Good)
    // 5 (😊) -> 10.0 (Very good)
    switch (moodIndex) {
      case 1: return 2.0;
      case 2: return 4.0;
      case 3: return 6.0;
      case 4: return 8.0;
      case 5: return 10.0;
      default: return 6.0; // Default to neutral
    }
  }
  
  /// Get current time segment based on notification settings
  static Future<int> _getCurrentTimeSegment() async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final eveningMinutes = settings.eveningTime.hour * 60 + settings.eveningTime.minute;
    final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;

    if (currentMinutes >= eveningMinutes) return 2; // Evening
    if (currentMinutes >= middayMinutes) return 1; // Midday
    return 0; // Morning
  }

  /// Check if user can log mood for current segment
  static Future<bool> _canLogCurrentSegment(int segment) async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    switch (segment) {
      case 0: return true; // Morning always available
      case 1:
        final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;
        return currentMinutes >= middayMinutes;
      case 2:
        final eveningMinutes = settings.eveningTime.hour * 60 + settings.eveningTime.minute;
        return currentMinutes >= eveningMinutes;
      default: return false;
    }
  }

  /// Schedule daily widget updates
  static Future<void> scheduleDailyUpdates() async {
    try {
      // Widget updates are handled by the system and manual triggers
      // Future enhancement: Could use flutter_local_notifications for periodic updates
      Logger.moodService('📅 Widget updates available on-demand');
    } catch (e) {
      Logger.moodService('❌ Widget scheduling failed: $e');
    }
  }

  /// Get widget analytics data
  static Future<Map<String, dynamic>> getWidgetAnalytics() async {
    try {
      // Track widget usage for insights
      return {
        'widget_interactions_today': 0, // Implement tracking
        'quick_moods_logged': 0,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      Logger.moodService('❌ Widget analytics failed: $e');
      return {};
    }
  }

  /// Handle mood selection for specific segment
  static Future<void> _handleMoodSelection(int moodIndex, int segment) async {
    try {
      final rating = _convertMoodIndexToRating(moodIndex);
      final today = DateTime.now();

      // Save the mood data
      final success = await MoodDataService.saveMood(today, segment, rating, 'Quick mood from widget');

      if (success) {
        Logger.moodService('✅ Mood saved from widget: $rating for segment $segment');

        // Update widget to show selection
        await updateWidget();

        // Trigger cloud backup if enabled
        await _triggerCloudBackupIfEnabled();
      } else {
        Logger.moodService('❌ Failed to save mood from widget');
      }
    } catch (e) {
      Logger.moodService('❌ Mood selection handling failed: $e');
    }
  }

  /// Handle swipe left (previous segment)
  static Future<void> _handleSwipeLeft() async {
    try {
      final currentSegment = await _getCurrentTimeSegment();
      if (currentSegment > 0) {
        // Update to previous segment and refresh widget
        await _setCurrentWidgetSegment(currentSegment - 1);
      }
    } catch (e) {
      Logger.moodService('❌ Swipe left handling failed: $e');
    }
  }

  /// Handle swipe right (next segment)
  static Future<void> _handleSwipeRight() async {
    try {
      final currentSegment = await _getCurrentTimeSegment();
      if (currentSegment < 2) {
        // Update to next segment and refresh widget
        await _setCurrentWidgetSegment(currentSegment + 1);
      }
    } catch (e) {
      Logger.moodService('❌ Swipe right handling failed: $e');
    }
  }

  /// Set current widget segment and update display
  static Future<void> _setCurrentWidgetSegment(int segment) async {
    try {
      await HomeWidget.saveWidgetData<int>('current_segment_index', segment);
      await updateWidget();
      Logger.moodService('📱 Widget swiped to segment: $segment');
    } catch (e) {
      Logger.moodService('❌ Set widget segment failed: $e');
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
      // Import the cloud backup service
      // Note: You may need to add this import at the top of the file:
      // import '../backup/cloud_backup_service.dart';

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
}