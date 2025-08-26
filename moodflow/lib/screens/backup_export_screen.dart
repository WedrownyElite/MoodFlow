import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/export_service.dart';
import '../services/backup/google_drive_service.dart';
import '../services/backup/icloud_service.dart';
import '../services/data/backup_models.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup/cloud_backup_service.dart';

// REMOVE FOR PRODUCTION (CUSTOM CSV IMPORT)
// Also delete the imports directory, and widgets/custom_csv_import_dialog.dart
import '../services/import/custom_csv_importer.dart';
import '../widgets/custom_csv_import_dialog.dart';

enum ExportType { csv, pdf }

class BackupExportScreen extends StatefulWidget {
  final int? initialTabIndex;
  const BackupExportScreen({super.key, this.initialTabIndex});

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
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    _checkICloudAvailability();
    _initializeGoogleDrive();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeGoogleDrive() async {
    await _googleDriveService.initialize();
    if (mounted) {
      setState(() {}); // Refresh UI to show correct sign-in status
    }
  }

  Future<void> _checkICloudAvailability() async {
    if (Platform.isIOS) {
      final available = await _iCloudService.isAvailable();
      if (mounted) {
        setState(() {
          _isICloudAvailable = available;
        });
      }
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
            Tab(icon: Icon(Icons.drive_folder_upload), text: 'Drive Backup'),
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
          _buildAdvancedExportCard(
            title: 'CSV Export',
            description: 'Export selected data as a spreadsheet file',
            icon: Icons.table_chart,
            color: Colors.green,
            onTap: () => _showExportOptionsDialog(ExportType.csv),
          ),

          const SizedBox(height: 16),

          // PDF Export
          _buildAdvancedExportCard(
            title: 'PDF Report',
            description:
                'Generate a comprehensive PDF report with selected data',
            icon: Icons.picture_as_pdf,
            color: Colors.red,
            onTap: () => _showExportOptionsDialog(ExportType.pdf),
          ),

          const SizedBox(height: 16),

          _buildExportCard(
            title: 'AI Analysis Export',
            description: 'Export saved AI analyses as JSON file',
            icon: Icons.psychology,
            color: Colors.purple,
            onTap: _exportAIAnalyses,
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
            'Google Drive Backup',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Backup your mood data as JSON files to Google Drive.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Google Drive Backup
          _buildCloudBackupCard(
            title: 'Google Drive',
            description: _googleDriveService.isSignedIn
                ? 'Signed in as ${_googleDriveService.userEmail}'
                : 'Sign in to backup JSON files to Google Drive',
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
              description: _googleDriveService.isSignedIn
                  ? 'Signed in as ${_googleDriveService.userEmail}'
                  : 'Sign in to backup JSON files to Google Drive',
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
            _buildBackupHistorySection('Google Drive', _driveBackups,
                _isDriveLoading, _loadGoogleDriveBackups),
          ],

          if (_isICloudAvailable && Platform.isIOS) ...[
            _buildBackupHistorySection(
                'iCloud', _iCloudBackups, _isICloudLoading, _loadICloudBackups),
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
            'Restore your mood data from previous backups or import custom data.',
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

          // Cloud Restore Section - NEW
          const Text(
            'Cloud Backups',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildCloudRestoreSection(),

          const SizedBox(height: 24),

          // File Import Section
          const Text(
            'Import from Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // JSON Backup Import
          _buildRestoreCard(
            title: 'Import Backup File',
            description: 'Import from a previously exported JSON backup file',
            icon: Icons.file_upload,
            color: Colors.purple,
            onTap: _importFromFile,
          ),

          // Keep your existing custom CSV import
          const SizedBox(height: 16),
          _buildRestoreCard(
            title: 'Import Your Custom CSV',
            description:
                'Import from your specific MoodLog CSV format (TEMPORARY)',
            icon: Icons.table_chart,
            color: Colors.orange,
            onTap: _importFromCustomCSV,
          ),
        ],
      ),
    );
  }

  Widget _buildCloudRestoreSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: RealCloudBackupService.getBackupStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data ?? {};
        final isAvailable = status['available'] ?? false;
        final isSignedIn = status['isSignedIn'] ?? false;

        if (!isAvailable) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Cloud backup not available on this device'),
            ),
          );
        }

        if (!isSignedIn) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Sign in to view cloud backups'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final success =
                          await RealCloudBackupService.signInToCloudService();
                      if (!mounted) return;

                      if (success) {
                        setState(() {});
                        _showSuccessMessage('Signed in successfully!');
                      } else {
                        _showErrorMessage('Sign in failed');
                      }
                    },
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<dynamic>>(
          future: RealCloudBackupService.listAvailableBackups(),
          builder: (context, backupSnapshot) {
            if (backupSnapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Loading cloud backups...'),
                    ],
                  ),
                ),
              );
            }

            final backups = backupSnapshot.data ?? [];

            if (backups.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No cloud backups found'),
                ),
              );
            }

            return Column(
              children: backups.map((backup) {
                return _buildCloudBackupRestoreCard(backup);
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildCloudBackupRestoreCard(dynamic backup) {
    // Handle both Google Drive and iCloud backup formats
    String title = 'Cloud Backup';
    String subtitle = 'Unknown date';
    String backupId = '';

    if (backup is DriveBackupFile) {
      title = backup.name;
      subtitle = backup.formattedDate;
      backupId = backup.id;
    } else if (backup is ICloudBackupFile) {
      title = backup.name;
      subtitle = backup.formattedDate;
      backupId = backup.relativePath;
    } else {
      // Fallback for other formats
      title = backup.toString();
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_download),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          onPressed: () => _restoreFromCloudBackup(backupId),
          child: const Text('Restore'),
        ),
      ),
    );
  }

  Future<void> _restoreFromCloudBackup(String backupId) async {
    final confirmed = await _showRestoreConfirmation();
    if (!confirmed) return;

    try {
      _showLoadingDialog('Restoring from cloud backup...');

      final result = await RealCloudBackupService.restoreFromBackup(backupId);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        _showSuccessMessage(
            result.message ?? 'Cloud restore completed successfully!');
      } else {
        _showErrorMessage(result.error ?? 'Cloud restore failed');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('Cloud restore failed: $e');
    }
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
                  color: color.withValues(alpha: 0.1),
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
                    color: color.withValues(alpha: 0.1),
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
                  color: color.withValues(alpha: 0.1),
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

  Widget _buildBackupHistorySection(
      String title, List items, bool isLoading, VoidCallback onLoad) {
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
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
              )),
      ],
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
                  const SnackBar(
                      content: Text('Date range selection coming soon')),
                );
              },
              child: const Text('Select Date Range'),
            ),
          ],
        ),
      ),
    );
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

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        _showSuccessMessage(result.message ?? 'Backup completed successfully!');
        _loadGoogleDriveBackups();
      } else {
        _showErrorMessage(result.error ?? 'Backup failed');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('Backup failed: $e');
    }
  }

  Future<void> _signOutGoogleDrive() async {
    await _googleDriveService.signOut();
    if (mounted) {
      setState(() {
        _driveBackups.clear();
      });
      _showSuccessMessage('Signed out of Google Drive');
    }
  }

  Future<void> _loadGoogleDriveBackups() async {
    if (mounted) {
      setState(() => _isDriveLoading = true);
    }

    try {
      final backups = await _googleDriveService.listBackups();
      if (mounted) {
        setState(() {
          _driveBackups = backups;
          _isDriveLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDriveLoading = false);
        _showErrorMessage('Failed to load Google Drive backups: $e');
      }
    }
  }

  // iCloud Methods (iOS only)
  Future<void> _backupToICloud() async {
    try {
      _showLoadingDialog('Backing up to iCloud...');

      final result = await _iCloudService.uploadBackup();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result.success) {
        _showSuccessMessage(result.message ?? 'iCloud backup completed!');
        _loadICloudBackups();
      } else {
        _showErrorMessage(result.error ?? 'iCloud backup failed');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorMessage('iCloud backup failed: $e');
    }
  }

  Future<void> _loadICloudBackups() async {
    if (mounted) {
      setState(() => _isICloudLoading = true);
    }

    try {
      final backups = await _iCloudService.listBackups();
      if (mounted) {
        setState(() {
          _iCloudBackups = backups;
          _isICloudLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isICloudLoading = false);
        _showErrorMessage('Failed to load iCloud backups: $e');
      }
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

          if (!mounted) return;
          Navigator.of(context).pop(); // Close loading dialog

          if (importResult.success) {
            _showSuccessMessage(
                'Import completed! Added ${importResult.importedMoods} moods and ${importResult.importedGoals} goals.');
          } else {
            _showErrorMessage(importResult.error ?? 'Import failed');
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
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
        ) ??
        false;
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // REMOVE FOR PRODUCTION (CUSTOM CSV IMPORT)
  Future<void> _importFromCustomCSV() async {
    try {
      final result = await showDialog<CustomImportResult>(
        context: context,
        builder: (context) => const CustomCSVImportDialog(),
      );

      if (result != null) {
        if (result.success) {
          _showSuccessMessage('Custom CSV import completed!\n'
              'Imported/Overwrote: ${result.imported} mood entries\n'
              'Note: This import overwrites any existing data for the same dates');

          // Show errors if any
          if (result.errors.isNotEmpty) {
            _showCustomImportErrors(result);
          }
        } else {
          _showErrorMessage(result.error ?? 'Custom CSV import failed');
        }
      }
    } catch (e) {
      _showErrorMessage('Custom CSV import failed: $e');
    }
  }

  // REMOVE FOR PRODUCTION (CUSTOM CSV IMPORT)
  void _showCustomImportErrors(CustomImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Results'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Imported: ${result.imported} entries'),
              Text('⏭️ Skipped: ${result.skipped} existing entries'),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Errors:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: result.errors
                          .map((error) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $error',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.red)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportOptionsDialog(ExportType type) async {
    bool includeMoods = true;
    bool includeCorrelations = true;
    bool includeWeather = true;
    bool includeSleep = true;
    bool includeActivity = true;
    DateTime? startDate;
    DateTime? endDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title:
              Text('${type == ExportType.csv ? 'CSV' : 'PDF'} Export Options'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Mood Logs'),
                  subtitle: const Text('Daily mood ratings and notes'),
                  value: includeMoods,
                  onChanged: (value) =>
                      setState(() => includeMoods = value ?? true),
                ),
                CheckboxListTile(
                  title: const Text('Weather Data'),
                  subtitle: const Text('Saved weather conditions'),
                  value: includeWeather,
                  onChanged: (value) =>
                      setState(() => includeWeather = value ?? true),
                ),
                CheckboxListTile(
                  title: const Text('Sleep Data'),
                  subtitle: const Text('Sleep quality and duration'),
                  value: includeSleep,
                  onChanged: (value) =>
                      setState(() => includeSleep = value ?? true),
                ),
                CheckboxListTile(
                  title: const Text('Activity & Social Data'),
                  subtitle: const Text('Exercise and social activities'),
                  value: includeActivity,
                  onChanged: (value) =>
                      setState(() => includeActivity = value ?? true),
                ),
                CheckboxListTile(
                  title: const Text('All Correlation Data'),
                  subtitle: const Text('Include all correlation factors'),
                  value: includeCorrelations,
                  onChanged: (value) =>
                      setState(() => includeCorrelations = value ?? true),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Date Range'),
                  subtitle: Text(
                    startDate != null && endDate != null
                        ? '${DateFormat('MMM d, yyyy').format(startDate!)} - ${DateFormat('MMM d, yyyy').format(endDate!)}'
                        : 'All available data',
                  ),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 3)),
                      lastDate: DateTime.now(),
                      initialDateRange: startDate != null && endDate != null
                          ? DateTimeRange(start: startDate!, end: endDate!)
                          : null,
                    );
                    if (picked != null) {
                      setState(() {
                        startDate = picked.start;
                        endDate = picked.end;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop({
                'includeMoods': includeMoods,
                'includeWeather': includeWeather,
                'includeSleep': includeSleep,
                'includeActivity': includeActivity,
                'includeCorrelations': includeCorrelations,
                'startDate': startDate,
                'endDate': endDate,
              }),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (type == ExportType.csv) {
        await _exportToCsvWithOptions(result);
      } else {
        await _exportToPdfWithOptions(result);
      }
    }
  }

  Widget _buildAdvancedExportCard({
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
                  color: color.withValues(alpha: 0.1),
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

  Future<void> _exportToCsvWithOptions(Map<String, dynamic> options) async {
    try {
      _showLoadingDialog('Exporting CSV with selected data...');

      final filePath = await ExportService.exportToCSVWithOptions(
        includeMoods: options['includeMoods'],
        includeWeather: options['includeWeather'],
        includeSleep: options['includeSleep'],
        includeActivity: options['includeActivity'],
        includeCorrelations: options['includeCorrelations'],
        startDate: options['startDate'],
        endDate: options['endDate'],
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await ExportService.shareFile(filePath,
          subject: 'MoodFlow Data Export (CSV)');
      _showSuccessMessage('CSV export completed successfully!');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showErrorMessage('Failed to export CSV: $e');
    }
  }

  Future<void> _exportToPdfWithOptions(Map<String, dynamic> options) async {
    try {
      _showLoadingDialog('Generating PDF with selected data...');

      final filePath = await ExportService.exportToPDFWithOptions(
        includeMoods: options['includeMoods'],
        includeWeather: options['includeWeather'],
        includeSleep: options['includeSleep'],
        includeActivity: options['includeActivity'],
        includeCorrelations: options['includeCorrelations'],
        startDate: options['startDate'],
        endDate: options['endDate'],
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await ExportService.shareFile(filePath, subject: 'MoodFlow Report (PDF)');
      _showSuccessMessage('PDF export completed successfully!');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showErrorMessage('Failed to export PDF: $e');
    }
  }

  Future<void> _exportAIAnalyses() async {
    try {
      _showLoadingDialog('Exporting AI analyses...');

      final filePath = await ExportService.exportAIAnalyses();

      if (!mounted) return;
      Navigator.of(context).pop();

      await ExportService.shareFile(filePath,
          subject: 'MoodFlow AI Analyses Export');
      _showSuccessMessage('AI analyses exported successfully!');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showErrorMessage('Failed to export AI analyses: $e');
    }
  }
}
