import 'package:home_widget/home_widget.dart';
import '../data/mood_data_service.dart';
import '../notifications/enhanced_notification_service.dart';
import '../utils/logger.dart';

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

      // Get today's mood data
      final morningMood = await MoodDataService.loadMood(today, 0);
      final middayMood = await MoodDataService.loadMood(today, 1);
      final eveningMood = await MoodDataService.loadMood(today, 2);

      // Calculate completion status
      final completedSegments = [
        morningMood?['rating'] != null,
        middayMood?['rating'] != null,
        eveningMood?['rating'] != null,
      ];

      final completionCount = completedSegments.where((c) => c).length;
      final completionPercentage = (completionCount / 3 * 100).round();

      // Get current mood average
      final moods = [
        morningMood?['rating'],
        middayMood?['rating'],
        eveningMood?['rating'],
      ].where((m) => m != null).cast<num>().toList();

      final averageMood = moods.isNotEmpty
          ? moods.reduce((a, b) => a + b) / moods.length
          : 0.0;

      // Update widget data
      await HomeWidget.saveWidgetData<String>('current_segment', MoodDataService.timeSegments[currentSegment]);
      await HomeWidget.saveWidgetData<double>('average_mood', averageMood.toDouble());
      await HomeWidget.saveWidgetData<int>('completion_percentage', completionPercentage);
      await HomeWidget.saveWidgetData<bool>('morning_completed', completedSegments[0]);
      await HomeWidget.saveWidgetData<bool>('midday_completed', completedSegments[1]);
      await HomeWidget.saveWidgetData<bool>('evening_completed', completedSegments[2]);
      await HomeWidget.saveWidgetData<bool>('can_log_current', await _canLogCurrentSegment(currentSegment));

      // Update the actual widget
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'MoodFlowWidgetProvider',
        iOSName: 'MoodFlowWidget',
      );

      Logger.moodService('✅ Widget updated: $completionPercentage% complete, avg mood: ${averageMood.toStringAsFixed(1)}');
    } catch (e) {
      Logger.moodService('❌ Widget update failed: $e');
    }
  }

  /// Handle widget interactions
  static Future<void> handleWidgetInteraction(String? action) async {
    if (action == null) return;

    try {
      Logger.moodService('📱 Widget interaction: $action');

      switch (action) {
        case 'quick_mood_1':
        case 'quick_mood_2':
        case 'quick_mood_3':
        case 'quick_mood_4':
        case 'quick_mood_5':
          final rating = double.parse(action.split('_').last) * 2; // Convert 1-5 to 2-10
          await _logQuickMood(rating);
          break;
        case 'open_app':
        // This will be handled by the main app when it opens
          break;
      }
    } catch (e) {
      Logger.moodService('❌ Widget interaction failed: $e');
    }
  }

  /// Log a quick mood from widget
  static Future<void> _logQuickMood(double rating) async {
    try {
      final today = DateTime.now();
      final currentSegment = await _getCurrentTimeSegment();

      if (!await _canLogCurrentSegment(currentSegment)) {
        Logger.moodService('⚠️ Cannot log mood for current segment');
        return;
      }

      // Save the mood with a note indicating it was from widget
      await MoodDataService.saveMood(
          today,
          currentSegment,
          rating,
          'Quick check-in via widget'
      );

      // Update widget to reflect the change
      await updateWidget();

      // Show success notification
      await _showSuccessNotification(rating);

      Logger.moodService('✅ Quick mood logged: $rating for segment $currentSegment');
    } catch (e) {
      Logger.moodService('❌ Quick mood logging failed: $e');
    }
  }

  /// Show success notification after logging mood
  static Future<void> _showSuccessNotification(double rating) async {
    try {
      final moodEmoji = _getMoodEmoji(rating);
      Logger.moodService('✅ Mood logged successfully: $moodEmoji ${rating.toStringAsFixed(1)}/10');

    } catch (e) {
      Logger.moodService('❌ Success notification failed: $e');
    }
  }

  /// Get appropriate emoji for mood rating
  static String _getMoodEmoji(double rating) {
    if (rating >= 8) return '😊';
    if (rating >= 6) return '🙂';
    if (rating >= 4) return '😐';
    if (rating >= 2) return '🙁';
    return '😢';
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
}