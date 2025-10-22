import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'real_notification_service.dart';
import 'personalized_notification_generator.dart';
import '../data/mood_trends_service.dart';
import '../data/mood_data_service.dart';
import '../utils/logger.dart';

class NotificationManager {
  static Timer? _backgroundTimer;
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    RealNotificationService.initialize();

    // Start background task to check for streak preservation
    _backgroundTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _checkStreakPreservation();

      // Check once per day (at hour 10) for inactive users
      if (DateTime.now().hour == 10) {
        await _checkInactiveUsers();
      }
    });
  }

  static Future<void> _checkStreakPreservation() async {
    try {
      final now = DateTime.now();

      // Only check between 8 PM and 11 PM
      if (now.hour < 20 || now.hour >= 23) return;

      // Check if user has logged mood today
      final today = DateTime(now.year, now.month, now.day);
      bool hasLoggedToday = false;

      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(today, segment);
        if (mood != null && mood['rating'] != null) {
          hasLoggedToday = true;
          break;
        }
      }

      // If no mood logged and user has an active streak, send reminder
      if (!hasLoggedToday) {
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
          // Generate personalized streak message
          final streakMessage = await PersonalizedNotificationGenerator.generateStreakMessage(stats.currentStreak);

          // Send immediate notification
          await RealNotificationService.showNotification(
            id: 5001,
            title: streakMessage.title,
            body: streakMessage.body,
            payload: jsonEncode({
              'type': 'streak_preservation',
              'currentStreak': stats.currentStreak,
            }),
          );
        }
      }
    } catch (e) {
      Logger.notificationService('Error in streak preservation check: $e');
    }
  }

  /// Check for inactive users and send return notifications
  static Future<void> _checkInactiveUsers() async {
    try {
      final daysSinceLastLog = await _getDaysSinceLastMoodLog();

      // Only notify if user has been inactive for 3+ days
      if (daysSinceLastLog >= 3) {
        final returnMessage = await PersonalizedNotificationGenerator.generateReturnMessage(daysSinceLastLog);

        // Send notification
        await RealNotificationService.showNotification(
          id: 5002,
          title: returnMessage.title,
          body: returnMessage.body,
          payload: jsonEncode({
            'type': 'return_reminder',
            'daysSinceLastLog': daysSinceLastLog,
          }),
        );

        Logger.notificationService('📬 Sent return notification after $daysSinceLastLog days');
      }
    } catch (e) {
      Logger.notificationService('Error checking inactive users: $e');
    }
  }

  static Future<int> _getDaysSinceLastMoodLog() async {
    final today = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(checkDate, segment);
        if (mood != null) {
          return i;
        }
      }
    }

    return 365;
  }
  
  static void dispose() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _isInitialized = false;
  }

  // Remove all the placeholder/testing methods and keep only these essentials:
  static Future<void> showTestNotification(
      BuildContext context, String title, String body) async {
    await RealNotificationService.showNotification(
      id: 9999,
      title: title,
      body: body,
    );
  }
}
