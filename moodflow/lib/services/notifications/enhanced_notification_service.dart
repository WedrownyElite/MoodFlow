import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as notifications;
import 'personalized_notification_generator.dart';
import 'real_notification_service.dart';
import '../data/mood_trends_service.dart';
import '../data/mood_analytics_service.dart';
import '../utils/logger.dart';

class EnhancedNotificationService {
  static const String _settingsKey = 'notification_settings_v2';
  static const String _permissionAskedKey = 'notification_permission_asked';

  /// Initialize the notification system
  static Future<void> initialize() async {
    await RealNotificationService.initialize();
  }

  /// Check if we should ask for notification permission
  static Future<bool> shouldAskForPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool(_permissionAskedKey) ?? false;

    if (hasAsked) return false;

    // Also check if permissions are already granted
    final areEnabled = await RealNotificationService.areNotificationsEnabled();
    return !areEnabled;
  }

  /// Mark that we've asked for permission
  static Future<void> markPermissionAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionAskedKey, true);
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    final granted = await RealNotificationService.requestPermissions();
    await markPermissionAsked();
    return granted;
  }

  /// Save notification settings and update scheduled notifications
  static Future<void> saveSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

    // Update scheduled notifications based on new settings
    await _updateScheduledNotifications(settings);
  }

  /// Load notification settings
  static Future<NotificationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson == null) {
      return NotificationSettings.defaultSettings();
    }

    try {
      final Map<String, dynamic> json = jsonDecode(settingsJson);
      return NotificationSettings.fromJson(json);
    } catch (_) {
      return NotificationSettings.defaultSettings();
    }
  }

  /// Update scheduled notifications based on settings
  static Future<void> _updateScheduledNotifications(
      NotificationSettings settings) async {
    if (!settings.enabled) {
      await RealNotificationService.cancelAllNotifications();
      return;
    }

    await RealNotificationService.cancelAllNotifications();

    // Schedule personalized mood reminders
    if (settings.accessReminders) {
      if (settings.morningAccessReminder) {
        final morningNotification = await PersonalizedNotificationGenerator.generateMorningMessage();
        await RealNotificationService.schedulePersonalizedMoodReminder(
          id: 1001,
          title: morningNotification.title,
          body: morningNotification.body,
          time: NotificationTime(settings.morningTime.hour, settings.morningTime.minute),
          segment: 0,
        );
      }

      if (settings.middayAccessReminder) {
        final middayNotification = await PersonalizedNotificationGenerator.generateMiddayMessage();
        await RealNotificationService.schedulePersonalizedMoodReminder(
          id: 1002,
          title: middayNotification.title,
          body: middayNotification.body,
          time: NotificationTime(settings.middayTime.hour, settings.middayTime.minute),
          segment: 1,
        );
      }

      if (settings.eveningAccessReminder) {
        final eveningNotification = await PersonalizedNotificationGenerator.generateEveningMessage();
        await RealNotificationService.schedulePersonalizedMoodReminder(
          id: 1003,
          title: eveningNotification.title,
          body: eveningNotification.body,
          time: NotificationTime(settings.eveningTime.hour, settings.eveningTime.minute),
          segment: 2,
        );
      }
    }

    // Schedule end-of-day reminder
    if (settings.endOfDayReminder) {
      await RealNotificationService.scheduleEndOfDayReminder(
        enabled: true,
        time: NotificationTime(settings.endOfDayTime.hour, settings.endOfDayTime.minute),
      );
    }

    // Schedule streak preservation notification (1 hour before midnight)
    await _scheduleStreakPreservationCheck();

    // Schedule goal progress notifications
    if (settings.goalProgress) {
      await _scheduleGoalProgressCheck();
    }
  }

  /// Check and schedule streak preservation notification
  static Future<void> _scheduleStreakPreservationCheck() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));
      final trends = await MoodTrendsService.getMoodTrends(
        startDate: startDate,
        endDate: endDate,
      );
      final stats = await MoodTrendsService.calculateStatisticsForDateRange(
        trends,
        startDate,
        endDate,
      );

      if (stats.currentStreak >= 3) {
        // Schedule notification for 11 PM (1 hour before midnight)
        await RealNotificationService.scheduleStreakPreservationNotification(
          currentStreak: stats.currentStreak,
          time: const NotificationTime(23, 0),
        );
      }
    } catch (e) {
      Logger.notificationService('Error scheduling streak preservation: $e');
    }
  }

  /// Check and schedule goal progress notifications
  static Future<void> _scheduleGoalProgressCheck() async {
    try {
      final goals = await MoodAnalyticsService.loadGoals();

      for (final goal in goals) {
        if (!goal.isCompleted) {
          // Calculate progress based on goal type
          int progress = 0;
          int target = goal.targetDays;

          if (goal.type == GoalType.consecutiveDays) {
            final endDate = DateTime.now();
            final startDate = goal.createdDate;
            final trends = await MoodTrendsService.getMoodTrends(
              startDate: startDate,
              endDate: endDate,
            );
            final stats = await MoodTrendsService.calculateStatisticsForDateRange(
              trends,
              startDate,
              endDate,
            );
            progress = stats.currentStreak;
          } else {
            progress = goal.targetDays ~/ 2; // Placeholder calculation
          }

          final percentage = (progress / target * 100).round();

          // Only schedule if meaningful progress (25%, 50%, 75%, 90%)
          if (percentage >= 25 && percentage % 25 == 0 || percentage >= 90) {
            await RealNotificationService.scheduleGoalProgressNotification(
              goalTitle: goal.title,
              progress: progress,
              target: target,
              time: const NotificationTime(18, 0), // 6 PM by default
            );
          }
        }
      }
    } catch (e) {
      Logger.notificationService('Error scheduling goal progress: $e');
    }
  }

  /// Show a test notification
  static Future<void> showTestNotification() async {
    await RealNotificationService.showTestNotification();
  }

  /// Get real pending notifications from the system
  static Future<List<notifications.PendingNotificationRequest>>
      getSystemPendingNotifications() async {
    return await RealNotificationService.getPendingNotifications();
  }
}

