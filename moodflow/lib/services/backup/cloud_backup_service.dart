import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../backup/google_drive_service.dart';
import '../backup/icloud_service.dart';
import '../data/backup_models.dart';
import '../utils/logger.dart';

/// REAL cloud backup service that actually saves to Google Drive/iCloud
class RealCloudBackupService {
  static const String _lastBackupKey = 'last_cloud_backup_timestamp';
  static const String _autoCloudBackupEnabledKey = 'auto_cloud_backup_enabled';
  static const String _backupIntervalKey = 'cloud_backup_interval_hours';
  static const String _lastRestoreCheckKey = 'last_restore_check_timestamp';

  // Default backup every 24 hours
  static const int _defaultBackupIntervalHours = 24;

  static final GoogleDriveService _googleDriveService = GoogleDriveService();
  static final ICloudService _iCloudService = ICloudService();

  /// Check if cloud backup is available on this platform
  static Future<bool> isCloudBackupAvailable() async {
    if (Platform.isAndroid) {
      return true; // Google Drive available on Android
    } else if (Platform.isIOS) {
      return await _iCloudService.isAvailable();
    }
    return false;
  }

  /// Get the appropriate cloud service for this platform
  static dynamic _getCloudService() {
    if (Platform.isAndroid) {
      return _googleDriveService;
    } else if (Platform.isIOS) {
      return _iCloudService;
    }
    return null;
  }

  /// Trigger backup if needed (call this after mood changes)
  static void triggerBackupIfNeeded() {
    _scheduleBackupCheck();
  }

  /// Internal method to schedule a backup check
  static void _scheduleBackupCheck() {
    // Run backup check in background after a delay
    Future.delayed(const Duration(seconds: 30), () async {
      if (await shouldPerformBackup()) {
        await performAutomaticBackup();
      }
    });
  }

  /// Check if we should perform a backup now
  static Future<bool> shouldPerformBackup() async {
    if (!await isAutoBackupEnabled()) return false;
    if (!await isCloudBackupAvailable()) return false;

    final cloudService = _getCloudService();
    if (cloudService == null) return false;

    // For Android, check if user is signed in
    if (Platform.isAndroid && !_googleDriveService.isSignedIn) {
      return false;
    }

    return true;
  }

  static Future<void> _cleanupOldBackups() async {
    try {
      final backups = await listAvailableBackups();

      // Keep only the 5 most recent backups
      if (backups.length > 5) {
        final sortedBackups = List.from(backups);
        // Sort by date (newest first)
        sortedBackups.sort((a, b) {
          if (Platform.isAndroid) {
            return (b as DriveBackupFile).createdTime?.compareTo((a as DriveBackupFile).createdTime ?? DateTime.now()) ?? 0;
          } else {
            return (b as ICloudBackupFile).createdDate.compareTo((a as ICloudBackupFile).createdDate);
          }
        });

        // Delete old backups (keep first 5, delete the rest)
        for (int i = 5; i < sortedBackups.length; i++) {
          final backup = sortedBackups[i];
          String backupId;
          if (Platform.isAndroid) {
            backupId = (backup as DriveBackupFile).id;
          } else {
            backupId = (backup as ICloudBackupFile).relativePath;
          }
          await deleteBackup(backupId);
        }
      }
    } catch (e) {
      Logger.backupService('Error cleaning up old backups: $e');
    }
  }
  
