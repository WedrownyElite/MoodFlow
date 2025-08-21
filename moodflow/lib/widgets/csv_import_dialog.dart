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
  String? _selectedFileName;
  List<List<String>> _csvPreview = [];
  bool _isLoadingPreview = false;
  String? _errorMessage;

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
      setState(() {
        _errorMessage = null;
      });

      // Try different approaches to file selection
      FilePickerResult? result;

      try {
        // First attempt: Standard CSV file picker
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
          allowMultiple: false,
          withData: false, // Don't load data immediately
          withReadStream: false,
        );
      } catch (e) {
        print('Standard picker failed, trying alternative: $e');

        // Second attempt: Try any file type and validate extension manually
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
          withData: false,
          withReadStream: false,
        );

        // Validate that it's a CSV file
        if (result != null && result.files.isNotEmpty) {
          final fileName = result.files.first.name.toLowerCase();
          if (!fileName.endsWith('.csv') && !fileName.endsWith('.txt')) {
            _showError('Please select a CSV file (.csv or .txt)');
            return;
          }
        }
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        print('Selected file: ${file.name}');
        print('File path: ${file.path}');
        print('File size: ${file.size}');

        if (file.path != null) {
          setState(() {
            _selectedFilePath = file.path!;
            _selectedFileName = file.name;
            _isLoadingPreview = true;
            _errorMessage = null;
          });

          await _loadPreview();
        } else {
          _showError('Could not access the selected file. Please try a different file.');
        }
      } else {
        print('No file selected or file picker cancelled');
      }
    } catch (e) {
      print('File selection error: $e');
      _showError('Failed to select file: $e');
    }
  }

  Future<void> _loadPreview() async {
    if (_selectedFilePath == null) return;

    try {
      print('Loading preview for: $_selectedFilePath');

      // Add more detailed error handling for CSV parsing
      final preview = await CSVImportService.getCSVPreview(
        _selectedFilePath!,
        maxRows: 15, // Show more rows for better preview
        maxCols: 15,  // Show more columns
      );

      print('Preview loaded successfully. Rows: ${preview.length}');

      if (preview.isEmpty) {
        throw Exception('The CSV file appears to be empty or could not be parsed');
      }

      setState(() {
        _csvPreview = preview;
        _isLoadingPreview = false;
        _errorMessage = null;
      });

      // Auto-suggest some common configurations
      _suggestCommonMappings();

    } catch (e) {
      print('Preview loading error: $e');
      setState(() {
        _isLoadingPreview = false;
        _errorMessage = 'Failed to load CSV preview: $e';
      });
      _showError('Failed to load CSV preview: $e');
    }
  }

  void _suggestCommonMappings() {
    if (_csvPreview.isEmpty) return;

    print('CSV Preview has ${_csvPreview.length} rows');
    for (int i = 0; i < _csvPreview.length && i < 3; i++) {
      print('Row ${i + 1}: ${_csvPreview[i]}');
    }

    // Look for common column headers in the first few rows
    for (int row = 0; row < _csvPreview.length && row < 3; row++) {
      final headers = _csvPreview[row];

      for (int col = 0; col < headers.length; col++) {
        final header = headers[col].toLowerCase().trim();
        print('Checking header at Row ${row + 1}, Col ${_getColumnLetter(col)}: "$header"');

        // Suggest date column
        if ((header.contains('date') || header.contains('day')) && _dateRangeController.text.isEmpty) {
          final colLetter = _getColumnLetter(col);
          final startRow = row + 2; // Skip header row
          final endRow = _csvPreview.length;
          _dateRangeController.text = '$colLetter$startRow:$colLetter$endRow';
          print('Suggested date range: ${_dateRangeController.text}');
        }

        // Suggest morning mood - look for variations
        if (_morningRangeController.text.isEmpty) {
          if (header.contains('morning') ||
              (header.contains('day') && header.contains('mood')) ||
              header == 'morning mood' ||
              header == 'am mood') {
            final colLetter = _getColumnLetter(col);
            final startRow = row + 2;
            final endRow = _csvPreview.length;
            _morningRangeController.text = '$colLetter$startRow:$colLetter$endRow';
            print('Suggested morning mood range: ${_morningRangeController.text}');
          }
        }

        // Suggest midday mood
        if (_middayRangeController.text.isEmpty) {
          if (header.contains('midday') || header.contains('mid-day') ||
              header.contains('afternoon') || header.contains('pm') ||
              header.contains('noon')) {
            final colLetter = _getColumnLetter(col);
            final startRow = row + 2;
            final endRow = _csvPreview.length;
            _middayRangeController.text = '$colLetter$startRow:$colLetter$endRow';
            print('Suggested midday mood range: ${_middayRangeController.text}');
          }
        }

        // Suggest evening mood - look for night/evening variations
        if (_eveningRangeController.text.isEmpty) {
          if (header.contains('evening') || header.contains('night') ||
              header.contains('eve') || header.contains('pm mood') ||
              (header.contains('night') && header.contains('mood'))) {
            final colLetter = _getColumnLetter(col);
            final startRow = row + 2;
            final endRow = _csvPreview.length;
            _eveningRangeController.text = '$colLetter$startRow:$colLetter$endRow';
            print('Suggested evening mood range: ${_eveningRangeController.text}');
          }
        }

        // Suggest notes ranges
        if (header.contains('note')) {
          final colLetter = _getColumnLetter(col);
          final startRow = row + 2;
          final endRow = _csvPreview.length;

          if ((header.contains('morning') || header.contains('am')) && _morningNotesController.text.isEmpty) {
            _morningNotesController.text = '$colLetter$startRow:$colLetter$endRow';
            print('Suggested morning notes range: ${_morningNotesController.text}');
          } else if ((header.contains('midday') || header.contains('mid-day') || header.contains('afternoon')) && _middayNotesController.text.isEmpty) {
            _middayNotesController.text = '$colLetter$startRow:$colLetter$endRow';
            print('Suggested midday notes range: ${_middayNotesController.text}');
          } else if ((header.contains('evening') || header.contains('night')) && _eveningNotesController.text.isEmpty) {
            _eveningNotesController.text = '$colLetter$startRow:$colLetter$endRow';
            print('Suggested evening notes range: ${_eveningNotesController.text}');
          }
        }
      }
    }

    // Show user what we detected
    setState(() {});
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  bool _validateRanges() {
    if (_dateRangeController.text.trim().isEmpty) {
      _showError('Date range is required');
      return false;
    }

    // At least one mood range should be specified
    if (_morningRangeController.text.trim().isEmpty &&
        _middayRangeController.text.trim().isEmpty &&
        _eveningRangeController.text.trim().isEmpty) {
      _showError('At least one mood range (Morning, Midday, or Evening) must be specified');
      return false;
    }

    // Validate range format
    try {
      _parseRange(_dateRangeController.text.trim());

      if (_morningRangeController.text.trim().isNotEmpty) {
        _parseRange(_morningRangeController.text.trim());
      }
      if (_middayRangeController.text.trim().isNotEmpty) {
        _parseRange(_middayRangeController.text.trim());
      }
      if (_eveningRangeController.text.trim().isNotEmpty) {
        _parseRange(_eveningRangeController.text.trim());
      }
    } catch (e) {
      _showError('Invalid range format: $e');
      return false;
    }

    return true;
  }

  // Simplified range parsing for validation
  void _parseRange(String range) {
    range = range.trim().toUpperCase();
    if (range.isEmpty) throw Exception('Empty range');

    if (range.contains(':')) {
      final parts = range.split(':');
      if (parts.length != 2) throw Exception('Invalid range format: $range');

      _parseCellReference(parts[0]);
      _parseCellReference(parts[1]);
    } else {
      _parseCellReference(range);
    }
  }

  void _parseCellReference(String cellRef) {
    cellRef = cellRef.trim().toUpperCase();
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cellRef);
    if (match == null) throw Exception('Invalid cell reference: $cellRef');

    final colStr = match.group(1)!;
    final rowStr = match.group(2)!;

    // Validate column (A-ZZ should be enough)
    if (colStr.length > 2) throw Exception('Column too large: $colStr');

    // Validate row (1-10000 should be enough)
    final row = int.parse(rowStr);
    if (row < 1 || row > 10000) throw Exception('Row out of range: $row');
  }

  Future<void> _performImport() async {
    if (!_validateRanges() || _selectedFilePath == null) return;

    final config = CSVMappingConfig(
      dateRange: _dateRangeController.text.trim(),
      dateFormat: _dateFormatController.text.trim(),
      morningRange: _morningRangeController.text.trim().isNotEmpty
          ? _morningRangeController.text.trim() : null,
      middayRange: _middayRangeController.text.trim().isNotEmpty
          ? _middayRangeController.text.trim() : null,
      eveningRange: _eveningRangeController.text.trim().isNotEmpty
          ? _eveningRangeController.text.trim() : null,
      morningNotesRange: _morningNotesController.text.trim().isNotEmpty
          ? _morningNotesController.text.trim() : null,
      middayNotesRange: _middayNotesController.text.trim().isNotEmpty
          ? _middayNotesController.text.trim() : null,
      eveningNotesRange: _eveningNotesController.text.trim().isNotEmpty
          ? _eveningNotesController.text.trim() : null,
    );

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
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
      print('Starting CSV import with config: ${config.dateRange}');

      final result = await CSVImportService.importMoodData(
        filePath: _selectedFilePath!,
        config: config,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (result.success) {
        print('Import successful: ${result.importedEntries} imported, ${result.skippedEntries} skipped');
        // Close import dialog and return result
        if (mounted) Navigator.of(context).pop(result);
      } else {
        print('Import failed: ${result.error}');
        _showError(result.error ?? 'Import failed');
      }
    } catch (e) {
      print('Import exception: $e');
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      _showError('Import failed: $e');
    }
  }

  Widget _buildFlexibleDataPreview() {
    if (_csvPreview.isEmpty) return const Text('No data to preview');

    // Find the maximum number of columns across all rows
    int maxColumns = 0;
    for (final row in _csvPreview) {
      if (row.length > maxColumns) {
        maxColumns = row.length;
      }
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
      columnWidths: {
        0: const FixedColumnWidth(50), // Row number column
        // All other columns get equal width
        for (int i = 1; i <= maxColumns; i++)
          i: const FlexColumnWidth(1),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableCell('Row', isHeader: true),
            for (int i = 0; i < maxColumns; i++)
              _buildTableCell(_getColumnLetter(i), isHeader: true),
          ],
        ),
        // Data rows
        ..._csvPreview.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;

          return TableRow(
            children: [
              _buildTableCell('${rowIndex + 1}', isRowNumber: true),
              for (int i = 0; i < maxColumns; i++)
                _buildTableCell(
                  i < row.length ? (row[i].isEmpty ? '(empty)' : row[i]) : '',
                  isEmpty: i >= row.length || (i < row.length && row[i].isEmpty),
                ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTableCell(String content, {bool isHeader = false, bool isRowNumber = false, bool isEmpty = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 35),
      decoration: BoxDecoration(
        color: isHeader
            ? Colors.grey.shade200
            : (isRowNumber ? Colors.grey.shade50 : null),
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader || isRowNumber ? FontWeight.bold : FontWeight.normal,
          color: isEmpty ? Colors.grey.shade500 : null,
          fontStyle: isEmpty ? FontStyle.italic : null,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
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
      insetPadding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = MediaQuery.of(context).size.height * 0.85;

          return Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              minHeight: 400,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Import CSV Data',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Flexible scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Error message display
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // File selection
                        _buildFileSelectionSection(),

                        if (_selectedFilePath != null) ...[
                          const SizedBox(height: 20),

                          // CSV Preview
                          if (_isLoadingPreview)
                            const Center(child: CircularProgressIndicator())
                          else if (_csvPreview.isNotEmpty) ...[
                            _buildPreviewSection(),
                            const SizedBox(height: 20),
                            _buildRangeMappingSection(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // Fixed bottom buttons
                if (_selectedFilePath != null && _csvPreview.isNotEmpty && !_isLoadingPreview) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: _buildActionButtons(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1: Select CSV File',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: Text(_selectedFileName != null
                  ? 'Selected: $_selectedFileName'
                  : 'Choose CSV File'),
              onPressed: _selectFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedFileName != null
                    ? Colors.green.shade100
                    : null,
                foregroundColor: _selectedFileName != null
                    ? Colors.green.shade800
                    : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_selectedFileName != null) ...[
            const SizedBox(height: 8),
            Text(
              'File: $_selectedFileName',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Preview Your Data',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // CSV Info summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your CSV has ${_csvPreview.length} rows and ${_csvPreview.isNotEmpty ? _csvPreview.first.length : 0} columns. '
                      'Data rows: ${_csvPreview.length - 1} (excluding header)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: _buildFlexibleDataPreview(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeMappingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Define Data Ranges',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Use Excel-style ranges (e.g., A1:A10)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),

        // Date range (required) - Single row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _dateRangeController,
                decoration: const InputDecoration(
                  labelText: 'Date Range *',
                  hintText: 'A1:A10',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _dateFormatController,
                decoration: const InputDecoration(
                  labelText: 'Format',
                  hintText: 'yyyy-MM-dd',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Mood ranges - More compact
        const Text(
          'Mood Ratings (1-10):',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        // All three mood fields in two rows for better space usage
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _morningRangeController,
                    decoration: const InputDecoration(
                      labelText: 'Morning',
                      hintText: 'B1:B10',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _middayRangeController,
                    decoration: const InputDecoration(
                      labelText: 'Midday',
                      hintText: 'C1:C10',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _eveningRangeController,
                    decoration: const InputDecoration(
                      labelText: 'Evening',
                      hintText: 'D1:D10',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()), // Half empty space
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Notes section - More compact, always expanded but smaller
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _morningNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Morning Notes',
                            hintText: 'E1:E10',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextFormField(
                          controller: _middayNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Midday Notes',
                            hintText: 'F1:F10',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _eveningNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Evening Notes',
                            hintText: 'G1:G10',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Compact help text
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Examples: A1:A10 (column A, rows 1-10) • A1:J1 (row 1, columns A-J) • C5 (single cell)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
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
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Import Data'),
          ),
        ),
      ],
    );
  }
}