import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_backup_service.dart';
import '../utils/logger.dart';

class StartupRestoreService {
  static const String _lastRestoreCheckKey = 'last_startup_restore_check';
  static const String _hasShownRestorePromptKey = 'has_shown_restore_prompt';

  /// Check if we should show restore prompt on app startup
  static Future<void> checkAndPromptRestore(BuildContext context) async {
    try {
      // Only check once per day to avoid being annoying
      if (!await _shouldCheckForRestore()) return;

      // Mark that we've checked today
      await _markRestoreCheckTime();

      // Check if user has any existing data
      if (await _hasExistingMoodData()) {
          Logger.backupService('User has existing data, skipping restore prompt');
        return;
      }

      // Check if we've already shown the restore prompt
      if (await _hasShownRestorePrompt()) {
        Logger.backupService('Already shown restore prompt, skipping');
        return;
      }

      // Check for available cloud backups
      final hasBackups = await _hasAvailableCloudBackups();
      if (!hasBackups) {
        Logger.backupService('No cloud backups available');
        return;
      }

      // Show restore prompt
      await _showRestorePrompt(context);

    } catch (e) {
      Logger.backupService('Error in startup restore check: $e');
    }
  }

  static Future<bool> _shouldCheckForRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastRestoreCheckKey);

    if (lastCheck == null) return true;

    final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
    final now = DateTime.now();

    return now.difference(lastCheckTime).inHours >= 24;
  }

  static Future<void> _markRestoreCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRestoreCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> _hasExistingMoodData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    return allKeys.any((key) => key.startsWith('mood_'));
  }

  static Future<bool> _hasShownRestorePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownRestorePromptKey) ?? false;
  }

  static Future<void> _markRestorePromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownRestorePromptKey, true);
  }

  static Future<bool> _hasAvailableCloudBackups() async {
    if (!await RealCloudBackupService.isCloudBackupAvailable()) return false;

    try {
      if (Platform.isAndroid) {
        // For Android, try to sign in and check for backups
        final signedIn = await RealCloudBackupService.signInToCloudService();
        if (!signedIn) return false;
      }

      final backups = await RealCloudBackupService.listAvailableBackups();
      return backups.isNotEmpty;
    } catch (e) {
      Logger.backupService('Error checking for available backups: $e');
      return false;
    }
  }

  static Future<void> _showRestorePrompt(BuildContext context) async {
    await _markRestorePromptShown();

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_download, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Expanded(child: Text('Restore Your Data?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We found mood tracking data backed up to your cloud account.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Would you like to restore:'),
            const SizedBox(height: 8),
            const Text('• Your mood history'),
            const Text('• Your goals and progress'),
            const Text('• Your notification settings'),
            const SizedBox(height: 12),
            Text(
              'This will not overwrite any existing data.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _performAutomaticRestore(context);
    }
  }

  static Future<void> _performAutomaticRestore(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Restoring your data...')),
          ],
        ),
      ),
    );

    try {
      // Get the most recent backup
      final mostRecentBackup = await RealCloudBackupService.getMostRecentBackup();

      if (mostRecentBackup == null) {
        throw Exception('No backup found');
      }

      // Restore from the most recent backup
      String backupId;
      if (Platform.isAndroid) {
        backupId = mostRecentBackup.id; // Google Drive file ID
      } else {
        backupId = mostRecentBackup.relativePath; // iCloud relative path
      }

      final result = await RealCloudBackupService.restoreFromBackup(backupId);

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show result
      if (context.mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Data restored successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restore failed: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Reset restore prompt (for testing)
  static Future<void> resetRestorePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasShownRestorePromptKey);
    await prefs.remove(_lastRestoreCheckKey);
  }
}