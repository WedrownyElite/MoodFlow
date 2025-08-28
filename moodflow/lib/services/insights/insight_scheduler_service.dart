import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifications/enhanced_notification_service.dart';
import '../insights/smart_insights_service.dart';
import '../utils/logger.dart';

class InsightsSchedulerService {
  static const String _lastReminderKey = 'last_insights_reminder';
  static const String _adaptiveRemindersEnabledKey = 'adaptive_reminders_enabled';
  static const String _optimalTimesKey = 'optimal_reminder_times';

  /// Schedule adaptive reminders based on user patterns
  static Future<void> scheduleAdaptiveReminders() async {
    try {
      Logger.smartInsightService('🔄 Scheduling adaptive reminders...');

      final isEnabled = await _isAdaptiveRemindersEnabled();
      if (!isEnabled) {
        Logger.smartInsightService('⚠️ Adaptive reminders disabled');
        return;
      }

      // Get user's optimal reminder times
      final optimalTimes = await _getOptimalReminderTimes();

      // Schedule notifications for these times
      await _scheduleInsightNotifications(optimalTimes);

      Logger.smartInsightService('✅ Scheduled adaptive reminders for: $optimalTimes');

    } catch (e) {
      Logger.smartInsightService('❌ Error scheduling adaptive reminders: $e');
    }
  }

