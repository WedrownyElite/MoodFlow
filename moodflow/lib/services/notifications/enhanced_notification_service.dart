import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifications;
import 'real_notification_service.dart';

class EnhancedNotificationService {
  static const String _settingsKey = 'notification_settings_v2';
  static const String _permissionAskedKey = 'notification_permission_asked';
  static const String _lastNotificationKey = 'last_notification_date';

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
  static Future<void> _updateScheduledNotifications(NotificationSettings settings) async {
    if (!settings.enabled) {
      // Cancel all notifications if disabled
      await RealNotificationService.cancelAllNotifications();
      return;
    }

    // Cancel existing notifications first
    await RealNotificationService.cancelAllNotifications();

    // Schedule mood reminders with user-configured times
    if (settings.accessReminders) {
      await RealNotificationService.scheduleMoodReminders(
        morningEnabled: settings.morningAccessReminder,
        middayEnabled: settings.middayAccessReminder,
        eveningEnabled: settings.eveningAccessReminder,
        morningTime: NotificationTime(settings.morningTime.hour, settings.morningTime.minute),
        middayTime: NotificationTime(settings.middayTime.hour, settings.middayTime.minute),
        eveningTime: NotificationTime(settings.eveningTime.hour, settings.eveningTime.minute),
      );
    }

    // Schedule end-of-day reminder
    if (settings.endOfDayReminder) {
      await RealNotificationService.scheduleEndOfDayReminder(
        enabled: true,
        time: NotificationTime(settings.endOfDayTime.hour, settings.endOfDayTime.minute),
      );
    }
  }

  /// Show a test notification
  static Future<void> showTestNotification() async {
    await RealNotificationService.showTestNotification();
  }

  /// Get real pending notifications from the system
  static Future<List<notifications.PendingNotificationRequest>> getSystemPendingNotifications() async {
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
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      accessReminders: accessReminders ?? this.accessReminders,
      morningAccessReminder: morningAccessReminder ??
          this.morningAccessReminder,
      middayAccessReminder: middayAccessReminder ?? this.middayAccessReminder,
      eveningAccessReminder: eveningAccessReminder ??
          this.eveningAccessReminder,
      endOfDayReminder: endOfDayReminder ?? this.endOfDayReminder,
      endOfDayTime: endOfDayTime ?? this.endOfDayTime,
      morningTime: morningTime ?? this.morningTime,
      middayTime: middayTime ?? this.middayTime,
      eveningTime: eveningTime ?? this.eveningTime,
      goalReminders: goalReminders ?? this.goalReminders,
      goalProgress: goalProgress ?? this.goalProgress,
      goalEncouragement: goalEncouragement ?? this.goalEncouragement,
      streakCelebrations: streakCelebrations ?? this.streakCelebrations,
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
  accessReminder,      // "Morning mood logging is now available!"
  endOfDayReminder,    // "Don't forget to log your missing moods"
  endOfDayComplete,    // "Perfect day of mood tracking!"
  goalProgress,        // "Goal Progress Update"
  goalEncouragement,   // "Keep working toward your goal!"
  streakCelebration,   // "7 day streak!"
}

class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}