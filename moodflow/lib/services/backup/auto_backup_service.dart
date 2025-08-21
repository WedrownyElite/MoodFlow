import 'dart:io';
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
}