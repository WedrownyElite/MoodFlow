import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'real_notification_service.dart';
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
          // Send immediate notification
          await RealNotificationService.showNotification(
            id: 5001,
            title: '🔥 Don\'t break your ${stats.currentStreak}-day streak!',
            body: 'Quick! Log your mood before midnight to keep your streak alive.',
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