// Keep the same classes as before...
class NotificationSettings {
  final bool enabled;
  final bool accessReminders;
  final bool morningAccessReminder;
  final bool middayAccessReminder;
  final bool eveningAccessReminder;
  final bool endOfDayReminder;
  final TimeOfDay morningTime;
  final TimeOfDay middayTime;
  final TimeOfDay eveningTime;
  final TimeOfDay endOfDayTime;
  final bool goalReminders;
  final bool goalProgress;
  final bool goalEncouragement;
  final bool streakCelebrations;
  final bool correlationNotifications;
  final bool smartInsightNotifications;

  NotificationSettings({
    required this.enabled,
    required this.accessReminders,
    required this.morningAccessReminder,
    required this.middayAccessReminder,
    required this.eveningAccessReminder,
    required this.endOfDayReminder,
    required this.morningTime,
    required this.middayTime,
    required this.eveningTime,
    required this.endOfDayTime,
    required this.goalReminders,
    required this.goalProgress,
    required this.goalEncouragement,
    required this.streakCelebrations,
    required this.correlationNotifications,
    required this.smartInsightNotifications,
  });

  static NotificationSettings defaultSettings() {
    return NotificationSettings(
      enabled: true,
      accessReminders: true,
      morningAccessReminder: true,
      middayAccessReminder: true,
      eveningAccessReminder: true,
      endOfDayReminder: true,
      endOfDayTime: const TimeOfDay(hour: 23, minute: 0),
      morningTime: const TimeOfDay(hour: 9, minute: 0),
      middayTime: const TimeOfDay(hour: 13, minute: 0),
      eveningTime: const TimeOfDay(hour: 19, minute: 0),
      goalReminders: true,
      goalProgress: true,
      goalEncouragement: true,
      streakCelebrations: true,
      correlationNotifications: true,
      smartInsightNotifications: true,
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? accessReminders,
    bool? morningAccessReminder,
    bool? middayAccessReminder,
    bool? eveningAccessReminder,
    bool? endOfDayReminder,
    TimeOfDay? endOfDayTime,
    TimeOfDay? morningTime,
    TimeOfDay? middayTime,
    TimeOfDay? eveningTime,
    bool? goalReminders,
    bool? goalProgress,
    bool? goalEncouragement,
    bool? streakCelebrations,
    bool? correlationNotifications,
    bool? smartInsightNotifications,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      accessReminders: accessReminders ?? this.accessReminders,
      morningAccessReminder:
          morningAccessReminder ?? this.morningAccessReminder,
      middayAccessReminder: middayAccessReminder ?? this.middayAccessReminder,
      eveningAccessReminder:
          eveningAccessReminder ?? this.eveningAccessReminder,
      endOfDayReminder: endOfDayReminder ?? this.endOfDayReminder,
      endOfDayTime: endOfDayTime ?? this.endOfDayTime,
      morningTime: morningTime ?? this.morningTime,
      middayTime: middayTime ?? this.middayTime,
      eveningTime: eveningTime ?? this.eveningTime,
      goalReminders: goalReminders ?? this.goalReminders,
      goalProgress: goalProgress ?? this.goalProgress,
      goalEncouragement: goalEncouragement ?? this.goalEncouragement,
      streakCelebrations: streakCelebrations ?? this.streakCelebrations,
      correlationNotifications:
          correlationNotifications ?? this.correlationNotifications,
      smartInsightNotifications:
          smartInsightNotifications ?? this.smartInsightNotifications,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'accessReminders': accessReminders,
      'morningAccessReminder': morningAccessReminder,
      'middayAccessReminder': middayAccessReminder,
      'eveningAccessReminder': eveningAccessReminder,
      'endOfDayReminder': endOfDayReminder,
      'endOfDayTime': '${endOfDayTime.hour}:${endOfDayTime.minute}',
      'morningTime': '${morningTime.hour}:${morningTime.minute}',
      'middayTime': '${middayTime.hour}:${middayTime.minute}',
      'eveningTime': '${eveningTime.hour}:${eveningTime.minute}',
      'goalReminders': goalReminders,
      'goalProgress': goalProgress,
      'goalEncouragement': goalEncouragement,
      'streakCelebrations': streakCelebrations,
      'correlationNotifications': correlationNotifications,
      'smartInsightNotifications': smartInsightNotifications,
    };
  }

