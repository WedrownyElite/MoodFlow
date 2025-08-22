import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/cloud_backup_service.dart';

class MoodDataService {
  static const List<String> timeSegments = ['Morning', 'Midday', 'Evening'];
  static Timer? _backupThrottleTimer;
  static DateTime? _lastBackupAttempt;

  // Flag to prevent operations before proper initialization
  static bool _isInitialized = false;
  static Completer<SharedPreferences>? _prefsCompleter;
  static SharedPreferences? _cachedPrefs;

  /// Initialize the service safely
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 Initializing MoodDataService...');

      // Ensure we have bindings before accessing SharedPreferences
      WidgetsFlutterBinding.ensureInitialized();

      // Get SharedPreferences instance and cache it
      _cachedPrefs = await SharedPreferences.getInstance();
      _isInitialized = true;

      print('✅ MoodDataService initialized successfully');
    } catch (e) {
      print('❌ MoodDataService initialization failed: $e');
      rethrow;
    }
  }

  /// Get SharedPreferences instance safely
  static Future<SharedPreferences> _getPrefs() async {
    // If we have cached prefs and they're ready, use them
    if (_cachedPrefs != null && _isInitialized) {
      return _cachedPrefs!;
    }

    // If another call is already getting prefs, wait for it
    if (_prefsCompleter != null) {
      return await _prefsCompleter!.future;
    }

    // Create a new completer for this request
    _prefsCompleter = Completer<SharedPreferences>();

    try {
      // Ensure initialization before accessing SharedPreferences
      if (!_isInitialized) {
        await initialize();
      }

      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;

      _prefsCompleter!.complete(prefs);
      _prefsCompleter = null;

      return prefs;
    } catch (e) {
      _prefsCompleter!.completeError(e);
      _prefsCompleter = null;
      rethrow;
    }
  }

  /// Returns key for storing mood data
  static String getKeyForDateSegment(DateTime date, int segmentIndex) {
    final dateString = date.toIso8601String().substring(0, 10);
    return 'mood_${dateString}_${segmentIndex}';
  }

  /// Loads saved mood (rating + note + timestamp) for given date and segment
  static Future<Map<String, dynamic>?> loadMood(DateTime date, int segmentIndex) async {
    try {
      final key = getKeyForDateSegment(date, segmentIndex);
      final prefs = await _getPrefs();

      // Force reload to get fresh data
      await prefs.reload();

      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        return null;
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (kDebugMode && DateTime.now().millisecond % 100 == 0) {
        print('📖 Loaded fresh mood for $key: $data');
      }
      return data;
    } catch (e) {
      print('❌ Error loading mood: $e');
      return null;
    }
  }

  /// Saves mood (rating + note + timestamp) for given date and segment
  static Future<bool> saveMood(DateTime date, int segmentIndex, double rating, String note) async {
    try {
      final prefs = await _getPrefs();
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

      // Use commit() for immediate persistence
      final success = await prefs.setString(key, jsonData);

      if (success) {
        // Force immediate reload to ensure data is available for next read
        await prefs.reload();

        // Verify the data was actually saved
        final verification = prefs.getString(key);
        if (verification != null && verification == jsonData) {
          print('✅ Mood saved and verified for $key: $moodData');

          // Trigger cloud backup after successful save
          _scheduleThrottledBackup();

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

  /// Schedule throttled backup to prevent too frequent backups
  static void _scheduleThrottledBackup() {
    final now = DateTime.now();

    // Don't backup more than once every 30 minutes
    if (_lastBackupAttempt != null &&
        now.difference(_lastBackupAttempt!).inMinutes < 30) {
      return;
    }

    // Cancel existing timer and set new one
    _backupThrottleTimer?.cancel();
    _backupThrottleTimer = Timer(const Duration(minutes: 2), () async {
      try {
        _lastBackupAttempt = DateTime.now();

        // Safely check if cloud backup is available and enabled
        bool isEnabled = false;
        bool isAvailable = false;

        try {
          isEnabled = await RealCloudBackupService.isAutoBackupEnabled();
          isAvailable = await RealCloudBackupService.isCloudBackupAvailable();
        } catch (e) {
          print('❌ Error checking cloud backup status: $e');
          return;
        }

        if (isEnabled && isAvailable) {
          await RealCloudBackupService.performAutomaticBackup();
        }
      } catch (e) {
        print('❌ Throttled cloud backup failed: $e');
      }
    });
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
    try {
      final prefs = await _getPrefs();
      await prefs.reload(); // Ensure fresh data
      final allKeys = prefs.getKeys();
      final moodKeys = allKeys.where((key) => key.startsWith('mood_')).toList();

      print('🔍 Found ${moodKeys.length} mood entries:');
      for (final key in moodKeys) {
        final value = prefs.getString(key);
        print('  $key: $value');
      }
    } catch (e) {
      print('❌ Error debugging moods: $e');
    }
  }

  /// Clear all mood data (for testing purposes)
  static Future<void> clearAllMoods() async {
    try {
      final prefs = await _getPrefs();
      final allKeys = prefs.getKeys();
      final moodKeys = allKeys.where((key) => key.startsWith('mood_')).toList();

      for (final key in moodKeys) {
        await prefs.remove(key);
      }

      await prefs.reload(); // Ensure changes are reflected
      print('🗑️ Cleared ${moodKeys.length} mood entries');
    } catch (e) {
      print('❌ Error clearing moods: $e');
    }
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

  /// Cleanup method
  static void dispose() {
    _backupThrottleTimer?.cancel();
    _backupThrottleTimer = null;
    _prefsCompleter = null;
    _cachedPrefs = null;
    _isInitialized = false;
  }
}