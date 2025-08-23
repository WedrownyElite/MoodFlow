import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../backup/backup_service.dart';
import '../data/backup_models.dart';

class GoogleDriveService {
  static const List<String> _scopes = [drive.DriveApi.driveFileScope];
  static const String _appDataFolderName = 'MoodFlow_Backups';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );
  GoogleSignInAccount? _currentUser;

  /// Check if user is signed in
  bool get isSignedIn => _currentUser != null;

  /// Get current user email
  String? get userEmail => _currentUser?.email;

  /// Sign in to Google Drive
  Future<bool> signIn() async {
    try {
      // First try silent sign-in
      _currentUser = await _googleSignIn.signInSilently();

      if (_currentUser != null) {
        debugPrint('✅ Silent sign-in successful: ${_currentUser!.email}');
        return true;
      }

      // If silent sign-in fails, prompt for interactive sign-in
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        debugPrint('✅ Interactive sign-in successful: ${_currentUser!.email}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return false;
    }
  }

  /// Sign out from Google Drive
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Create authenticated HTTP client
  Future<AuthClient?> _getAuthClient() async {
    if (_currentUser == null) {
      final signedIn = await signIn();
      if (!signedIn) return null;
    }

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final accessToken = authHeaders['Authorization']?.replaceFirst('Bearer ', '');

      if (accessToken == null) {
        debugPrint('No access token available');
        return null;
      }

      return authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            accessToken,
            DateTime.now().add(const Duration(hours: 1)).toUtc(),
          ),
          null,
          _scopes,
        ),
      );
    } catch (e) {
      debugPrint('Error creating auth client: $e');
      return null;
    }
  }

  /// Get or create app data folder
  Future<String?> _getAppDataFolder(drive.DriveApi driveApi) async {
    try {
      // Search for existing app data folder
      final folderQuery = await driveApi.files.list(
        q: "name='$_appDataFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );

      if (folderQuery.files != null && folderQuery.files!.isNotEmpty) {
        return folderQuery.files!.first.id;
      }

      // Create new folder if it doesn't exist
      final folder = drive.File()
        ..name = _appDataFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      debugPrint('Error getting app data folder: $e');
      return null;
    }
  }

  /// Upload backup to Google Drive
  Future<BackupResult> uploadBackup() async {
    try {
      final client = await _getAuthClient();
      if (client == null) {
        return BackupResult(false, error: 'Authentication failed');
      }

      final driveApi = drive.DriveApi(client);
      final folderId = await _getAppDataFolder(driveApi);

      if (folderId == null) {
        client.close();
        return BackupResult(false, error: 'Failed to create app folder');
      }

      // Export all data
      final exportData = await BackupService.exportAllData();
      final jsonString = jsonEncode(exportData.toJson());
      final bytes = utf8.encode(jsonString);

      // Create file metadata
      final fileName = 'moodflow_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..description = 'MoodFlow backup created on ${DateTime.now().toIso8601String()}';

      // Upload file
      final media = drive.Media(Stream.fromIterable([bytes]), bytes.length);
      final uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      client.close();

      // Save backup info locally for quick access
      await _saveBackupInfo(fileName, uploadedFile.id ?? '', bytes.length);

      return BackupResult(
        true,
        message: 'Backup uploaded successfully to Google Drive (${_formatFileSize(bytes.length)})',
      );
    } catch (e) {
      return BackupResult(false, error: 'Upload failed: ${e.toString()}');
    }
  }

  /// List available backups (Removed problematic $fields)
  Future<List<DriveBackupFile>> listBackups() async {
    try {
      final client = await _getAuthClient();
      if (client == null) return [];

      final driveApi = drive.DriveApi(client);
      final folderId = await _getAppDataFolder(driveApi);

      if (folderId == null) {
        client.close();
        return [];
      }

      // Removed the problematic $fields parameter
      final query = await driveApi.files.list(
        q: "parents in '$folderId' and name contains 'moodflow_backup_' and trashed=false",
        orderBy: 'createdTime desc',
        pageSize: 50,
        $fields: 'files(id,name,createdTime,size,description)', // Add this line
      );

      client.close();

      return query.files?.map((file) => DriveBackupFile(
        id: file.id ?? 'unknown',
        name: file.name ?? 'Unknown Backup',
        createdTime: file.createdTime ?? DateTime.now(),
        size: file.size?.toString(),
        description: file.description,
      )).toList() ?? [];
    } catch (e) {
      debugPrint('Error listing backups: $e'); 
      return [];
    }
  }

  /// Download and restore backup
  Future<BackupResult> downloadAndRestoreBackup(String fileId) async {
    try {
      final client = await _getAuthClient();
      if (client == null) {
        return BackupResult(false, error: 'Authentication failed');
      }

      final driveApi = drive.DriveApi(client);

      // Download file
      final media = await driveApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia
      );

      if (media is! drive.Media) {
        client.close();
        return BackupResult(false, error: 'Failed to download backup file');
      }

      // Read file content
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final exportData = MoodDataExport.fromJson(jsonData);

      client.close();

      // Import data
      final importResult = await BackupService.importData(exportData);

      if (importResult.success) {
        return BackupResult(
          true,
          message: 'Backup restored successfully! '
              'Imported ${importResult.importedMoods} moods and ${importResult.importedGoals} goals.',
        );
      } else {
        return BackupResult(false, error: importResult.error ?? 'Import failed');
      }
    } catch (e) {
      return BackupResult(false, error: 'Download failed: ${e.toString()}');
    }
  }

  /// Delete backup from Google Drive
  Future<bool> deleteBackup(String fileId) async {
    try {
      final client = await _getAuthClient();
      if (client == null) return false;

      final driveApi = drive.DriveApi(client);
      await driveApi.files.delete(fileId);

      client.close();
      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Save backup info locally for quick reference
  Future<void> _saveBackupInfo(String fileName, String fileId, int size) async {
    // This could save to SharedPreferences for quick access to recent backups
    // without needing to query Google Drive every time
  }

  /// Check if there are backups available (quick check)
  Future<bool> hasBackupsAvailable() async {
    try {
      final backups = await listBackups();
      return backups.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Auto-restore: Check for recent backups and offer to restore
  Future<DriveBackupFile?> getMostRecentBackup() async {
    try {
      final backups = await listBackups();
      if (backups.isNotEmpty) {
        return backups.first; // Already sorted by creation time desc
      }
      return null;
    } catch (e) {
      debugPrint('Error getting recent backup: $e');
      return null;
    }
  }

  /// Perform automatic backup (call this after mood changes)
  Future<bool> performAutomaticBackup() async {
    try {
      // Only backup if signed in
      if (!isSignedIn) return false;

      // Check if enough time has passed since last backup
      // (you might want to implement throttling)

      final result = await uploadBackup();
      return result.success;
    } catch (e) {
      debugPrint('Automatic backup failed: $e');
      return false;
    }
  }

  Future<void> initialize() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        debugPrint('✅ User already signed in: ${_currentUser!.email}');
      } else {
        debugPrint('❌ No existing sign-in found');
      }
    } catch (e) {
      debugPrint('Error checking sign-in status: $e');
      _currentUser = null;
    }
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DriveBackupFile {
  final String id;
  final String name;
  final DateTime? createdTime;
  final String? size;
  final String? description;

  DriveBackupFile({
    required this.id,
    required this.name,
    this.createdTime,
    this.size,
    this.description,
  });

  String get formattedSize {
    if (size == null) return 'Unknown size';
    final bytes = int.tryParse(size!) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    if (createdTime == null) return 'Unknown date';
    return '${createdTime!.day}/${createdTime!.month}/${createdTime!.year} ${createdTime!.hour}:${createdTime!.minute.toString().padLeft(2, '0')}';
  }
}