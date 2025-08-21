// Enhanced version of mood_data_service.dart to track when moods are logged

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/auto_backup_service.dart';

class MoodDataService {
  static const List<String> timeSegments = ['Morning', 'Midday', 'Evening'];

  /// Returns key for storing mood data
  static String getKeyForDateSegment(DateTime date, int segmentIndex) {
    final dateString = date.toIso8601String().substring(0, 10);
    return '${dateString}_${timeSegments[segmentIndex].toLowerCase()}';
  }

  /// Loads saved mood (rating + note + timestamp) for given date and segment
  static Future<Map<String, dynamic>?> loadMood(DateTime date, int segmentIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getKeyForDateSegment(date, segmentIndex);
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Saves mood (rating + note + timestamp) for given date and segment
  static Future<void> saveMood(DateTime date, int segmentIndex, double rating, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getKeyForDateSegment(date, segmentIndex);

    // Check if this is an existing entry to preserve original timestamp
    final existingData = await loadMood(date, segmentIndex);
    final originalTimestamp = existingData?['timestamp'];

    // Include timestamp of when this mood was actually logged
    final jsonData = jsonEncode({
      'rating': rating,
      'note': note,
      'timestamp': originalTimestamp ?? DateTime.now().toIso8601String(), // Preserve original or use current
      'moodDate': date.toIso8601String(), // What date the mood is for
      'lastModified': DateTime.now().toIso8601String(), // Track last edit
    });

    await prefs.setString(key, jsonData);

    AutoBackupService.triggerBackupIfNeeded();
  }

  /// Check if a mood entry was logged on the actual day (within grace period)
  static Future<bool> wasMoodLoggedOnTime(DateTime moodDate, int segmentIndex) async {
    final moodData = await loadMood(moodDate, segmentIndex);
    if (moodData == null || moodData['timestamp'] == null) return false;

    try {
      final loggedAt = DateTime.parse(moodData['timestamp']);
      final moodDayStart = DateTime(moodDate.year, moodDate.month, moodDate.day);
      final moodDayEnd = moodDayStart.add(const Duration(days: 1));
      final gracePeriodEnd = moodDayEnd.add(const Duration(hours: 6)); // 6 hour grace period

      // Was it logged on the actual day or within 6 hours after?
      return loggedAt.isAfter(moodDayStart) && loggedAt.isBefore(gracePeriodEnd);
    } catch (_) {
      return false;
    }
  }
}