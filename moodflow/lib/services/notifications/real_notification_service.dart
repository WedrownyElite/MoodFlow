import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../navigation_service.dart';

// Custom Time class to avoid conflicts
class NotificationTime {
  final int hour;
  final int minute;

  const NotificationTime(this.hour, this.minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class RealNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static late tz.Location _localTimeZone;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Get the device's local timezone
    try {
      // Try to get system timezone name
      final String timeZoneName = DateTime.now().timeZoneName;
      debugPrint('🌍 System timezone name: $timeZoneName');

      // Set local timezone - try system timezone first, fallback to UTC
      try {
        _localTimeZone = tz.getLocation(timeZoneName);
      } catch (e) {
        debugPrint(
            '⚠️ Could not find timezone $timeZoneName, trying common alternatives...');

        // Try common timezone mappings
        String? alternativeZone;
        if (timeZoneName.contains('EST') || timeZoneName.contains('EDT')) {
          alternativeZone = 'America/New_York';
        } else if (timeZoneName.contains('CST') ||
            timeZoneName.contains('CDT')) {
          alternativeZone = 'America/Chicago';
        } else if (timeZoneName.contains('MST') ||
            timeZoneName.contains('MDT')) {
          alternativeZone = 'America/Denver';
        } else if (timeZoneName.contains('PST') ||
            timeZoneName.contains('PDT')) {
          alternativeZone = 'America/Los_Angeles';
        }

        if (alternativeZone != null) {
          try {
            _localTimeZone = tz.getLocation(alternativeZone);
            debugPrint('🌍 Using alternative timezone: $alternativeZone');
          } catch (e2) {
            _localTimeZone = tz.local;
            debugPrint('🌍 Falling back to tz.local');
          }
        } else {
          _localTimeZone = tz.local;
          debugPrint('🌍 Using tz.local as fallback');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting timezone, using tz.local: $e');
      _localTimeZone = tz.local;
    }

    // Verify timezone is working correctly
    final now = tz.TZDateTime.now(_localTimeZone);
    final systemNow = DateTime.now();
    debugPrint('🌍 Selected timezone: ${_localTimeZone.name}');
    debugPrint('🕐 TZ now: $now (${now.toLocal()})');
    debugPrint('🕐 System now: $systemNow');
    debugPrint('🕐 UTC offset: ${now.timeZoneOffset}');

    // Android initialization settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('📱 Notification service initialized successfully');
  }

  /// Handle notification taps
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final type = data['type'] as String?;

        NavigationService.showNotificationTapInfo(type ?? 'unknown');
        NavigationService.handleNotificationTap(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
        NavigationService.navigateToHome();
      }
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        await Permission.scheduleExactAlarm.request();
        return true;
      }
      return false;
    } else if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return false;
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    } else if (Platform.isIOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return result?.isEnabled ?? false;
    }
    return false;
  }

  /// Show an immediate notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'mood_tracker_general',
      'General Notifications',
      channelDescription: 'General notifications for mood tracking reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.indigo,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Schedule daily repeating notification
  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required NotificationTime time,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'mood_tracker_daily',
      'Daily Reminders',
      channelDescription: 'Daily reminders for mood logging',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.indigo,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(time),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Get next instance of a specific time
  static tz.TZDateTime _nextInstanceOfTime(NotificationTime time) {
    final now = tz.TZDateTime.now(_localTimeZone);

    // Create scheduled time for today in the correct timezone
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      _localTimeZone,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      0, // seconds
      0, // milliseconds
    );

    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Convert to system time for logging (what the user actually sees)
    final systemTime = scheduledDate.toLocal();
    final systemNow = DateTime.now();

    debugPrint('🔔 Current system time: $systemNow');
    debugPrint('🔔 Scheduling notification for: $systemTime');
    debugPrint(
        '🔔 Time difference: ${scheduledDate.difference(now).inMinutes} minutes');
    debugPrint('🔔 Timezone: ${_localTimeZone.name}');

    return scheduledDate;
  }

  static Future<void> scheduleTestNotificationIn(
      int seconds, String message) async {
    final now = tz.TZDateTime.now(_localTimeZone);
    final scheduledTime = now.add(Duration(seconds: seconds));

    debugPrint('🔔 Current time: ${DateTime.now()}');
    debugPrint(
        '🔔 Test notification scheduled for: ${scheduledTime.toLocal()} (in $seconds seconds)');

    const androidDetails = AndroidNotificationDetails(
      'mood_tracker_test',
      'Test Notifications',
      channelDescription: 'Test notifications for debugging',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      99999, // Unique test ID
      'Test Notification',
      message,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({'type': 'test'}),
    );
  }

  /// Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Schedule mood logging reminders
  static Future<void> scheduleMoodReminders({
    required bool morningEnabled,
    required bool middayEnabled,
    required bool eveningEnabled,
    required NotificationTime morningTime,
    required NotificationTime middayTime,
    required NotificationTime eveningTime,
  }) async {
    await cancelNotification(1001);
    await cancelNotification(1002);
    await cancelNotification(1003);

    if (morningEnabled) {
      await scheduleDailyNotification(
        id: 1001,
        title: 'Good morning! ☀️',
        body: 'How are you feeling this morning?',
        time: morningTime,
        payload: jsonEncode({'type': 'access_reminder', 'segment': 0}),
      );
    }

    if (middayEnabled) {
      await scheduleDailyNotification(
        id: 1002,
        title: 'Midday check-in ⚡',
        body: 'Take a moment to log your current mood',
        time: middayTime,
        payload: jsonEncode({'type': 'access_reminder', 'segment': 1}),
      );
    }

    if (eveningEnabled) {
      await scheduleDailyNotification(
        id: 1003,
        title: 'Evening reflection 🌙',
        body: 'How has your evening been?',
        time: eveningTime,
        payload: jsonEncode({'type': 'access_reminder', 'segment': 2}),
      );
    }
  }

  /// Schedule end-of-day reminder
  static Future<void> scheduleEndOfDayReminder({
    required bool enabled,
    required NotificationTime time,
  }) async {
    await cancelNotification(2001);

    if (enabled) {
      await scheduleDailyNotification(
        id: 2001,
        title: 'End of day reflection 🌙',
        body: 'Don\'t forget to complete your mood log before bed',
        time: time,
        payload: jsonEncode({'type': 'end_of_day'}),
      );
    }
  }

  /// Show test notification
  static Future<void> showTestNotification() async {
    await showNotification(
      id: 9999,
      title: 'Test Notification 📱',
      body: 'This is a test notification to verify everything is working!',
      payload: jsonEncode({'type': 'test'}),
    );
  }
}

/// Notification ID constants
class NotificationIds {
  static const int morningReminder = 1001;
  static const int middayReminder = 1002;
  static const int eveningReminder = 1003;
  static const int endOfDayReminder = 2001;
  static const int goalReminder = 3001;
  static const int streakCelebration = 4001;
  static const int test = 9999;
}