  static NotificationSettings fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      accessReminders: json['accessReminders'] ?? true,
      morningAccessReminder: json['morningAccessReminder'] ?? true,
      middayAccessReminder: json['middayAccessReminder'] ?? true,
      eveningAccessReminder: json['eveningAccessReminder'] ?? true,
      endOfDayReminder: json['endOfDayReminder'] ?? true,
      endOfDayTime: parseTime(json['endOfDayTime'] ?? '23:0'),
      morningTime: parseTime(json['morningTime'] ?? '9:0'),
      middayTime: parseTime(json['middayTime'] ?? '13:0'),
      eveningTime: parseTime(json['eveningTime'] ?? '19:0'),
      goalReminders: json['goalReminders'] ?? true,
      goalProgress: json['goalProgress'] ?? true,
      goalEncouragement: json['goalEncouragement'] ?? true,
      streakCelebrations: json['streakCelebrations'] ?? true,
      correlationNotifications: json['correlationNotifications'] ?? true,
      smartInsightNotifications: json['smartInsightNotifications'] ?? true,
    );
  }
}

class NotificationContent {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;

  NotificationContent({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
  });
}

enum NotificationType {
  accessReminder, // "Morning mood logging is now available!"
  endOfDayReminder, // "Don't forget to log your missing moods"
  endOfDayComplete, // "Perfect day of mood tracking!"
  goalProgress, // "Goal Progress Update"
  goalEncouragement, // "Keep working toward your goal!"
  streakCelebration, // "7 day streak!"
}

class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