  /// Perform automatic cloud backup
  static Future<bool> performAutomaticBackup() async {
    try {
      Logger.backupService('🔄 Starting automatic cloud backup...');

      if (!await isCloudBackupAvailable()) {
        Logger.backupService('❌ Cloud backup not available on this platform');
        return false;
      }

      final cloudService = _getCloudService();
      if (cloudService == null) {
        Logger.backupService('❌ No cloud service available');
        return false;
      }

      BackupResult result;
      if (Platform.isAndroid) {
        // For Android, check if signed in first
        if (!_googleDriveService.isSignedIn) {
          Logger.backupService('❌ Not signed into Google Drive - skipping auto backup');
          return false;
        }
        result = await _googleDriveService.uploadBackup();
      } else {
        result = await _iCloudService.uploadBackup();
      }

      if (result.success) {
        await _setLastBackupTime(DateTime.now());
        Logger.backupService('✅ Automatic cloud backup completed successfully');
        await _cleanupOldBackups();
        return true;
      } else {
        Logger.backupService('❌ Automatic cloud backup failed: ${result.error}');
        return false;
      }
    } catch (e) {
      Logger.backupService('❌ Automatic cloud backup error: $e');
      return false;
    }
  }

  /// Perform manual cloud backup
  static Future<BackupResult> performManualBackup() async {
    try {
      Logger.backupService('🔄 Starting manual cloud backup...');

      if (!await isCloudBackupAvailable()) {
        return BackupResult(false, error: 'Cloud backup not available on this platform');
      }

      final cloudService = _getCloudService();
      if (cloudService == null) {
        return BackupResult(false, error: 'No cloud service available');
      }

      BackupResult result;
      if (Platform.isAndroid) {
        result = await _googleDriveService.uploadBackup();
      } else {
        result = await _iCloudService.uploadBackup();
      }

      if (result.success) {
        await _setLastBackupTime(DateTime.now());
      }

      return result;
    } catch (e) {
      return BackupResult(false, error: 'Manual backup failed: ${e.toString()}');
    }
  }

  /// Check for cloud backups on app startup (for restore)
  static Future<void> checkForRestoreOnStartup() async {
    try {
      // Only check once per day to avoid annoying the user
      final lastCheck = await _getLastRestoreCheckTime();
      if (lastCheck != null && DateTime.now().difference(lastCheck).inHours < 24) {
        return;
      }

      if (!await isCloudBackupAvailable()) return;

      final cloudService = _getCloudService();
      if (cloudService == null) return;

      // Check if there are cloud backups available
      bool hasBackups = false;
      if (Platform.isAndroid && _googleDriveService.isSignedIn) {
        hasBackups = await _googleDriveService.hasBackupsAvailable();
      } else if (Platform.isIOS) {
        hasBackups = await _iCloudService.hasBackupsAvailable();
      }

      await _setLastRestoreCheckTime(DateTime.now());

      // If backups exist, you might want to notify the user or show a restore option
      if (hasBackups) {
        Logger.backupService('✅ Cloud backups found - user can restore from Backup & Export screen');
      }
    } catch (e) {
      Logger.backupService('Error checking for restore on startup: $e');
    }
  }

  /// Get backup status for UI display
  static Future<Map<String, dynamic>> getBackupStatus() async {
    try {
      final isAvailable = await isCloudBackupAvailable();
      final isEnabled = await isAutoBackupEnabled();
      final lastBackup = await getLastBackupTime();

      String platformType;
      bool isSignedIn = false;
      String? userEmail;

      if (Platform.isAndroid) {
        platformType = 'Google Drive';
        await _googleDriveService.initialize();
        isSignedIn = _googleDriveService.isSignedIn;
        userEmail = _googleDriveService.userEmail;
      } else if (Platform.isIOS) {
        platformType = 'iCloud';
        isSignedIn = await _iCloudService.isAvailable();
        userEmail = 'iCloud Account';
      } else {
        platformType = 'Not supported';
      }

      return {
        'available': isAvailable,
        'enabled': isEnabled,
        'type': platformType,
        'lastBackup': lastBackup,
        'isSignedIn': isSignedIn,
        'userEmail': userEmail,
        'intervalHours': await getBackupInterval(),
      };
    } catch (e) {
      return {
        'available': false,
        'enabled': false,
        'error': e.toString(),
      };
    }
  }

