import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import/csv_import_service.dart';

class CSVImportDialog extends StatefulWidget {
  const CSVImportDialog({super.key});

  @override
  State<CSVImportDialog> createState() => _CSVImportDialogState();
}

class _CSVImportDialogState extends State<CSVImportDialog> {
  String? _selectedFilePath;
  List<List<String>> _csvPreview = [];
  bool _isLoadingPreview = false;

  // Range controllers
  final _dateRangeController = TextEditingController();
  final _dateFormatController = TextEditingController(text: 'yyyy-MM-dd');
  final _morningRangeController = TextEditingController();
  final _middayRangeController = TextEditingController();
  final _eveningRangeController = TextEditingController();
  final _morningNotesController = TextEditingController();
  final _middayNotesController = TextEditingController();
  final _eveningNotesController = TextEditingController();

  @override
  void dispose() {
    _dateRangeController.dispose();
    _dateFormatController.dispose();
    _morningRangeController.dispose();
    _middayRangeController.dispose();
    _eveningRangeController.dispose();
    _morningNotesController.dispose();
    _middayNotesController.dispose();
    _eveningNotesController.dispose();
    super.dispose();
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
            _isLoadingPreview = true;
          });

          await _loadPreview();
        }
      }
    } catch (e) {
      _showError('Failed to select file: $e');
    }
  }

  Future<void> _loadPreview() async {
    if (_selectedFilePath == null) return;

    try {
      final preview = await CSVImportService.getCSVPreview(_selectedFilePath!);
      setState(() {
        _csvPreview = preview;
        _isLoadingPreview = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPreview = false;
      });
      _showError('Failed to load CSV preview: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _validateRanges() {
    if (_dateRangeController.text
        .trim()
        .isEmpty) {
      _showError('Date range is required');
      return false;
    }

    // At least one mood range should be specified
    if (_morningRangeController.text
        .trim()
        .isEmpty &&
        _middayRangeController.text
            .trim()
            .isEmpty &&
        _eveningRangeController.text
            .trim()
            .isEmpty) {
      _showError(
          'At least one mood range (Morning, Midday, or Evening) must be specified');
      return false;
    }

    return true;
  }

  Future<void> _performImport() async {
    if (!_validateRanges() || _selectedFilePath == null) return;

    final config = CSVMappingConfig(
      dateRange: _dateRangeController.text.trim(),
      dateFormat: _dateFormatController.text.trim(),
      morningRange: _morningRangeController.text
          .trim()
          .isNotEmpty
          ? _morningRangeController.text.trim() : null,
      middayRange: _middayRangeController.text
          .trim()
          .isNotEmpty
          ? _middayRangeController.text.trim() : null,
      eveningRange: _eveningRangeController.text
          .trim()
          .isNotEmpty
          ? _eveningRangeController.text.trim() : null,
      morningNotesRange: _morningNotesController.text
          .trim()
          .isNotEmpty
          ? _morningNotesController.text.trim() : null,
      middayNotesRange: _middayNotesController.text
          .trim()
          .isNotEmpty
          ? _middayNotesController.text.trim() : null,
      eveningNotesRange: _eveningNotesController.text
          .trim()
          .isNotEmpty
          ? _eveningNotesController.text.trim() : null,
    );

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
      const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Importing CSV data...')),
          ],
        ),
      ),
    );

    try {
      final result = await CSVImportService.importMoodData(
        filePath: _selectedFilePath!,
        config: config,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (result.success) {
        // Close import dialog and return result
        if (mounted) Navigator.of(context).pop(result);
      } else {
        _showError(result.error ?? 'Import failed');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      _showError('Import failed: $e');
    }
  }

  String _getColumnLetter(int index) {
    String result = '';
    index++; // Convert to 1-based

    while (index > 0) {
      index--;
      result = String.fromCharCode('A'.codeUnitAt(0) + (index % 26)) + result;
      index ~/= 26;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: MediaQuery
            .of(context)
            .size
            .height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Import CSV Data',
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

            // File selection
            ElevatedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: Text(_selectedFilePath != null
                  ? 'File Selected: ${_selectedFilePath!.split('/').last}'
                  : 'Select CSV File'),
              onPressed: _selectFile,
            ),

            if (_selectedFilePath != null) ...[
              const SizedBox(height: 16),

              // CSV Preview
              if (_isLoadingPreview)
                const Center(child: CircularProgressIndicator())
              else
                if (_csvPreview.isNotEmpty) ...[
                  const Text(
                    'CSV Preview:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: List.generate(
                              _csvPreview.first.length,
                                  (index) =>
                                  DataColumn(
                                    label: Text(
                                      _getColumnLetter(index),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                            ),
                            rows: _csvPreview
                                .asMap()
                                .entries
                                .map((entry) {
                              final rowIndex = entry.key;
                              final row = entry.value;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${rowIndex + 1}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  ...row.map((cell) =>
                                      DataCell(
                                        Container(
                                          constraints: const BoxConstraints(
                                              maxWidth: 100),
                                          child: Text(
                                            cell.isEmpty ? '(empty)' : cell,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: cell.isEmpty
                                                  ? Colors.grey
                                                  : null,
                                              fontStyle: cell.isEmpty
                                                  ? FontStyle.italic
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      )).toList(),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Range mapping form
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Define Data Ranges:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'Use Excel-style ranges (e.g., A1:A10 for column A rows 1-10, or B5:E5 for row 5 columns B-E)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Date range (required)
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _dateRangeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Date Range *',
                                    hintText: 'e.g., A1:A10',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _dateFormatController,
                                  decoration: const InputDecoration(
                                    labelText: 'Date Format',
                                    hintText: 'yyyy-MM-dd',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Mood ranges
                          const Text(
                            'Mood Ratings (1-10):',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _morningRangeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Morning Mood',
                                    hintText: 'e.g., B1:B10',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _middayRangeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Midday Mood',
                                    hintText: 'e.g., C1:C10',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _eveningRangeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Evening Mood',
                                    hintText: 'e.g., D1:D10',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Notes ranges (optional)
                          const Text(
                            'Notes (Optional):',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _morningNotesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Morning Notes',
                                    hintText: 'e.g., E1:E10',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _middayNotesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Midday Notes',
                                    hintText: 'e.g., F1:F10',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _eveningNotesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Evening Notes',
                                    hintText: 'e.g., G1:G10',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Help text
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Range Examples:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Row-based: A1:A10 (dates in column A, rows 1-10)\n'
                                      '• Column-based: A1:J1 (dates in row 1, columns A-J)\n'
                                      '• Single cell: C5 (just cell C5)\n'
                                      '• Date formats: yyyy-MM-dd, MM/dd/yyyy, dd/MM/yyyy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _performImport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme
                                .of(context)
                                .primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Import Data'),
                        ),
                      ),
                    ],
                  ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}