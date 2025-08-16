import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifications;
import 'mood_data_service.dart';
import 'mood_analytics_service.dart';
import '../real_notification_service.dart'; // Import the real notification service

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

    // Schedule mood reminders
    if (settings.accessReminders) {
      await RealNotificationService.scheduleMoodReminders(
        morningEnabled: settings.morningAccessReminder,
        middayEnabled: settings.middayAccessReminder,
        eveningEnabled: settings.eveningAccessReminder,
        morningTime: NotificationTime(0, 0), // 12:00 AM
        middayTime: NotificationTime(12, 0), // 12:00 PM
        eveningTime: NotificationTime(18, 0), // 6:00 PM
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

  /// Get all pending notifications for the current time (for immediate notifications)
  static Future<List<NotificationContent>> getPendingNotifications() async {
    final settings = await loadSettings();
    if (!settings.enabled) return [];

    final now = DateTime.now();
    final notifications = <NotificationContent>[];

    // Check for mood log access notifications (only for immediate sending)
    if (settings.accessReminders) {
      final accessNotification = await _checkAccessNotification(now, settings);
      if (accessNotification != null) {
        notifications.add(accessNotification);
        
        // Send the notification immediately
        await RealNotificationService.showNotification(
          id: _getNotificationId(accessNotification.type),
          title: accessNotification.title,
          body: accessNotification.body,
          payload: jsonEncode(accessNotification.data),
        );
      }
    }

    // Check for end-of-day reminder (only for immediate sending)
    if (settings.endOfDayReminder) {
      final endOfDayNotification = await _checkEndOfDayNotification(now, settings);
      if (endOfDayNotification != null) {
        notifications.add(endOfDayNotification);
        
        // Send the notification immediately
        await RealNotificationService.showNotification(
          id: _getNotificationId(endOfDayNotification.type),
          title: endOfDayNotification.title,
          body: endOfDayNotification.body,
          payload: jsonEncode(endOfDayNotification.data),
        );
      }
    }

    // Check for goal reminders
    if (settings.goalReminders) {
      final goalNotifications = await _checkGoalNotifications(now, settings);
      for (final notification in goalNotifications) {
        notifications.add(notification);
        
        // Send the notification immediately
        await RealNotificationService.showNotification(
          id: _getNotificationId(notification.type),
          title: notification.title,
          body: notification.body,
          payload: jsonEncode(notification.data),
        );
      }
    }

    return notifications;
  }

  /// Get notification ID based on type
  static int _getNotificationId(NotificationType type) {
    switch (type) {
      case NotificationType.accessReminder:
        return 1000; // Dynamic ID based on segment
      case NotificationType.endOfDayReminder:
      case NotificationType.endOfDayComplete:
        return 2000;
      case NotificationType.goalProgress:
      case NotificationType.goalEncouragement:
        return 3000;
      case NotificationType.streakCelebration:
        return 4000;
    }
  }

  /// Check if user should get a mood log access notification
  static Future<NotificationContent?> _checkAccessNotification(DateTime now, NotificationSettings settings) async {
    final hour = now.hour;
    String? timeSegment;
    int segmentIndex = -1;

    // Determine which segment just became available
    if (hour == 0 && settings.morningAccessReminder) {
      timeSegment = 'Morning';
      segmentIndex = 0;
    } else if (hour == 12 && settings.middayAccessReminder) {
      timeSegment = 'Midday';
      segmentIndex = 1;
    } else if (hour == 18 && settings.eveningAccessReminder) {
      timeSegment = 'Evening';
      segmentIndex = 2;
    }

    if (timeSegment == null) return null;

    // Check if already notified today for this segment
    if (await _wasNotifiedToday('access_$segmentIndex')) return null;

    // Check if user already logged this segment
    final existingMood = await MoodDataService.loadMood(now, segmentIndex);
    if (existingMood != null && existingMood['rating'] != null) return null;

    await _markNotifiedToday('access_$segmentIndex');

    return NotificationContent(
      id: 'access_$segmentIndex',
      title: '$timeSegment mood logging is now available! 🌟',
      body: 'Time to check in with yourself - how are you feeling this $timeSegment?',
      type: NotificationType.accessReminder,
      data: {'type': 'access_reminder', 'segment': segmentIndex, 'timeSegment': timeSegment.toLowerCase()},
    );
  }

  /// Check for end-of-day reminder notification
  static Future<NotificationContent?> _checkEndOfDayNotification(DateTime now, NotificationSettings settings) async {
    // Check if it's around the end-of-day time (default 11 PM)
    if (now.hour != settings.endOfDayTime.hour) return null;

    // Check if already notified today
    if (await _wasNotifiedToday('end_of_day')) return null;

    // Check how many moods were logged today
    int loggedSegments = 0;
    final missingSegments = <String>[];
    
    for (int i = 0; i < 3; i++) {
      final mood = await MoodDataService.loadMood(now, i);
      if (mood != null && mood['rating'] != null) {
        loggedSegments++;
      } else {
        missingSegments.add(MoodDataService.timeSegments[i]);
      }
    }

    // If all segments logged, send congratulations
    if (loggedSegments == 3) {
      await _markNotifiedToday('end_of_day');
      return NotificationContent(
        id: 'end_of_day_complete',
        title: 'Perfect day of mood tracking! 🎉',
        body: 'You logged all your moods today. Great job staying mindful!',
        type: NotificationType.endOfDayComplete,
        data: {'type': 'end_of_day', 'segmentsLogged': loggedSegments},
      );
    }

    // If some segments missing, send reminder
    if (loggedSegments > 0) {
      await _markNotifiedToday('end_of_day');
      return NotificationContent(
        id: 'end_of_day_reminder',
        title: 'Don\'t forget to complete your mood log! 📝',
        body: 'You\'re missing: ${missingSegments.join(", ")}. Quick check-in before bed?',
        type: NotificationType.endOfDayReminder,
        data: {'type': 'end_of_day', 'missingSegments': missingSegments, 'loggedSegments': loggedSegments},
      );
    }

    // If no segments logged, send gentle reminder
    await _markNotifiedToday('end_of_day');
    return NotificationContent(
      id: 'end_of_day_empty',
      title: 'How was your day? 🌙',
      body: 'Take a moment to reflect on your day and log your moods.',
      type: NotificationType.endOfDayReminder,
      data: {'type': 'end_of_day', 'loggedSegments': 0},
    );
  }

  /// Check for goal-related notifications
  static Future<List<NotificationContent>> _checkGoalNotifications(DateTime now, NotificationSettings settings) async {
    final goals = await MoodAnalyticsService.loadGoals();
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final notifications = <NotificationContent>[];

    for (final goal in activeGoals) {
      // Check if it's been a while since goal was created (send progress reminder)
      final daysSinceCreated = now.difference(goal.createdDate).inDays;
      
      if (daysSinceCreated > 0 && daysSinceCreated % 3 == 0) { // Every 3 days
        final notificationId = 'goal_${goal.id}_day_$daysSinceCreated';
        if (await _wasNotifiedToday(notificationId)) continue;

        // Calculate progress (simplified)
        final progressText = await _getGoalProgressText(goal);
        
        await _markNotifiedToday(notificationId);
        notifications.add(NotificationContent(
          id: notificationId,
          title: 'Goal Progress Update 🎯',
          body: '${goal.title}: $progressText Keep it up!',
          type: NotificationType.goalProgress,
          data: {'type': 'goal', 'goalId': goal.id, 'goalTitle': goal.title},
        ));
      }

      // Check for goal near completion
      if (daysSinceCreated > 0 && daysSinceCreated % 7 == 0) { // Weekly encouragement
        final notificationId = 'goal_${goal.id}_week_${(daysSinceCreated / 7).floor()}';
        if (await _wasNotifiedToday(notificationId)) continue;

        await _markNotifiedToday(notificationId);
        notifications.add(NotificationContent(
          id: notificationId,
          title: 'Keep working toward your goal! 💪',
          body: '${goal.title} - You\'ve been at this for ${daysSinceCreated} days!',
          type: NotificationType.goalEncouragement,
          data: {'type': 'goal', 'goalId': goal.id, 'daysSinceCreated': daysSinceCreated},
        ));
      }
    }

    return notifications;
  }

  /// Helper: Check if we sent a notification today for this type
  static Future<bool> _wasNotifiedToday(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastNotified = prefs.getString('last_notification_$notificationId');
    if (lastNotified == null) return false;

    final lastDate = DateTime.parse(lastNotified);
    final today = DateTime.now();
    
    return lastDate.year == today.year && 
           lastDate.month == today.month && 
           lastDate.day == today.day;
  }

  /// Helper: Mark that we sent a notification today
  static Future<void> _markNotifiedToday(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_notification_$notificationId', DateTime.now().toIso8601String());
  }

  /// Helper: Get simplified goal progress text
  static Future<String> _getGoalProgressText(MoodGoal goal) async {
    switch (goal.type) {
      case GoalType.consecutiveDays:
        return 'Keep logging daily!';
      case GoalType.averageMood:
        return 'Maintain that positive energy!';
      case GoalType.minimumMood:
        return 'Stay above your minimum!';
      case GoalType.improvementStreak:
        return 'Each day better than the last!';
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
      endOfDayTime: const TimeOfDay(hour: 23, minute: 0), // 11 PM
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
    bool? goalReminders,
    bool? goalProgress,
    bool? goalEncouragement,
    bool? streakCelebrations,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      accessReminders: accessReminders ?? this.accessReminders,
      morningAccessReminder: morningAccessReminder ?? this.morningAccessReminder,
      middayAccessReminder: middayAccessReminder ?? this.middayAccessReminder,
      eveningAccessReminder: eveningAccessReminder ?? this.eveningAccessReminder,
      endOfDayReminder: endOfDayReminder ?? this.endOfDayReminder,
      endOfDayTime: endOfDayTime ?? this.endOfDayTime,
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