  /// List available cloud backups
  static Future<List<dynamic>> listAvailableBackups() async {
    try {
      if (!await isCloudBackupAvailable()) return [];

      if (Platform.isAndroid) {
        return await _googleDriveService.listBackups();
      } else if (Platform.isIOS) {
        return await _iCloudService.listBackups();
      }

      return [];
    } catch (e) {
      Logger.backupService('Error listing backups: $e');
      return [];
    }
  }

  /// Restore from a specific backup
  static Future<BackupResult> restoreFromBackup(String backupId) async {
    try {
      if (!await isCloudBackupAvailable()) {
        return BackupResult(false, error: 'Cloud backup not available');
      }

      if (Platform.isAndroid) {
        return await _googleDriveService.downloadAndRestoreBackup(backupId);
      } else if (Platform.isIOS) {
        return await _iCloudService.downloadAndRestoreBackup(backupId);
      }

      return BackupResult(false, error: 'Platform not supported');
    } catch (e) {
      return BackupResult(false, error: 'Restore failed: ${e.toString()}');
    }
  }

  /// Auto-restore: Get the most recent backup for quick restore
  static Future<dynamic> getMostRecentBackup() async {
    try {
      if (!await isCloudBackupAvailable()) return null;

      if (Platform.isAndroid && _googleDriveService.isSignedIn) {
        return await _googleDriveService.getMostRecentBackup();
      } else if (Platform.isIOS) {
        return await _iCloudService.getMostRecentBackup();
      }

      return null;
    } catch (e) {
      Logger.backupService('Error getting recent backup: $e');
      return null;
    }
  }

  /// Sign in to cloud service (Android only)
  static Future<bool> signInToCloudService() async {
    if (Platform.isAndroid) {
      return await _googleDriveService.signIn();
    }
    return true; // iOS doesn't need explicit sign-in
  }

  /// Sign out of cloud service (Android only)
  static Future<void> signOutOfCloudService() async {
    if (Platform.isAndroid) {
      await _googleDriveService.signOut();
    }
  }

  /// Settings management
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCloudBackupEnabledKey, enabled);

    if (enabled) {
      triggerBackupIfNeeded();
    }
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCloudBackupEnabledKey) ?? true; // Default enabled
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

  static Future<DateTime?> _getLastRestoreCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastRestoreCheckKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  static Future<void> _setLastRestoreCheckTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRestoreCheckKey, time.millisecondsSinceEpoch);
  }

  /// Delete a specific backup
  static Future<bool> deleteBackup(String backupId) async {
    try {
      if (Platform.isAndroid) {
        return await _googleDriveService.deleteBackup(backupId);
      } else if (Platform.isIOS) {
        return await _iCloudService.deleteBackup(backupId);
      }
      return false;
    } catch (e) {
      Logger.backupService('Error deleting backup: $e');
      return false;
    }
  }

  /// Manual test for debugging
  static Future<void> testCloudBackup() async {
    Logger.backupService('🧪 Testing cloud backup system...');

    final isAvailable = await isCloudBackupAvailable();
    Logger.backupService('📱 Cloud backup available: $isAvailable');

    if (!isAvailable) {
      Logger.backupService('❌ Cloud backup not available on this platform');
      return;
    }

    final status = await getBackupStatus();
    Logger.backupService('📊 Backup status: $status');

    if (Platform.isAndroid && !_googleDriveService.isSignedIn) {
      Logger.backupService('🔑 Not signed into Google Drive - attempting sign in...');
      final signedIn = await signInToCloudService();
      if (!signedIn) {
        Logger.backupService('❌ Failed to sign into Google Drive');
        return;
      }
      Logger.backupService('✅ Signed into Google Drive');
    }

    Logger.backupService('🔄 Performing test backup...');
    final backupResult = await performManualBackup();

    if (backupResult.success) {
      Logger.backupService('✅ Test backup successful: ${backupResult.message}');

      Logger.backupService('📋 Listing available backups...');
      final backups = await listAvailableBackups();
      Logger.backupService('📁 Found ${backups.length} backups');

    } else {
      Logger.backupService('❌ Test backup failed: ${backupResult.error}');
    }
  }
}