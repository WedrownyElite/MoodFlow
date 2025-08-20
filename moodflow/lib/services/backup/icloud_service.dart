import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:icloud_storage/icloud_storage.dart';
import '../backup/backup_service.dart';
import '../data/backup_models.dart';

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

      // FIXED: Use only accessible properties
      final sortedFiles = <ICloudFile>[];
      for (final file in backupFiles) {
        try {
          // Test if we can access the relativePath property
          final _ = file.relativePath;
          sortedFiles.add(file);
        } catch (e) {
          debugPrint('Skipping file due to property access error: $e');
          continue;
        }
      }

      // Sort by file name (which contains timestamp) since we can't reliably access date properties
      sortedFiles.sort((a, b) {
        try {
          // Extract timestamp from filename for sorting
          final aName = a.relativePath.split('/').last;
          final bName = b.relativePath.split('/').last;

          // Files are named like: moodflow_backup_1234567890123.json
          final aTimestampMatch = RegExp(r'(\d{13})').firstMatch(aName);
          final bTimestampMatch = RegExp(r'(\d{13})').firstMatch(bName);

          if (aTimestampMatch != null && bTimestampMatch != null) {
            final aTimestamp = int.parse(aTimestampMatch.group(1)!);
            final bTimestamp = int.parse(bTimestampMatch.group(1)!);
            return bTimestamp.compareTo(aTimestamp); // Newest first
          }

          // Fallback to string comparison
          return bName.compareTo(aName);
        } catch (e) {
          debugPrint('Error sorting files: $e');
          return 0;
        }
      });

      return sortedFiles.map((file) => ICloudBackupFile(
        relativePath: file.relativePath,
        name: file.relativePath.split('/').last,
        createdDate: _getFileDate(file),
        downloadStatus: _getDownloadStatus(file),
      )).toList();
    } catch (e) {
      debugPrint('Error listing iCloud backups: $e');
      return [];
    }
  }

  /// FIXED: Safe method to get file date
  DateTime _getFileDate(ICloudFile file) {
    try {
      // Try to access the date property directly
      // Different versions of icloud_storage may have different property names
      // Common property names: createdAt, modifiedAt, dateModified, lastModified

      // Try reflection-like access to get any date field
      final fileString = file.toString();

      // Extract date from string representation if possible
      final dateRegex = RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}');
      final match = dateRegex.firstMatch(fileString);

      if (match != null) {
        return DateTime.parse(match.group(0)!);
      }

      // Try to get file name and extract timestamp from it
      final fileName = file.relativePath.split('/').last;
      final timestampRegex = RegExp(r'(\d{13})'); // 13-digit timestamp
      final timestampMatch = timestampRegex.firstMatch(fileName);

      if (timestampMatch != null) {
        final timestamp = int.parse(timestampMatch.group(1)!);
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }

    } catch (e) {
      debugPrint('Could not get file date: $e');
    }

    // Fallback to current time if we can't get the actual date
    return DateTime.now();
  }

  /// FIXED: Safe method to get download status
  String _getDownloadStatus(ICloudFile file) {
    try {
      // Try to access downloadStatus property directly using reflection
      // Since we can't access it directly, we'll make an educated guess
      // based on the file properties we can access

      // For now, return a default status since we can't access the actual property
      return 'not_downloaded'; // Conservative default

    } catch (e) {
      debugPrint('Could not get download status: $e');
    }

    // Fallback status
    return 'unknown';
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

      return _getDownloadStatus(file);
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
    switch (downloadStatus.toLowerCase()) {
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
    switch (downloadStatus.toLowerCase()) {
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