import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoBackupService {
  static const MethodChannel _channel = MethodChannel('auto_backup');

  static Future<bool> isAutoBackupAvailable() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod('isAutoBackupAvailable') ?? false;
      } catch (e) {
        return true; // Assume available on modern Android
      }
    } else if (Platform.isIOS) {
      return true; // iOS backup via iCloud
    }
    return false;
  }

  static Future<void> requestBackup() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('requestBackup');
      } catch (e) {
        print('Backup request failed: $e');
      }
    }
  }

  static Future<Map<String, dynamic>> getBackupStatus() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getBackupStatus');
        return Map<String, dynamic>.from(result ?? {});
      } else if (Platform.isIOS) {
        return {
          'available': true,
          'enabled': true,
          'type': 'iCloud',
        };
      }
    } catch (e) {
      print('Failed to get backup status: $e');
    }

    return {
      'available': false,
      'enabled': false,
      'error': 'Platform not supported',
    };
  }

  static void triggerBackupIfNeeded() {
    requestBackup().catchError((e) {
      print('Auto backup trigger failed: $e');
    });
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);

    if (enabled) {
      triggerBackupIfNeeded();
    }
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_backup_enabled') ?? true;
  }

  static Future<void> manualBackupTest() async {
    final prefs = await SharedPreferences.getInstance();

    // Save all current data to a special backup key
    final allKeys = prefs.getKeys();
    final backupData = <String, dynamic>{};

    for (final key in allKeys) {
      final value = prefs.get(key);
      backupData[key] = value;
    }

    // Store backup data
    await prefs.setString('manual_backup_data', jsonEncode(backupData));
    await prefs.setString('manual_backup_timestamp', DateTime.now().toIso8601String());

    print('✅ Manual backup created with ${allKeys.length} keys');
  }

  static Future<bool> manualRestoreTest() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we have backup data
    final backupDataString = prefs.getString('manual_backup_data');
    if (backupDataString == null) {
      print('❌ No manual backup data found');
      return false;
    }

    try {
      final backupData = jsonDecode(backupDataString) as Map<String, dynamic>;

      // Restore all data except the backup keys themselves
      for (final entry in backupData.entries) {
        if (!entry.key.startsWith('manual_backup_')) {
          final value = entry.value;
          if (value is String) {
            await prefs.setString(entry.key, value);
          } else if (value is bool) {
            await prefs.setBool(entry.key, value);
          } else if (value is int) {
            await prefs.setInt(entry.key, value);
          } else if (value is double) {
            await prefs.setDouble(entry.key, value);
          }
        }
      }

      print('✅ Manual restore completed with ${backupData.length} keys');
      return true;
    } catch (e) {
      print('❌ Manual restore failed: $e');
      return false;
    }
  }
}