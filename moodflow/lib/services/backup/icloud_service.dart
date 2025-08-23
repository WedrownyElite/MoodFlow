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
    if (!Platform.isIOS) {
      return false;
    } else {
      return true;
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
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');
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
        message: 'Backup uploaded successfully to iCloud (${_formatFileSize(jsonString.length)})',
      );
    } catch (e) {
      return BackupResult(false, error: 'iCloud upload failed: ${e.toString()}');
    }
  }

  /// List available backups (FIXED: Safe property access)
  Future<List<ICloudBackupFile>> listBackups() async {
    try {
      if (!await isAvailable()) return [];

      final files = await ICloudStorage.gather(containerId: _containerId);

      // Filter for backup files in our folder
      final backupFiles = <ICloudFile>[];

      for (final file in files) {
        try {
          // FIXED: Safe property access with try-catch
          final relativePath = file.relativePath;
          if (relativePath.startsWith('$_backupFolderName/') &&
              relativePath.contains('moodflow_backup_')) {
            backupFiles.add(file);
          }
        } catch (e) {
          // Skip files we can't access
          debugPrint('Skipping file due to property access error: $e');
          continue;
        }
      }

      // Sort by filename (which contains timestamp) since we can't reliably access date properties
      backupFiles.sort((a, b) {
        try {
          final aName = _safeGetFileName(a);
          final bName = _safeGetFileName(b);

          // Extract timestamp from filename for sorting
          final aTimestamp = _extractTimestampFromFileName(aName);
          final bTimestamp = _extractTimestampFromFileName(bName);

          return bTimestamp.compareTo(aTimestamp); // Newest first
        } catch (e) {
          debugPrint('Error sorting files: $e');
          return 0;
        }
      });

      return backupFiles.map((file) => ICloudBackupFile(
        relativePath: _safeGetRelativePath(file),
        name: _safeGetFileName(file),
        createdDate: _safeGetFileDate(file),
        downloadStatus: _safeGetDownloadStatus(file),
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
      final tempDir = Directory.systemTemp;
      final tempDownloadPath = '${tempDir.path}/downloaded_$fileName';

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
          message: 'Backup restored successfully from iCloud! '
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

  /// Check if there are backups available
  Future<bool> hasBackupsAvailable() async {
    try {
      final backups = await listBackups();
      return backups.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get most recent backup for auto-restore
  Future<ICloudBackupFile?> getMostRecentBackup() async {
    try {
      final backups = await listBackups();
      if (backups.isNotEmpty) {
        return backups.first; // Already sorted by timestamp desc
      }
      return null;
    } catch (e) {
      debugPrint('Error getting recent backup: $e');
      return null;
    }
  }

  /// Perform automatic backup
  Future<bool> performAutomaticBackup() async {
    try {
      if (!await isAvailable()) return false;

      final result = await uploadBackup();
      return result.success;
    } catch (e) {
      debugPrint('Automatic backup failed: $e');
      return false;
    }
  }

  // FIXED: Safe property access methods
  String _safeGetRelativePath(ICloudFile file) {
    try {
      return file.relativePath;
    } catch (e) {
      return 'unknown_path';
    }
  }

  String _safeGetFileName(ICloudFile file) {
    try {
      return file.relativePath.split('/').last;
    } catch (e) {
      return 'unknown_file';
    }
  }

  DateTime _safeGetFileDate(ICloudFile file) {
    try {
      // Try to extract timestamp from filename first
      final fileName = _safeGetFileName(file);
      final timestamp = _extractTimestampFromFileName(fileName);
      if (timestamp > 0) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }

      // Try to access file properties (may not work reliably)
      final fileString = file.toString();
      final dateRegex = RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}');
      final match = dateRegex.firstMatch(fileString);

      if (match != null) {
        return DateTime.parse(match.group(0)!);
      }
    } catch (e) {
      debugPrint('Could not get file date: $e');
    }

    // Fallback to current time
    return DateTime.now();
  }

  String _safeGetDownloadStatus(ICloudFile file) {
    try {
      // Since we can't reliably access download status, return a safe default
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  int _extractTimestampFromFileName(String fileName) {
    try {
      // Files are named like: moodflow_backup_1234567890123.json
      final timestampRegex = RegExp(r'(\d{13})'); // 13-digit timestamp
      final match = timestampRegex.firstMatch(fileName);

      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (e) {
      debugPrint('Could not extract timestamp from $fileName: $e');
    }

    return 0;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        return 'In iCloud';
    }
  }
}