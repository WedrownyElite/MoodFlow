import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/cloud_backup_service.dart';

class MoodDataService {
  static const List<String> timeSegments = ['Morning', 'Midday', 'Evening'];

  /// Returns key for storing mood data
  static String getKeyForDateSegment(DateTime date, int segmentIndex) {
    final dateString = date.toIso8601String().substring(0, 10);
    return 'mood_${dateString}_${segmentIndex}';
  }

  /// Loads saved mood (rating + note + timestamp) for given date and segment
  /// FIXED: Always reload from SharedPreferences to get fresh data
  static Future<Map<String, dynamic>?> loadMood(DateTime date, int segmentIndex) async {
    try {
      final key = getKeyForDateSegment(date, segmentIndex);

      final prefs = await SharedPreferences.getInstance();
      
      await prefs.reload();

      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        return null;
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      print('📖 Loaded fresh mood for $key: $data');
      return data;
    } catch (e) {
      print('❌ Error loading mood: $e');
      return null;
    }
  }

  /// Saves mood (rating + note + timestamp) for given date and segment
  /// FIXED: Improved save process with verification
  static Future<bool> saveMood(DateTime date, int segmentIndex, double rating, String note) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getKeyForDateSegment(date, segmentIndex);

      // Check if this is an existing entry to preserve original timestamp
      final existingData = await _loadMoodDirect(prefs, key);
      final originalTimestamp = existingData?['timestamp'];

      // Include timestamp of when this mood was actually logged
      final moodData = {
        'rating': rating,
        'note': note,
        'timestamp': originalTimestamp ?? DateTime.now().toIso8601String(),
        'moodDate': date.toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      };

      final jsonData = jsonEncode(moodData);

      // Use commit() instead of setString() for immediate persistence
      final success = await prefs.setString(key, jsonData);

      if (success) {
        // Force immediate reload to ensure data is available for next read
        await prefs.reload();

        // Verify the data was actually saved
        final verification = prefs.getString(key);
        if (verification != null && verification == jsonData) {
          print('✅ Mood saved and verified for $key: $moodData');

          // Trigger cloud backup after successful save
          try {
            RealCloudBackupService.triggerBackupIfNeeded();
            print('🔄 Real cloud backup triggered after mood save');
          } catch (e) {
            print('⚠️ Cloud backup trigger failed: $e');
          }

          return true;
        } else {
          print('❌ Verification failed: Data was not persisted correctly');
          return false;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error saving mood: $e');
      return false;
    }
  }

  /// Helper method to load mood data directly from prefs without reload
  static Future<Map<String, dynamic>?> _loadMoodDirect(SharedPreferences prefs, String key) async {
    try {
      final jsonString = prefs.getString(key);
      if (jsonString == null) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
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
      final gracePeriodEnd = moodDayEnd.add(const Duration(hours: 6));

      return loggedAt.isAfter(moodDayStart) && loggedAt.isBefore(gracePeriodEnd);
    } catch (_) {
      return false;
    }
  }

  /// Debug method to check all stored mood data
  static Future<void> debugPrintAllMoods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Ensure fresh data
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

    await prefs.reload(); // Ensure changes are reflected
    print('🗑️ Cleared ${moodKeys.length} mood entries');
  }

  /// Force a cloud backup of all current mood data
  static Future<bool> forceCloudBackup() async {
    try {
      final result = await RealCloudBackupService.performManualBackup();
      if (result.success) {
        print('✅ Force cloud backup successful: ${result.message}');
        return true;
      } else {
        print('❌ Force cloud backup failed: ${result.error}');
        return false;
      }
    } catch (e) {
      print('❌ Force cloud backup error: $e');
      return false;
    }
  }

  /// Check if cloud backup is available and configured
  static Future<bool> isCloudBackupConfigured() async {
    try {
      final status = await RealCloudBackupService.getBackupStatus();
      return status['available'] == true && status['isSignedIn'] == true;
    } catch (e) {
      return false;
    }
  }
}