import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import/custom_csv_importer.dart';

class CustomCSVImportDialog extends StatefulWidget {
  const CustomCSVImportDialog({super.key});

  @override
  State<CustomCSVImportDialog> createState() => _CustomCSVImportDialogState();
}

class _CustomCSVImportDialogState extends State<CustomCSVImportDialog> {
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.upload_file, size: 28, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Import Your MoodLog CSV',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Custom importer for your specific CSV format:',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.orange.shade800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Column A: Dates (6/15/2025 format)\n'
                        '• Column B: Morning Notes\n'
                        '• Column C: Day Mood (0-10 ratings)\n'
                        '• Column D: Mid-Day Notes\n'
                        '• Column E: Night Mood (0-10 ratings)\n'
                        '• Column F: Night Notes',
                    style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // File selection
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
                color: _selectedFileName != null ? Colors.green.shade50 : Colors.grey.shade50,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isImporting ? null : _selectFile,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedFileName != null ? Icons.check_circle : Icons.cloud_upload,
                        size: 40,
                        color: _selectedFileName != null ? Colors.green : Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFileName != null
                            ? 'Selected: $_selectedFileName'
                            : 'Click to select your CSV file',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedFileName != null ? Colors.green.shade800 : Colors.grey.shade700,
                          fontWeight: _selectedFileName != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedFileName == null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Supports .csv files',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedFilePath != null && !_isImporting ? _performImport : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isImporting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Import Data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedFilePath = file.path!;
            _selectedFileName = file.name;
          });
        }
      }
    } catch (e) {
      _showError('Failed to select file: $e');
    }
  }

  Future<void> _performImport() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final result = await CustomCSVImporter.importYourCSV(_selectedFilePath!);

      setState(() {
        _isImporting = false;
      });

      if (result.success) {
        // Close dialog and return result
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      } else {
        _showError(result.error ?? 'Import failed');
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      _showError('Import failed: $e');
    }
  }

  void _showError(String message) {
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
}