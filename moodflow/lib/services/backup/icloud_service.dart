import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:icloud_storage/icloud_storage.dart';
import '../backup/backup_service.dart';

class ICloudService {
  // Replace with your actual iCloud container ID from Apple Developer Console
  static const String _containerId = 'iCloud.com.oddologyinc.moodflow';
  static const String _backupFolderName = 'MoodFlow_Backups';

  /// Check if iCloud is available
  Future<bool> isAvailable() async {
    try {
      // Test iCloud availability by attempting to gather files
      await ICloudStorage.gather(containerId: _containerId);
      return true;
    } catch (e) {
      debugPrint('iCloud not available: $e');
      return false;
    }
  }

  /// Upload backup to iCloud
  Future<BackupResult> uploadBackup() async {
    try {
      // Check if iCloud is available
      if (!await isAvailable()) {
        return BackupResult(false, error: 'iCloud is not available. Please check your iCloud settings.');
      }

      // Export all data
      final exportData = await BackupService.exportAllData();
      final jsonString = jsonEncode(exportData.toJson());

      // Create temporary file
      final fileName = 'moodflow_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final tempFile = File('/tmp/$fileName');
      await tempFile.writeAsString(jsonString);

      // Upload to iCloud
      await ICloudStorage.upload(
        containerId: _containerId,
        filePath: tempFile.path,
        destinationRelativePath: '$_backupFolderName/$fileName',
        onProgress: (stream) {
          stream.listen(
                (progress) => debugPrint('Upload Progress: $progress'),
            onDone: () => debugPrint('Upload Completed'),
            onError: (err) => debugPrint('Upload Error: $err'),
            cancelOnError: true,
          );
        },
      );

      // Clean up temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return BackupResult(
        true,
        message: 'Backup uploaded successfully to iCloud. File: $fileName',
      );
    } catch (e) {
      return BackupResult(false, error: 'iCloud upload failed: ${e.toString()}');
    }
  }

  /// List available backups
  Future<List<ICloudBackupFile>> listBackups() async {
    try {
      if (!await isAvailable()) return [];

      final files = await ICloudStorage.gather(containerId: _containerId);

      // Filter for backup files in our folder
      final backupFiles = files.where((file) =>
      file.relativePath.startsWith('$_backupFolderName/') &&
          file.relativePath.contains('moodflow_backup_')
      ).toList();

      // Sort by modification date (newest first)
      backupFiles.sort((a, b) => b.contentChangedDate.compareTo(a.contentChangedDate));

      return backupFiles.map((file) => ICloudBackupFile(
        relativePath: file.relativePath,
        name: file.relativePath.split('/').last,
        createdDate: file.contentChangedDate,
        downloadStatus: file.downloadStatus,
      )).toList();
    } catch (e) {
      debugPrint('Error listing iCloud backups: $e');
      return [];
    }
  }

  /// Download and restore backup
  Future<BackupResult> downloadAndRestoreBackup(String relativePath) async {
    try {
      if (!await isAvailable()) {
        return BackupResult(false, error: 'iCloud is not available');
      }

      // Create temporary download path
      final fileName = relativePath.split('/').last;
      final tempDownloadPath = '/tmp/downloaded_$fileName';

      // Download from iCloud
      await ICloudStorage.download(
        containerId: _containerId,
        relativePath: relativePath,
        destinationFilePath: tempDownloadPath,
        onProgress: (stream) {
          stream.listen(
                (progress) => debugPrint('Download Progress: $progress'),
            onDone: () => debugPrint('Download Completed'),
            onError: (err) => debugPrint('Download Error: $err'),
            cancelOnError: true,
          );
        },
      );

      // Read downloaded file
      final downloadedFile = File(tempDownloadPath);
      if (!await downloadedFile.exists()) {
        return BackupResult(false, error: 'Downloaded file not found');
      }

      final jsonString = await downloadedFile.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final exportData = MoodDataExport.fromJson(jsonData);

      // Clean up temporary file
      await downloadedFile.delete();

      // Import data
      final importResult = await BackupService.importData(exportData);

      if (importResult.success) {
        return BackupResult(
          true,
          message: 'Backup restored successfully from iCloud. '
              'Imported ${importResult.importedMoods} moods and ${importResult.importedGoals} goals.',
        );
      } else {
        return BackupResult(false, error: importResult.error ?? 'Import failed');
      }
    } catch (e) {
      return BackupResult(false, error: 'iCloud download failed: ${e.toString()}');
    }
  }

  /// Delete backup from iCloud
  Future<bool> deleteBackup(String relativePath) async {
    try {
      if (!await isAvailable()) return false;

      await ICloudStorage.delete(
        containerId: _containerId,
        relativePath: relativePath,
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting iCloud backup: $e');
      return false;
    }
  }

  /// Check download status of a file
  Future<String> getDownloadStatus(String relativePath) async {
    try {
      final files = await ICloudStorage.gather(containerId: _containerId);
      final file = files.firstWhere(
            (f) => f.relativePath == relativePath,
        orElse: () => throw Exception('File not found'),
      );

      switch (file.downloadStatus) {
        case 'downloaded':
          return 'Available offline';
        case 'downloading':
          return 'Downloading...';
        case 'not_downloaded':
          return 'Cloud only';
        default:
          return 'Unknown';
      }
    } catch (e) {
      return 'Error checking status';
    }
  }
}

class ICloudBackupFile {
  final String relativePath;
  final String name;
  final DateTime createdDate;
  final String downloadStatus;

  ICloudBackupFile({
    required this.relativePath,
    required this.name,
    required this.createdDate,
    required this.downloadStatus,
  });

  String get formattedDate {
    return '${createdDate.day}/${createdDate.month}/${createdDate.year} ${createdDate.hour}:${createdDate.minute.toString().padLeft(2, '0')}';
  }

  String get statusIcon {
    switch (downloadStatus) {
      case 'downloaded':
        return '📱'; // Available offline
      case 'downloading':
        return '⬇️'; // Downloading
      case 'not_downloaded':
        return '☁️'; // Cloud only
      default:
        return '❓'; // Unknown
    }
  }

  String get statusText {
    switch (downloadStatus) {
      case 'downloaded':
        return 'Available offline';
      case 'downloading':
        return 'Downloading...';
      case 'not_downloaded':
        return 'Cloud only';
      default:
        return 'Unknown status';
    }
  }
}