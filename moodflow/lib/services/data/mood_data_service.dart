import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/auto_backup_service.dart';

class MoodDataService {
  static const List<String> timeSegments = ['Morning', 'Midday', 'Evening'];

  /// Returns key for storing mood data
  static String getKeyForDateSegment(DateTime date, int segmentIndex) {
    final dateString = date.toIso8601String().substring(0, 10);
    return 'mood_${dateString}_${segmentIndex}'; // More specific key format
  }

  /// Loads saved mood (rating + note + timestamp) for given date and segment
  static Future<Map<String, dynamic>?> loadMood(DateTime date, int segmentIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getKeyForDateSegment(date, segmentIndex);
      final jsonString = prefs.getString(key);

      if (jsonString == null) return null;

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      print('📖 Loaded mood for $key: $data'); // Debug logging
      return data;
    } catch (e) {
      print('❌ Error loading mood: $e');
      return null;
    }
  }

  /// Saves mood (rating + note + timestamp) for given date and segment
  static Future<bool> saveMood(DateTime date, int segmentIndex, double rating, String note) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getKeyForDateSegment(date, segmentIndex);

      // Check if this is an existing entry to preserve original timestamp
      final existingData = await loadMood(date, segmentIndex);
      final originalTimestamp = existingData?['timestamp'];

      // Include timestamp of when this mood was actually logged
      final moodData = {
        'rating': rating,
        'note': note,
        'timestamp': originalTimestamp ?? DateTime.now().toIso8601String(), // Preserve original or use current
        'moodDate': date.toIso8601String(), // What date the mood is for
        'lastModified': DateTime.now().toIso8601String(), // Track last edit
      };

      final jsonData = jsonEncode(moodData);
      final success = await prefs.setString(key, jsonData);

      print('💾 Saved mood for $key: $moodData'); // Debug logging
      print('💾 Save result: $success'); // Debug logging

      if (success) {
        // Force immediate commit to storage
        await prefs.reload();

        // Verify the data was actually saved
        final verification = prefs.getString(key);
        if (verification != null) {
          print('✅ Verification successful: Data is persisted');

          // Trigger auto backup
          AutoBackupService.triggerBackupIfNeeded();
          return true;
        } else {
          print('❌ Verification failed: Data was not persisted');
          return false;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error saving mood: $e');
      return false;
    }
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

  /// Debug method to check all stored mood data
  static Future<void> debugPrintAllMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final moodKeys = allKeys.where((key) => key.startsWith('mood_')).toList();

    print('🔍 Found ${moodKeys.length} mood entries:');
    for (final key in moodKeys) {
      final value = prefs.getString(key);
      print('  $key: $value');
    }
  }

  /// Clear all mood data (for testing purposes)
  static Future<void> clearAllMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final moodKeys = allKeys.where((key) => key.startsWith('mood_')).toList();

    for (final key in moodKeys) {
      await prefs.remove(key);
    }

    print('🗑️ Cleared ${moodKeys.length} mood entries');
  }
}