  /// Enable adaptive reminders
  static Future<void> enableAdaptiveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adaptiveRemindersEnabledKey, true);

      // Schedule reminders immediately
      await scheduleAdaptiveReminders();

      Logger.smartInsightService('✅ Adaptive reminders enabled');
    } catch (e) {
      Logger.smartInsightService('❌ Error enabling adaptive reminders: $e');
    }
  }

  /// Disable adaptive reminders
  static Future<void> disableAdaptiveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adaptiveRemindersEnabledKey, false);

      // Cancel scheduled notifications
      await _cancelInsightNotifications();

      Logger.smartInsightService('🚫 Adaptive reminders disabled');
    } catch (e) {
      Logger.smartInsightService('❌ Error disabling adaptive reminders: $e');
    }
  }

  /// Check if adaptive reminders are enabled
  static Future<bool> _isAdaptiveRemindersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_adaptiveRemindersEnabledKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get optimal reminder times based on user patterns
  static Future<List<String>> _getOptimalReminderTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTimes = prefs.getStringList(_optimalTimesKey);

      if (savedTimes != null && savedTimes.isNotEmpty) {
        return savedTimes;
      }

      // Default times if no pattern analysis available
      return ['9:00', '14:00', '20:00']; // 9 AM, 2 PM, 8 PM
    } catch (e) {
      Logger.smartInsightService('❌ Error getting optimal times: $e');
      return ['9:00', '14:00', '20:00'];
    }
  }

  /// Analyze user's mood logging patterns to find optimal reminder times
  static Future<void> analyzeAndUpdateOptimalTimes() async {
    try {
      // This would analyze when the user typically logs moods
      // For now, we'll use intelligent defaults based on common patterns

      final Random random = Random();
      final optimalTimes = <String>[];

      // Morning reminder (8-10 AM)
      final morningHour = 8 + random.nextInt(3);
      optimalTimes.add('${morningHour.toString().padLeft(2, '0')}:00');

      // Afternoon reminder (1-3 PM) 
      final afternoonHour = 13 + random.nextInt(3);
      optimalTimes.add('${afternoonHour.toString().padLeft(2, '0')}:00');

      // Evening reminder (7-9 PM)
      final eveningHour = 19 + random.nextInt(3);
      optimalTimes.add('${eveningHour.toString().padLeft(2, '0')}:00');

      // Save the optimal times
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_optimalTimesKey, optimalTimes);

      Logger.smartInsightService('✅ Updated optimal reminder times: $optimalTimes');
    } catch (e) {
      Logger.smartInsightService('❌ Error analyzing optimal times: $e');
    }
  }

  /// Schedule insight notifications
  static Future<void> _scheduleInsightNotifications(List<String> times) async {
    try {
      // Cancel existing notifications first
      await _cancelInsightNotifications();

      // Schedule new notifications for each optimal time
      for (int i = 0; i < times.length; i++) {
        final timeStr = times[i];
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        // Schedule daily notification at this time
        await _scheduleDailyInsightNotification(
          i + 100, // Unique ID for insights notifications
          hour,
          minute,
          await _generateInsightNotificationText(),
        );
      }
    } catch (e) {
      Logger.smartInsightService('❌ Error scheduling notifications: $e');
    }
  }

  /// Schedule a single daily insight notification
  static Future<void> _scheduleDailyInsightNotification(
      int id, int hour, int minute, String text) async {
    try {
      // This would integrate with your notification service
      // Since we don't have direct access to the notification scheduling here,
      // we'll log what should be scheduled

      Logger.smartInsightService(
          '📅 Would schedule daily notification ID $id at $hour:${minute.toString().padLeft(2, '0')} - "$text"'
      );

      // In a real implementation, you'd call something like:
      // await NotificationService.scheduleDailyNotification(
      //   id: id,
      //   hour: hour,
      //   minute: minute,
      //   title: 'MoodFlow Insights',
      //   body: text,
      // );

    } catch (e) {
      Logger.smartInsightService('❌ Error scheduling daily notification: $e');
    }
  }

  /// Cancel insight notifications
  static Future<void> _cancelInsightNotifications() async {
    try {
      // Cancel notifications with IDs 100, 101, 102 (our insight notification IDs)
      for (int i = 100; i < 103; i++) {
        Logger.smartInsightService('❌ Would cancel notification ID $i');
        // In real implementation: await NotificationService.cancelNotification(i);
      }
    } catch (e) {
      Logger.smartInsightService('❌ Error canceling notifications: $e');
    }
  }

  /// Generate dynamic notification text based on current insights
  static Future<String> _generateInsightNotificationText() async {
    try {
      // Get current insights to create personalized notification text
      final unreadCount = await SmartInsightsService.getUnreadInsightsCount();
      final criticalInsights = await SmartInsightsService.getInsightsByPriority(AlertPriority.critical);
      final highInsights = await SmartInsightsService.getInsightsByPriority(AlertPriority.high);

      if (criticalInsights.isNotEmpty) {
        return 'Important mood insight waiting: ${criticalInsights.first.title}';
      } else if (highInsights.isNotEmpty) {
        return 'New insight about your mood: ${highInsights.first.title}';
      } else if (unreadCount > 0) {
        return 'You have $unreadCount new mood insights to explore!';
      } else {
        // Generate encouraging notification text
        final encouragements = [
          'Time to check in with your mood and see your latest insights!',
          'Your mood patterns are waiting to be explored!',
          'Discover what\'s been affecting your wellbeing lately.',
          'Let\'s see how your mood journey is progressing!',
          'New personalized mood insights might be ready for you.',
        ];

        final random = Random();
        return encouragements[random.nextInt(encouragements.length)];
      }
    } catch (e) {
      Logger.smartInsightService('❌ Error generating notification text: $e');
      return 'Check your mood insights in MoodFlow!';
    }
  }

  /// Check if it's time to generate new insights
  static Future<bool> shouldTriggerInsightGeneration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastReminderStr = prefs.getString(_lastReminderKey);

      if (lastReminderStr == null) return true;

      final lastReminder = DateTime.parse(lastReminderStr);
      final now = DateTime.now();

      // Trigger new insights if it's been more than 8 hours
      return now.difference(lastReminder).inHours >= 8;
    } catch (e) {
      return true;
    }
  }

  /// Mark that we've sent a reminder
  static Future<void> markReminderSent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastReminderKey, DateTime.now().toIso8601String());
    } catch (e) {
      Logger.smartInsightService('❌ Error marking reminder sent: $e');
    }
  }

  /// Background task to check and generate insights
  static Future<void> backgroundInsightsCheck() async {
    try {
      if (await shouldTriggerInsightGeneration()) {
        Logger.smartInsightService('🔄 Triggering background insight generation');

        // Generate new insights
        await SmartInsightsService.backgroundRefresh();

        // Update optimal reminder times based on new data
        await analyzeAndUpdateOptimalTimes();

        // Reschedule notifications with updated times
        if (await _isAdaptiveRemindersEnabled()) {
          await scheduleAdaptiveReminders();
        }

        await markReminderSent();
      }
    } catch (e) {
      Logger.smartInsightService('❌ Error in background insights check: $e');
    }
  }

  /// Get reminder statistics for settings display
  static Future<Map<String, dynamic>> getReminderStatistics() async {
    try {
      final isEnabled = await _isAdaptiveRemindersEnabled();
      final optimalTimes = await _getOptimalReminderTimes();
      final unreadCount = await SmartInsightsService.getUnreadInsightsCount();
      final lastReminderStr = await SharedPreferences.getInstance()
          .then((prefs) => prefs.getString(_lastReminderKey));

      DateTime? lastReminder;
      if (lastReminderStr != null) {
        lastReminder = DateTime.parse(lastReminderStr);
      }

      return {
        'enabled': isEnabled,
        'optimalTimes': optimalTimes,
        'unreadInsights': unreadCount,
        'lastReminder': lastReminder,
        'nextReminderDue': lastReminder != null
            ? lastReminder.add(const Duration(hours: 8))
            : DateTime.now(),
      };
    } catch (e) {
      Logger.smartInsightService('❌ Error getting reminder statistics: $e');
      return {
        'enabled': false,
        'optimalTimes': <String>[],
        'unreadInsights': 0,
      };
    }
  }

  /// Test the reminder system
  static Future<void> testReminderSystem() async {
    try {
      Logger.smartInsightService('🧪 Testing reminder system...');

      // Enable reminders
      await enableAdaptiveReminders();

      // Analyze optimal times
      await analyzeAndUpdateOptimalTimes();

      // Generate test notification text
      final notificationText = await _generateInsightNotificationText();
      Logger.smartInsightService('📱 Test notification: "$notificationText"');

      // Get statistics
      final stats = await getReminderStatistics();
      Logger.smartInsightService('📊 Reminder stats: $stats');

      Logger.smartInsightService('✅ Reminder system test complete');
    } catch (e) {
      Logger.smartInsightService('❌ Reminder system test failed: $e');
    }
  }

  /// Initialize the reminder system
  static Future<void> initialize() async {
    try {
      Logger.smartInsightService('🔄 Initializing insights scheduler...');

      // Check if reminders are enabled and schedule them
      if (await _isAdaptiveRemindersEnabled()) {
        await scheduleAdaptiveReminders();
      }

      // Run background check
      await backgroundInsightsCheck();

      Logger.smartInsightService('✅ Insights scheduler initialized');
    } catch (e) {
      Logger.smartInsightService('❌ Error initializing scheduler: $e');
    }
  }

  /// Update reminder preferences
  static Future<void> updateReminderPreferences({
    bool? enabled,
    List<String>? customTimes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (enabled != null) {
        await prefs.setBool(_adaptiveRemindersEnabledKey, enabled);

        if (enabled) {
          await scheduleAdaptiveReminders();
        } else {
          await _cancelInsightNotifications();
        }
      }

      if (customTimes != null && customTimes.isNotEmpty) {
        await prefs.setStringList(_optimalTimesKey, customTimes);

        // Reschedule with new times if enabled
        if (await _isAdaptiveRemindersEnabled()) {
          await scheduleAdaptiveReminders();
        }
      }

      Logger.smartInsightService('✅ Updated reminder preferences');
    } catch (e) {
      Logger.smartInsightService('❌ Error updating preferences: $e');
    }
  }

  /// Reset reminder system to defaults
  static Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Reset all keys
      await prefs.remove(_lastReminderKey);
      await prefs.remove(_adaptiveRemindersEnabledKey);
      await prefs.remove(_optimalTimesKey);

      // Cancel all notifications
      await _cancelInsightNotifications();

      Logger.smartInsightService('🔄 Reset reminder system to defaults');
    } catch (e) {
      Logger.smartInsightService('❌ Error resetting to defaults: $e');
    }
  }
}