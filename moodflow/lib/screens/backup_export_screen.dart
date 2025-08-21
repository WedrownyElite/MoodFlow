import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/export_service.dart';
import '../services/backup/google_drive_service.dart';
import '../services/backup/icloud_service.dart';
import '../services/data/backup_models.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup/auto_backup_service.dart';

class BackupExportScreen extends StatefulWidget {
  const BackupExportScreen({super.key});

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Google Drive
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  List<DriveBackupFile> _driveBackups = [];
  bool _isDriveLoading = false;

  // iCloud
  final ICloudService _iCloudService = ICloudService();
  List<ICloudBackupFile> _iCloudBackups = [];
  bool _isICloudLoading = false;
  bool _isICloudAvailable = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkICloudAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkICloudAvailability() async {
    if (Platform.isIOS) {
      final available = await _iCloudService.isAvailable();
      setState(() {
        _isICloudAvailable = available;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Export'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.file_download), text: 'Export'),
            Tab(icon: Icon(Icons.cloud), text: 'Cloud Backup'),
            Tab(icon: Icon(Icons.cloud_upload), text: 'Restore'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(),
          _buildBackupTab(),
          _buildRestoreTab(),
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Your Data',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Create local files of your mood data for sharing or personal records.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // CSV Export
          _buildExportCard(
            title: 'CSV Export',
            description: 'Export your mood data as a spreadsheet file',
            icon: Icons.table_chart,
            color: Colors.green,
            onTap: _exportToCsv,
          ),

          const SizedBox(height: 16),

          // PDF Export
          _buildExportCard(
            title: 'PDF Report',
            description: 'Generate a comprehensive PDF report with statistics',
            icon: Icons.picture_as_pdf,
            color: Colors.red,
            onTap: _exportToPdf,
          ),

          const SizedBox(height: 24),

          // Export Options
          const Text(
            'Export Options',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildDateRangeSelector(),
        ],
      ),
    );
  }

  Widget _buildBackupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cloud Backup',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically backup your data to the cloud for safekeeping.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Google Drive Backup
          _buildCloudBackupCard(
            title: 'Google Drive',
            description: _googleDriveService.isSignedIn
                ? 'Signed in as ${_googleDriveService.userEmail}'
                : 'Sign in to backup to Google Drive',
            icon: Icons.cloud,
            color: Colors.blue,
            isSignedIn: _googleDriveService.isSignedIn,
            onBackup: _backupToGoogleDrive,
            onSignOut: _signOutGoogleDrive,
          ),

          const SizedBox(height: 16),

          // iCloud Backup (iOS only)
          if (Platform.isIOS) ...[
            _buildCloudBackupCard(
              title: 'iCloud',
              description: _isICloudAvailable
                  ? 'iCloud is available for backup'
                  : 'iCloud is not available',
              icon: Icons.cloud_circle,
              color: Colors.grey,
              isSignedIn: _isICloudAvailable,
              onBackup: _isICloudAvailable ? _backupToICloud : null,
            ),
            const SizedBox(height: 16),
          ],

          // Backup History
          const Text(
            'Recent Backups',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_googleDriveService.isSignedIn) ...[
            _buildBackupHistorySection('Google Drive', _driveBackups, _isDriveLoading, _loadGoogleDriveBackups),
          ],

          if (_isICloudAvailable && Platform.isIOS) ...[
            _buildBackupHistorySection('iCloud', _iCloudBackups, _isICloudLoading, _loadICloudBackups),
          ],
        ],
      ),
    );
  }

  Widget _buildRestoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Restore Data',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Restore your mood data from previous backups.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Warning banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Restoring will not overwrite existing data. Duplicate entries will be skipped.',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // File Import
          _buildRestoreCard(
            title: 'Import from File',
            description: 'Import from a previously exported backup file',
            icon: Icons.file_upload,
            color: Colors.purple,
            onTap: _importFromFile,
          ),

          const SizedBox(height: 16),

          // Google Drive Restore
          if (_googleDriveService.isSignedIn && _driveBackups.isNotEmpty) ...[
            const Text(
              'Google Drive Backups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._driveBackups.map((backup) => _buildBackupRestoreCard(
              title: backup.name,
              subtitle: backup.formattedDate,
              size: backup.formattedSize,
              onRestore: () => _restoreFromGoogleDrive(backup.id),
            )).toList(),
            const SizedBox(height: 16),
          ],

          // iCloud Restore
          if (_isICloudAvailable && _iCloudBackups.isNotEmpty) ...[
            const Text(
              'iCloud Backups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._iCloudBackups.map((backup) => _buildBackupRestoreCard(
              title: backup.name,
              subtitle: backup.formattedDate,
              size: backup.statusText,
              onRestore: () => _restoreFromICloud(backup.relativePath),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloudBackupCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSignedIn,
    VoidCallback? onBackup,
    VoidCallback? onSignOut,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onBackup != null)
                  ElevatedButton.icon(
                    onPressed: onBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Backup Now'),
                  ),
                if (isSignedIn && onSignOut != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Sign Out'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupHistorySection(String title, List items, bool isLoading, VoidCallback onLoad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: isLoading ? null : onLoad,
              icon: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (items.isEmpty && !isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No backups found'),
          )
        else
          ...items.take(3).map((item) => ListTile(
            leading: const Icon(Icons.cloud_done),
            title: Text(item.name ?? 'Backup'),
            subtitle: Text(item.formattedDate ?? ''),
            trailing: Text(item.formattedSize ?? ''),
          )).toList(),
      ],
    );
  }

  Widget _buildBackupRestoreCard({
    required String title,
    required String subtitle,
    required String size,
    required VoidCallback onRestore,
  }) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_download),
        title: Text(title),
        subtitle: Text('$subtitle • $size'),
        trailing: ElevatedButton(
          onPressed: onRestore,
          child: const Text('Restore'),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    // This would implement date range selection for exports
    // For now, we'll just show a placeholder
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Currently exporting all available data',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement date range picker
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Date range selection coming soon')),
                );
              },
              child: const Text('Select Date Range'),
            ),
          ],
        ),
      ),
    );
  }

  // Export Methods
  Future<void> _exportToCsv() async {
    try {
      _showLoadingDialog('Exporting CSV...');

      final filePath = await ExportService.exportToCSV();

      Navigator.of(context).pop(); // Close loading dialog

      await ExportService.shareFile(filePath, subject: 'MoodFlow Data Export (CSV)');

      _showSuccessMessage('CSV export completed successfully!');
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('Failed to export CSV: $e');
    }
  }

  Future<void> _exportToPdf() async {
    try {
      _showLoadingDialog('Generating PDF...');

      final filePath = await ExportService.exportToPDF();

      Navigator.of(context).pop(); // Close loading dialog

      await ExportService.shareFile(filePath, subject: 'MoodFlow Report (PDF)');

      _showSuccessMessage('PDF export completed successfully!');
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('Failed to export PDF: $e');
    }
  }

  // Google Drive Methods
  Future<void> _backupToGoogleDrive() async {
    if (!_googleDriveService.isSignedIn) {
      final signedIn = await _googleDriveService.signIn();
      if (!signedIn) {
        _showErrorMessage('Failed to sign in to Google Drive');
        return;
      }
    }

    try {
      _showLoadingDialog('Backing up to Google Drive...');

      final result = await _googleDriveService.uploadBackup();

      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        _showSuccessMessage(result.message ?? 'Backup completed successfully!');
        _loadGoogleDriveBackups();
      } else {
        _showErrorMessage(result.error ?? 'Backup failed');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('Backup failed: $e');
    }
  }

  Future<void> _signOutGoogleDrive() async {
    await _googleDriveService.signOut();
    setState(() {
      _driveBackups.clear();
    });
    _showSuccessMessage('Signed out of Google Drive');
  }

  Future<void> _loadGoogleDriveBackups() async {
    setState(() => _isDriveLoading = true);

    try {
      final backups = await _googleDriveService.listBackups();
      setState(() {
        _driveBackups = backups;
        _isDriveLoading = false;
      });
    } catch (e) {
      setState(() => _isDriveLoading = false);
      _showErrorMessage('Failed to load Google Drive backups: $e');
    }
  }

  Future<void> _restoreFromGoogleDrive(String fileId) async {
    final confirmed = await _showRestoreConfirmation();
    if (!confirmed) return;

    try {
      _showLoadingDialog('Restoring from Google Drive...');

      final result = await _googleDriveService.downloadAndRestoreBackup(fileId);

      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        _showSuccessMessage(result.message ?? 'Restore completed successfully!');
      } else {
        _showErrorMessage(result.error ?? 'Restore failed');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('Restore failed: $e');
    }
  }

  // iCloud Methods (iOS only)
  Future<void> _backupToICloud() async {
    try {
      _showLoadingDialog('Backing up to iCloud...');

      final result = await _iCloudService.uploadBackup();

      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        _showSuccessMessage(result.message ?? 'iCloud backup completed!');
        _loadICloudBackups();
      } else {
        _showErrorMessage(result.error ?? 'iCloud backup failed');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('iCloud backup failed: $e');
    }
  }

  Future<void> _loadICloudBackups() async {
    setState(() => _isICloudLoading = true);

    try {
      final backups = await _iCloudService.listBackups();
      setState(() {
        _iCloudBackups = backups;
        _isICloudLoading = false;
      });
    } catch (e) {
      setState(() => _isICloudLoading = false);
      _showErrorMessage('Failed to load iCloud backups: $e');
    }
  }

  Future<void> _restoreFromICloud(String relativePath) async {
    final confirmed = await _showRestoreConfirmation();
    if (!confirmed) return;

    try {
      _showLoadingDialog('Restoring from iCloud...');

      final result = await _iCloudService.downloadAndRestoreBackup(relativePath);

      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        _showSuccessMessage(result.message ?? 'iCloud restore completed!');
      } else {
        _showErrorMessage(result.error ?? 'iCloud restore failed');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('iCloud restore failed: $e');
    }
  }

  // File Import
  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          _showLoadingDialog('Importing backup file...');

          // Read and parse the file
          final fileContent = await File(file.path!).readAsString();
          final jsonData = jsonDecode(fileContent) as Map<String, dynamic>;
          final exportData = MoodDataExport.fromJson(jsonData);

          // Import the data
          final importResult = await BackupService.importData(exportData);

          Navigator.of(context).pop(); // Close loading dialog

          if (importResult.success) {
            _showSuccessMessage(
                'Import completed! Added ${importResult.importedMoods} moods and ${importResult.importedGoals} goals.'
            );
          } else {
            _showErrorMessage(importResult.error ?? 'Import failed');
          }
        }
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if open
      _showErrorMessage('Import failed: $e');
    }
  }

  // Helper Methods
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<bool> _showRestoreConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'This will import data from the backup. Existing data will not be overwritten. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildAutoBackupSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: AutoBackupService.getBackupStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data ?? {};
        final isAvailable = status['available'] ?? false;
        final isEnabled = status['enabled'] ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAvailable ? Icons.backup : Icons.backup_outlined,
                      color: isAvailable ? Colors.green : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Platform.isAndroid ? 'Android Auto Backup' : 'iCloud Backup',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isAvailable
                                ? 'Automatic backup is enabled'
                                : 'Not available on this device',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  Platform.isAndroid
                      ? 'Your mood data is automatically backed up to Google Drive. When you reinstall the app, your data will be restored automatically.'
                      : 'Your mood data syncs with iCloud and will be available on all your iOS devices.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),

                if (isAvailable) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await AutoBackupService.requestBackup();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(Platform.isAndroid
                              ? 'Backup requested - will complete when device is charging and on WiFi'
                              : 'iCloud sync triggered'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.backup),
                    label: Text(Platform.isAndroid ? 'Request Backup' : 'Sync Now'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}