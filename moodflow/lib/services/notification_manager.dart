import 'dart:async';
import 'package:flutter/material.dart';
import 'data/enhanced_notification_service.dart';

class NotificationManager {
  static Timer? _backgroundTimer;
  static bool _isInitialized = false;

  /// Initialize the notification manager
  static void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;

    // Check for notifications every hour
    _backgroundTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkAndScheduleNotifications();
    });

    // Also check immediately
    _checkAndScheduleNotifications();
  }

  /// Dispose of the notification manager
  static void dispose() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _isInitialized = false;
  }

  /// Check for pending notifications and schedule them
  static Future<void> _checkAndScheduleNotifications() async {
    try {
      // The RealNotificationService already handles scheduling
      // This timer just ensures the scheduled notifications stay active
      final settings = await EnhancedNotificationService.loadSettings();
      if (settings.enabled) {
        // Re-apply scheduled notifications to ensure they're still active
        await EnhancedNotificationService.saveSettings(settings);
      }
    } catch (e) {
      debugPrint('Error maintaining notifications: $e');
    }
  }

  /// Schedule a single notification (placeholder implementation)
  static Future<void> _scheduleNotification(
      NotificationContent notification) async {
    // In a real implementation, this would use flutter_local_notifications
    // to schedule the actual system notification

    debugPrint('📱 Notification: ${notification.title}');
    debugPrint('📝 Body: ${notification.body}');
    debugPrint('🔔 Type: ${notification.type}');

    // For development/testing, you could show a snackbar or dialog
    // In production, this would be a proper system notification
  }

  /// Show a notification immediately (for testing purposes)
  static Future<void> showTestNotification(BuildContext context,
      NotificationContent notification) async {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notification.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(notification.body),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Handle notification tap
            _handleNotificationTap(context, notification);
          },
        ),
      ),
    );
  }

  /// Handle when user taps on a notification
  static void _handleNotificationTap(BuildContext context,
      NotificationContent notification) {
    switch (notification.type) {
      case NotificationType.accessReminder:
      // Navigate to mood log screen
        Navigator.of(context).pushNamed('/mood-log');
        break;
      case NotificationType.endOfDayReminder:
      case NotificationType.endOfDayComplete:
      // Navigate to mood log screen
        Navigator.of(context).pushNamed('/mood-log');
        break;
      case NotificationType.goalProgress:
      case NotificationType.goalEncouragement:
      // Navigate to goals screen
        Navigator.of(context).pushNamed('/goals');
        break;
      case NotificationType.streakCelebration:
      // Navigate to trends screen to show streak
        Navigator.of(context).pushNamed('/trends');
        break;
    }
  }

  /// Manual check for notifications (useful for testing)
  static Future<List<NotificationContent>> checkForNotifications() async {
    return [];
  }

  /// Show all pending notifications as snackbars (for testing)
  static Future<void> showPendingNotificationsAsSnackbars(
      BuildContext context) async {
    // For testing purposes, show example notifications instead of actual pending ones
    final testNotifications = NotificationTesting.createTestNotifications();

    if (testNotifications.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No test notifications available.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    for (int i = 0; i < testNotifications.length; i++) {
      final notification = testNotifications[i];

      // Delay between notifications so they don't overlap
      await Future.delayed(Duration(milliseconds: i * 2000)); // 2 second delay

      if (context.mounted) {
        await showTestNotification(context, notification);
      }
    }
  }

  /// Check for real pending notifications (for actual scheduling)
  static Future<void> showRealPendingNotifications(BuildContext context) async {
    // Show the actual system-scheduled pending notifications instead
    try {
      final pendingNotifications = await EnhancedNotificationService
          .getSystemPendingNotifications();

      if (pendingNotifications.isEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pending system notifications scheduled.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Show info about scheduled notifications
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Found ${pendingNotifications.length} scheduled notifications'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking notifications: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

/// Extension to add notification testing capabilities to debug builds
extension NotificationTesting on NotificationManager {
  /// Create test notifications for different scenarios
  static List<NotificationContent> createTestNotifications() {
    return [
      NotificationContent(
        id: 'test_access',
        title: 'Morning mood logging is now available! ☀️',
        body: 'Time to check in with yourself - how are you feeling this morning?',
        type: NotificationType.accessReminder,
        data: {'segment': 0, 'timeSegment': 'morning'},
      ),
      NotificationContent(
        id: 'test_end_of_day',
        title: 'Don\'t forget to complete your mood log! 📝',
        body: 'You\'re missing: Evening. Quick check-in before bed?',
        type: NotificationType.endOfDayReminder,
        data: {'missingSegments': ['Evening'], 'loggedSegments': 2},
      ),
      NotificationContent(
        id: 'test_goal',
        title: 'Goal Progress Update 🎯',
        body: 'Maintain 7+ Average Mood: Keep it up!',
        type: NotificationType.goalProgress,
        data: {'goalId': 'test', 'goalTitle': 'Maintain 7+ Average Mood'},
      ),
      NotificationContent(
        id: 'test_celebration',
        title: 'Perfect day of mood tracking! 🎉',
        body: 'You logged all your moods today. Great job staying mindful!',
        type: NotificationType.endOfDayComplete,
        data: {'segmentsLogged': 3},
      ),
    ];
  }
}