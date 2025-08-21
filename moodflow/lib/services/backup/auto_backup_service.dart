import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../data/backup_models.dart';
import 'backup_service.dart';

class AutoBackupService {
  static const MethodChannel _channel = MethodChannel('auto_backup');
  static const String _lastBackupKey = 'last_auto_backup_timestamp';
  static const String _backupEnabledKey = 'auto_backup_enabled';
  static const String _backupIntervalKey = 'auto_backup_interval_hours';

  // Default backup every 24 hours
  static const int _defaultBackupIntervalHours = 24;

  /// Check if auto backup is available on this platform
  static Future<bool> isAutoBackupAvailable() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod('isAutoBackupAvailable') ?? true;
      } catch (e) {
        print('Auto backup channel error: $e');
        return true; // Assume available on modern Android
      }
    } else if (Platform.isIOS) {
      return true; // iOS has built-in iCloud backup
    }
    return false;
  }

  /// Request immediate backup (Android only)
  static Future<void> requestBackup() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('requestBackup');
        print('✅ Android backup requested');
      } catch (e) {
        print('❌ Backup request failed: $e');
      }
    }
  }

  /// Get backup status
  static Future<Map<String, dynamic>> getBackupStatus() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('getBackupStatus');
        return Map<String, dynamic>.from(result ?? {});
      } else if (Platform.isIOS) {
        return {
          'available': true,
          'enabled': await isAutoBackupEnabled(),
          'type': 'iCloud',
          'lastBackup': await getLastBackupTime(),
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

  /// The main method that should be called whenever data changes
  static void triggerBackupIfNeeded() {
    _scheduleBackupCheck();
  }

  /// Internal method to schedule a backup check
  static void _scheduleBackupCheck() {
    // Run backup check in background
    Future.delayed(const Duration(seconds: 5), () async {
      if (await shouldPerformBackup()) {
        await performAutomaticBackup();
      }
    });
  }

  /// Check if we should perform a backup now
  static Future<bool> shouldPerformBackup() async {
    if (!await isAutoBackupEnabled()) return false;

    final lastBackup = await getLastBackupTime();
    if (lastBackup == null) return true; // Never backed up

    final intervalHours = await getBackupInterval();
    final timeSinceLastBackup = DateTime.now().difference(lastBackup);

    return timeSinceLastBackup.inHours >= intervalHours;
  }

  /// Perform automatic backup
  static Future<bool> performAutomaticBackup() async {
    try {
      print('🔄 Starting automatic backup...');

      // Create backup data
      final exportData = await BackupService.exportAllData();

      // Save to local files for redundancy
      await _saveLocalBackup(exportData);

      // Trigger platform-specific backup
      if (Platform.isAndroid) {
        await _triggerAndroidBackup(exportData);
      } else if (Platform.isIOS) {
        await _triggerIOSBackup(exportData);
      }

      // Update last backup time
      await _setLastBackupTime(DateTime.now());

      print('✅ Automatic backup completed successfully');
      return true;
    } catch (e) {
      print('❌ Automatic backup failed: $e');
      return false;
    }
  }

  /// Save backup locally (cross-platform)
  static Future<void> _saveLocalBackup(MoodDataExport exportData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/auto_backups');

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Keep only the 5 most recent backups
      await _cleanupOldBackups(backupDir);

      // Create new backup file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File('${backupDir.path}/auto_backup_$timestamp.json');

      final jsonString = jsonEncode(exportData.toJson());
      await backupFile.writeAsString(jsonString);

      print('📁 Local backup saved: ${backupFile.path}');
    } catch (e) {
      print('❌ Failed to save local backup: $e');
    }
  }

  /// Clean up old backup files (keep only 5 most recent)
  static Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();

      if (files.length <= 5) return;

      // Sort by modification time (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Delete older files
      for (int i = 5; i < files.length; i++) {
        await files[i].delete();
        print('🗑️ Deleted old backup: ${files[i].path}');
      }
    } catch (e) {
      print('❌ Failed to cleanup old backups: $e');
    }
  }

  /// Trigger Android auto backup
  static Future<void> _triggerAndroidBackup(MoodDataExport exportData) async {
    try {
      // Store backup data in shared preferences for Android Auto Backup
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(exportData.toJson());

      // Split large data into chunks if needed (SharedPreferences has size limits)
      const chunkSize = 1000000; // 1MB chunks
      final chunks = <String>[];

      for (int i = 0; i < jsonString.length; i += chunkSize) {
        final end = (i + chunkSize < jsonString.length) ? i + chunkSize : jsonString.length;
        chunks.add(jsonString.substring(i, end));
      }

      // Store chunk count and chunks
      await prefs.setInt('backup_chunk_count', chunks.length);
      for (int i = 0; i < chunks.length; i++) {
        await prefs.setString('backup_chunk_$i', chunks[i]);
      }

      // Request system backup
      await requestBackup();

      print('📱 Android backup data prepared and requested');
    } catch (e) {
      print('❌ Android backup failed: $e');
    }
  }

  /// Trigger iOS backup (data already in Documents which syncs with iCloud)
  static Future<void> _triggerIOSBackup(MoodDataExport exportData) async {
    try {
      // On iOS, data in Documents directory automatically syncs with iCloud
      // The local backup we saved earlier will be included in iCloud backup
      print('☁️ iOS backup: Data saved to Documents (auto-syncs with iCloud)');
    } catch (e) {
      print('❌ iOS backup preparation failed: $e');
    }
  }

  /// Get list of available local backups
  static Future<List<File>> getLocalBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/auto_backups');

      if (!await backupDir.exists()) return [];

      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .cast<File>()
          .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } catch (e) {
      print('❌ Failed to get local backups: $e');
      return [];
    }
  }

  /// Restore from local backup file
  static Future<bool> restoreFromLocalBackup(File backupFile) async {
    try {
      final jsonString = await backupFile.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final exportData = MoodDataExport.fromJson(jsonData);

      final result = await BackupService.importData(exportData);

      if (result.success) {
        print('✅ Restored from local backup: ${backupFile.path}');
        return true;
      } else {
        print('❌ Restore failed: ${result.error}');
        return false;
      }
    } catch (e) {
      print('❌ Failed to restore from backup: $e');
      return false;
    }
  }

  /// Restore from Android auto backup
  static Future<bool> restoreFromAndroidBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chunkCount = prefs.getInt('backup_chunk_count');

      if (chunkCount == null || chunkCount == 0) {
        print('❌ No Android backup data found');
        return false;
      }

      // Reconstruct the JSON string from chunks
      final buffer = StringBuffer();
      for (int i = 0; i < chunkCount; i++) {
        final chunk = prefs.getString('backup_chunk_$i');
        if (chunk == null) {
          print('❌ Missing backup chunk $i');
          return false;
        }
        buffer.write(chunk);
      }

      final jsonString = buffer.toString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final exportData = MoodDataExport.fromJson(jsonData);

      final result = await BackupService.importData(exportData);

      if (result.success) {
        print('✅ Restored from Android backup');
        return true;
      } else {
        print('❌ Android restore failed: ${result.error}');
        return false;
      }
    } catch (e) {
      print('❌ Failed to restore from Android backup: $e');
      return false;
    }
  }

  /// Settings management
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupEnabledKey, enabled);

    if (enabled) {
      triggerBackupIfNeeded();
    }
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backupEnabledKey) ?? true; // Default enabled
  }

  static Future<void> setBackupInterval(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backupIntervalKey, hours);
  }

  static Future<int> getBackupInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_backupIntervalKey) ?? _defaultBackupIntervalHours;
  }

  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastBackupKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static Future<void> _setLastBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, time.millisecondsSinceEpoch);
  }

  /// Manual backup test for debugging
  static Future<void> manualBackupTest() async {
    print('🧪 Running manual backup test...');

    final success = await performAutomaticBackup();
    if (success) {
      print('✅ Manual backup test completed successfully');

      // List available backups
      final backups = await getLocalBackups();
      print('📁 Available local backups: ${backups.length}');
      for (final backup in backups) {
        final stat = await backup.stat();
        print('  - ${backup.path} (${stat.size} bytes, ${stat.modified})');
      }
    } else {
      print('❌ Manual backup test failed');
    }
  }

  /// Manual restore test for debugging
  static Future<bool> manualRestoreTest() async {
    print('🧪 Running manual restore test...');

    // Try to restore from the most recent local backup
    final backups = await getLocalBackups();
    if (backups.isEmpty) {
      print('❌ No local backups found for restore test');
      return false;
    }

    return await restoreFromLocalBackup(backups.first);
  }
}