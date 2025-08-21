import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../data/mood_data_service.dart';
import '../data/backup_models.dart';
import '../backup/backup_service.dart';

class CSVImportService {
  /// Parse a CSV file and return the raw data with better error handling
  static Future<List<List<String>>> parseCSVFile(String filePath) async {
    try {
      final file = File(filePath);

      // Check if file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();

      if (content.trim().isEmpty) {
        throw Exception('File is empty');
      }

      print('=== CSV PARSING DEBUG ===');
      print('File content length: ${content.length} characters');
      print('First 500 characters:');
      print(content.substring(0, math.min(500, content.length)));
      print('=========================');

      // Count actual lines in the file for comparison
      final lines = content.split('\n');
      print('Raw file has ${lines.length} lines');

      // Try different CSV parsing configurations with more robust settings
      List<List<dynamic>> csvData;

      try {
        // First attempt: More robust comma-separated parsing
        csvData = const CsvToListConverter(
          fieldDelimiter: ',',
          textDelimiter: '"',
          textEndDelimiter: '"',
          eol: '\n',
          allowInvalid: false, // Be stricter to catch malformed data
          convertEmptyTo: '',
          shouldParseNumbers: false, // Keep everything as strings initially
        ).convert(content);
        print('✅ Parsed with strict comma delimiter');
      } catch (e) {
        print('❌ Strict CSV parsing failed: $e');

        try {
          // Second attempt: More lenient parsing
          csvData = const CsvToListConverter(
            fieldDelimiter: ',',
            textDelimiter: '"',
            textEndDelimiter: '"',
            eol: '\n',
            allowInvalid: true, // Allow malformed CSV
            convertEmptyTo: '',
            shouldParseNumbers: false,
          ).convert(content);
          print('✅ Parsed with lenient comma delimiter');
        } catch (e2) {
          print('❌ Lenient CSV parsing failed: $e2');

          // Third attempt: Manual line-by-line parsing for problematic CSVs
          print('🔧 Attempting manual parsing...');
          csvData = _manualCSVParse(content);
          print('✅ Manual parsing completed');
        }
      }

      if (csvData.isEmpty) {
        throw Exception('No data found in CSV file');
      }

      print('=== RAW CSV DATA ===');
      print('Parsed ${csvData.length} raw rows (expected ~${lines.length})');

      // Show first few rows with better formatting
      for (int i = 0; i < csvData.length && i < 5; i++) {
        print('Raw Row $i (${csvData[i].length} cols): ');
        for (int j = 0; j < csvData[i].length && j < 6; j++) {
          final cell = csvData[i][j]?.toString() ?? '';
          final preview = cell.length > 50 ? '${cell.substring(0, 50)}...' : cell;
          print('  Col $j: "$preview"');
        }
      }
      print('=====================');

      // Convert all cells to strings and handle irregular row lengths
      final result = <List<String>>[];
      int maxColumns = 0;

      // First pass: find maximum column count
      for (final row in csvData) {
        if (row.length > maxColumns) {
          maxColumns = row.length;
        }
      }

      print('Maximum columns found: $maxColumns');

      // Second pass: normalize all rows to have the same length
      for (int i = 0; i < csvData.length; i++) {
        final row = csvData[i];
        final normalizedRow = <String>[];
        for (int j = 0; j < maxColumns; j++) {
          if (j < row.length) {
            final cellValue = row[j]?.toString()?.trim() ?? '';
            normalizedRow.add(cellValue);
          } else {
            normalizedRow.add(''); // Fill missing cells with empty strings
          }
        }
        result.add(normalizedRow);
      }

      print('=== FINAL RESULT ===');
      print('Final result: ${result.length} rows with $maxColumns columns each');

      // Check if we have the expected number of rows
      if (result.length < lines.length * 0.8) {
        print('⚠️ WARNING: Parsed ${result.length} rows but file has ${lines.length} lines. Some rows may have been merged due to multiline text.');
      }

      print('First 3 rows:');
      for (int i = 0; i < result.length && i < 3; i++) {
        print('Row ${i + 1}: [${result[i].map((cell) => '"${cell.length > 30 ? cell.substring(0, 30) + "..." : cell}"').join(', ')}]');
      }
      print('===================');

      return result;

    } catch (e) {
      print('CSV parsing error: $e');
      throw Exception('Failed to parse CSV file: $e');
    }
  }

  /// Manual CSV parser for problematic files with multiline text
  static List<List<dynamic>> _manualCSVParse(String content) {
    final result = <List<dynamic>>[];
    final lines = content.split('\n');

    List<String> currentRow = [];
    bool insideQuotes = false;
    String currentCell = '';

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];

      for (int charIndex = 0; charIndex < line.length; charIndex++) {
        final char = line[charIndex];

        if (char == '"') {
          // Handle quotes - toggle quote state
          insideQuotes = !insideQuotes;
          currentCell += char;
        } else if (char == ',' && !insideQuotes) {
          // End of cell
          currentRow.add(currentCell.trim());
          currentCell = '';
        } else {
          currentCell += char;
        }
      }

      // End of line
      if (!insideQuotes) {
        // Complete row
        currentRow.add(currentCell.trim());
        if (currentRow.any((cell) => cell.isNotEmpty)) {
          result.add(List<String>.from(currentRow));
        }
        currentRow = [];
        currentCell = '';
      } else {
        // Continue to next line (multiline cell)
        currentCell += '\n';
      }
    }

    // Handle last row if any
    if (currentRow.isNotEmpty || currentCell.isNotEmpty) {
      currentRow.add(currentCell.trim());
      if (currentRow.any((cell) => cell.isNotEmpty)) {
        result.add(List<String>.from(currentRow));
      }
    }

    print('Manual parser created ${result.length} rows');
    return result;
  }

  /// Get preview of CSV data with better handling of irregular files
  static Future<List<List<String>>> getCSVPreview(String filePath, {int maxRows = 15, int maxCols = 15}) async {
    try {
      final csvData = await parseCSVFile(filePath);

      print('=== GENERATING PREVIEW ===');
      print('Full CSV has ${csvData.length} rows');
      print('Requesting preview of max $maxRows rows, $maxCols cols');

      final preview = <List<String>>[];
      for (int i = 0; i < csvData.length && i < maxRows; i++) {
        final row = <String>[];
        final originalRow = csvData[i];

        // Take up to maxCols columns, but don't enforce exact length
        for (int j = 0; j < originalRow.length && j < maxCols; j++) {
          row.add(originalRow[j]);
        }

        // Add all rows, even if they seem "empty" (user might have data we don't see)
        preview.add(row);
        print('Preview Row ${i + 1}: $row');
      }

      print('Generated preview with ${preview.length} rows');
      print('==========================');
      return preview;
    } catch (e) {
      print('Preview generation error: $e');
      rethrow;
    }
  }

  /// Import mood data from CSV using user-defined ranges with better error handling
  static Future<CSVImportResult> importMoodData({
    required String filePath,
    required CSVMappingConfig config,
  }) async {
    try {
      print('Starting CSV import from: $filePath');
      print('Config: ${config.dateRange}, ${config.dateFormat}');

      final csvData = await parseCSVFile(filePath);

      if (csvData.isEmpty) {
        return CSVImportResult(
          success: false,
          error: 'CSV file is empty or could not be parsed',
        );
      }

      print('CSV loaded successfully: ${csvData.length} rows');

      final results = <CSVMoodEntry>[];
      final errors = <String>[];

      // Extract data from specified ranges with better error handling
      CellRange? dateRange;
      CellRange? morningRange;
      CellRange? middayRange;
      CellRange? eveningRange;
      CellRange? morningNotesRange;
      CellRange? middayNotesRange;
      CellRange? eveningNotesRange;

      try {
        dateRange = _parseRange(config.dateRange);
        morningRange = config.morningRange != null ? _parseRange(config.morningRange!) : null;
        middayRange = config.middayRange != null ? _parseRange(config.middayRange!) : null;
        eveningRange = config.eveningRange != null ? _parseRange(config.eveningRange!) : null;
        morningNotesRange = config.morningNotesRange != null ? _parseRange(config.morningNotesRange!) : null;
        middayNotesRange = config.middayNotesRange != null ? _parseRange(config.middayNotesRange!) : null;
        eveningNotesRange = config.eveningNotesRange != null ? _parseRange(config.eveningNotesRange!) : null;
      } catch (e) {
        return CSVImportResult(
          success: false,
          error: 'Invalid range format: $e',
        );
      }

      // Determine if we're using row-based or column-based layout
      final isRowBased = _isRowBasedLayout(dateRange, morningRange, middayRange, eveningRange);
      print('Detected layout: ${isRowBased ? "row-based" : "column-based"}');

      if (isRowBased) {
        await _processRowBasedData(
          csvData, config, dateRange, morningRange, middayRange, eveningRange,
          morningNotesRange, middayNotesRange, eveningNotesRange,
          results, errors,
        );
      } else {
        await _processColumnBasedData(
          csvData, config, dateRange, morningRange, middayRange, eveningRange,
          morningNotesRange, middayNotesRange, eveningNotesRange,
          results, errors,
        );
      }

      print('Processed ${results.length} entries with ${errors.length} errors');

      // Convert to mood entries and save
      int importedCount = 0;
      int skippedCount = 0;

      for (final entry in results) {
        try {
          // Check if entry already exists
          final existingMorning = entry.morningMood != null
              ? await MoodDataService.loadMood(entry.date, 0)
              : null;
          final existingMidday = entry.middayMood != null
              ? await MoodDataService.loadMood(entry.date, 1)
              : null;
          final existingEvening = entry.eveningMood != null
              ? await MoodDataService.loadMood(entry.date, 2)
              : null;

          // Save morning mood if provided and doesn't exist
          if (entry.morningMood != null && (existingMorning == null || existingMorning['rating'] == null)) {
            await MoodDataService.saveMood(
                entry.date, 0, entry.morningMood!, entry.morningNotes ?? ''
            );
            importedCount++;
          } else if (entry.morningMood != null) {
            skippedCount++;
          }

          // Save midday mood if provided and doesn't exist
          if (entry.middayMood != null && (existingMidday == null || existingMidday['rating'] == null)) {
            await MoodDataService.saveMood(
                entry.date, 1, entry.middayMood!, entry.middayNotes ?? ''
            );
            importedCount++;
          } else if (entry.middayMood != null) {
            skippedCount++;
          }

          // Save evening mood if provided and doesn't exist
          if (entry.eveningMood != null && (existingEvening == null || existingEvening['rating'] == null)) {
            await MoodDataService.saveMood(
                entry.date, 2, entry.eveningMood!, entry.eveningNotes ?? ''
            );
            importedCount++;
          } else if (entry.eveningMood != null) {
            skippedCount++;
          }

        } catch (e) {
          errors.add('Failed to save data for ${DateFormat('yyyy-MM-dd').format(entry.date)}: $e');
        }
      }

      print('Import completed: $importedCount imported, $skippedCount skipped');

      return CSVImportResult(
        success: true,
        importedEntries: importedCount,
        skippedEntries: skippedCount,
        totalEntries: results.length,
        errors: errors,
      );

    } catch (e) {
      print('Import failed with exception: $e');
      return CSVImportResult(
        success: false,
        error: 'Import failed: $e',
      );
    }
  }

  static bool _isRowBasedLayout(CellRange dateRange, CellRange? morningRange, CellRange? middayRange, CellRange? eveningRange) {
    // If date range spans multiple rows, it's likely row-based
    if (dateRange.endRow != dateRange.startRow) return true;

    // If any mood range spans multiple rows, it's likely row-based
    if (morningRange != null && morningRange.endRow != morningRange.startRow) return true;
    if (middayRange != null && middayRange.endRow != middayRange.startRow) return true;
    if (eveningRange != null && eveningRange.endRow != eveningRange.startRow) return true;

    // If date range spans multiple columns but mood ranges are in same row, it's column-based
    return false;
  }

  static Future<void> _processRowBasedData(
      List<List<String>> csvData,
      CSVMappingConfig config,
      CellRange dateRange,
      CellRange? morningRange,
      CellRange? middayRange,
      CellRange? eveningRange,
      CellRange? morningNotesRange,
      CellRange? middayNotesRange,
      CellRange? eveningNotesRange,
      List<CSVMoodEntry> results,
      List<String> errors,
      ) async {
    print('Processing row-based data:');
    print('CSV has ${csvData.length} rows');
    print('Date range: Row ${dateRange.startRow + 1} to ${dateRange.endRow + 1}');
    print('Morning range: ${morningRange != null ? "Row ${morningRange.startRow + 1} to ${morningRange.endRow + 1}, Col ${morningRange.startCol + 1}" : "None"}');
    print('Midday range: ${middayRange != null ? "Row ${middayRange.startRow + 1} to ${middayRange.endRow + 1}, Col ${middayRange.startCol + 1}" : "None"}');
    print('Evening range: ${eveningRange != null ? "Row ${eveningRange.startRow + 1} to ${eveningRange.endRow + 1}, Col ${eveningRange.startCol + 1}" : "None"}');

    // In row-based layout, iterate through rows
    for (int row = dateRange.startRow; row <= dateRange.endRow; row++) {
      if (row >= csvData.length) {
        errors.add('Row ${row + 1} is beyond the end of the CSV file (file has ${csvData.length} rows)');
        print('ERROR: Row ${row + 1} beyond CSV length ${csvData.length}');
        continue;
      }

      try {
        // Extract date
        final dateCell = _getCellValue(csvData, row, dateRange.startCol);
        if (dateCell.isEmpty) {
          print('Skipping row ${row + 1}: empty date cell');
          continue; // Skip empty date cells
        }

        final date = _parseDate(dateCell, config.dateFormat);
        if (date == null) {
          errors.add('Row ${row + 1}: Could not parse date "$dateCell"');
          print('ERROR: Could not parse date "$dateCell" in row ${row + 1}');
          continue;
        }

        print('Processing row ${row + 1}, date: $date');

        // Extract mood values with detailed logging
        double? morningMood;
        if (morningRange != null) {
          final morningCell = _getCellValue(csvData, row, morningRange.startCol);
          morningMood = _parseMoodValue(morningCell);
          print('  Morning mood: "$morningCell" -> $morningMood');
        }

        double? middayMood;
        if (middayRange != null) {
          final middayCell = _getCellValue(csvData, row, middayRange.startCol);
          middayMood = _parseMoodValue(middayCell);
          print('  Midday mood: "$middayCell" -> $middayMood');
        }

        double? eveningMood;
        if (eveningRange != null) {
          final eveningCell = _getCellValue(csvData, row, eveningRange.startCol);
          eveningMood = _parseMoodValue(eveningCell);
          print('  Evening mood: "$eveningCell" -> $eveningMood');
        }

        // Extract notes with detailed logging
        String? morningNotes;
        if (morningNotesRange != null) {
          morningNotes = _getCellValue(csvData, row, morningNotesRange.startCol);
          print('  Morning notes: "${morningNotes?.substring(0, math.min(morningNotes.length, 20)) ?? ""}..."');
        }

        String? middayNotes;
        if (middayNotesRange != null) {
          middayNotes = _getCellValue(csvData, row, middayNotesRange.startCol);
          print('  Midday notes: "${middayNotes?.substring(0, math.min(middayNotes.length, 20)) ?? ""}..."');
        }

        String? eveningNotes;
        if (eveningNotesRange != null) {
          eveningNotes = _getCellValue(csvData, row, eveningNotesRange.startCol);
          print('  Evening notes: "${eveningNotes?.substring(0, math.min(eveningNotes.length, 20)) ?? ""}..."');
        }

        if (morningMood != null || middayMood != null || eveningMood != null) {
          results.add(CSVMoodEntry(
            date: date,
            morningMood: morningMood,
            middayMood: middayMood,
            eveningMood: eveningMood,
            morningNotes: morningNotes?.isNotEmpty == true ? morningNotes : null,
            middayNotes: middayNotes?.isNotEmpty == true ? middayNotes : null,
            eveningNotes: eveningNotes?.isNotEmpty == true ? eveningNotes : null,
          ));
          print('  ✓ Added entry for $date');
        } else {
          print('  ✗ No mood data found for $date');
        }
      } catch (e) {
        errors.add('Error processing row ${row + 1}: $e');
        print('ERROR processing row ${row + 1}: $e');
      }
    }
  }

  static Future<void> _processColumnBasedData(
      List<List<String>> csvData,
      CSVMappingConfig config,
      CellRange dateRange,
      CellRange? morningRange,
      CellRange? middayRange,
      CellRange? eveningRange,
      CellRange? morningNotesRange,
      CellRange? middayNotesRange,
      CellRange? eveningNotesRange,
      List<CSVMoodEntry> results,
      List<String> errors,
      ) async {
    // In column-based layout, iterate through columns
    for (int col = dateRange.startCol; col <= dateRange.endCol; col++) {
      try {
        // Extract date
        final dateCell = _getCellValue(csvData, dateRange.startRow, col);
        if (dateCell.isEmpty) continue; // Skip empty date cells

        final date = _parseDate(dateCell, config.dateFormat);
        if (date == null) {
          errors.add('Column ${_columnToLetter(col)}: Could not parse date "$dateCell"');
          continue;
        }

        // Extract mood values
        final morningMood = morningRange != null
            ? _parseMoodValue(_getCellValue(csvData, morningRange.startRow, col))
            : null;
        final middayMood = middayRange != null
            ? _parseMoodValue(_getCellValue(csvData, middayRange.startRow, col))
            : null;
        final eveningMood = eveningRange != null
            ? _parseMoodValue(_getCellValue(csvData, eveningRange.startRow, col))
            : null;

        // Extract notes
        final morningNotes = morningNotesRange != null
            ? _getCellValue(csvData, morningNotesRange.startRow, col)
            : null;
        final middayNotes = middayNotesRange != null
            ? _getCellValue(csvData, middayNotesRange.startRow, col)
            : null;
        final eveningNotes = eveningNotesRange != null
            ? _getCellValue(csvData, eveningNotesRange.startRow, col)
            : null;

        if (morningMood != null || middayMood != null || eveningMood != null) {
          results.add(CSVMoodEntry(
            date: date,
            morningMood: morningMood,
            middayMood: middayMood,
            eveningMood: eveningMood,
            morningNotes: morningNotes?.isNotEmpty == true ? morningNotes : null,
            middayNotes: middayNotes?.isNotEmpty == true ? middayNotes : null,
            eveningNotes: eveningNotes?.isNotEmpty == true ? eveningNotes : null,
          ));
        }
      } catch (e) {
        errors.add('Error processing column ${_columnToLetter(col)}: $e');
      }
    }
  }

  static String _getCellValue(List<List<String>> csvData, int row, int col) {
    if (row >= csvData.length || row < 0) {
      print('❌ Row $row is out of bounds (CSV has ${csvData.length} rows)');
      return '';
    }
    if (col >= csvData[row].length || col < 0) {
      print('❌ Col $col is out of bounds for row $row (row has ${csvData[row].length} columns)');
      return '';
    }
    final value = csvData[row][col].trim();
    print('📖 Cell[${row + 1}, ${_columnToLetter(col)}] = "$value"');
    return value;
  }

  static DateTime? _parseDate(String dateString, String dateFormat) {
    if (dateString.isEmpty) return null;

    try {
      // Clean up the date string
      dateString = dateString.trim();

      // Try the user-specified format first
      if (dateFormat.isNotEmpty) {
        try {
          final formatter = DateFormat(dateFormat);
          return formatter.parse(dateString);
        } catch (e) {
          print('User format failed for "$dateString" with format "$dateFormat": $e');
        }
      }

      // Try common date formats
      final commonFormats = [
        'yyyy-MM-dd',
        'MM/dd/yyyy',
        'dd/MM/yyyy',
        'M/d/yyyy',
        'd/M/yyyy',
        'yyyy/MM/dd',
        'dd-MM-yyyy',
        'MM-dd-yyyy',
        'yyyy.MM.dd',
        'dd.MM.yyyy',
        'MMM d, yyyy',
        'MMM dd, yyyy',
        'dd MMM yyyy',
        'yyyy-M-d',
        'M-d-yyyy',
        'd-M-yyyy',
      ];

      for (final format in commonFormats) {
        try {
          final formatter = DateFormat(format);
          final parsed = formatter.parse(dateString);
          print('Successfully parsed "$dateString" with format "$format"');
          return parsed;
        } catch (_) {
          continue;
        }
      }

      print('Could not parse date: "$dateString"');
      return null;
    } catch (e) {
      print('Date parsing error for "$dateString": $e');
      return null;
    }
  }

  static double? _parseMoodValue(String moodString) {
    if (moodString.isEmpty) return null;

    try {
      // Clean up the string
      moodString = moodString.trim();

      // Handle common decimal separators
      moodString = moodString.replaceAll(',', '.');

      final value = double.parse(moodString);

      // Validate mood range (1-10)
      if (value >= 1 && value <= 10) {
        return value;
      } else {
        print('Mood value out of range (1-10): $value');
        return null;
      }
    } catch (e) {
      print('Could not parse mood value: "$moodString" - $e');
      return null;
    }
  }

  static CellRange _parseRange(String range) {
    // Parse ranges like "A1:A10", "B5:D5", "C3", etc.
    range = range.trim().toUpperCase();

    if (range.contains(':')) {
      final parts = range.split(':');
      if (parts.length != 2) throw Exception('Invalid range format: $range');

      final start = _parseCellReference(parts[0]);
      final end = _parseCellReference(parts[1]);

      return CellRange(
        startRow: start['row']!,
        startCol: start['col']!,
        endRow: end['row']!,
        endCol: end['col']!,
      );
    } else {
      // Single cell
      final cell = _parseCellReference(range);
      return CellRange(
        startRow: cell['row']!,
        startCol: cell['col']!,
        endRow: cell['row']!,
        endCol: cell['col']!,
      );
    }
  }

  static Map<String, int> _parseCellReference(String cellRef) {
    // Parse cell references like "A1", "BC42", etc.
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(cellRef);
    if (match == null) throw Exception('Invalid cell reference: $cellRef');

    final colStr = match.group(1)!;
    final rowStr = match.group(2)!;

    final col = _letterToColumn(colStr);
    final row = int.parse(rowStr) - 1; // Convert to 0-based index

    return {'row': row, 'col': col};
  }

  static int _letterToColumn(String letters) {
    int result = 0;
    for (int i = 0; i < letters.length; i++) {
      result = result * 26 + (letters.codeUnitAt(i) - 'A'.codeUnitAt(0) + 1);
    }
    return result - 1; // Convert to 0-based index
  }

  static String _columnToLetter(int col) {
    String result = '';
    col++; // Convert to 1-based

    while (col > 0) {
      col--;
      result = String.fromCharCode('A'.codeUnitAt(0) + (col % 26)) + result;
      col ~/= 26;
    }

    return result;
  }
}

// Keep all the existing classes unchanged
class CSVMappingConfig {
  final String dateRange;
  final String dateFormat;
  final String? morningRange;
  final String? middayRange;
  final String? eveningRange;
  final String? morningNotesRange;
  final String? middayNotesRange;
  final String? eveningNotesRange;

  CSVMappingConfig({
    required this.dateRange,
    this.dateFormat = '',
    this.morningRange,
    this.middayRange,
    this.eveningRange,
    this.morningNotesRange,
    this.middayNotesRange,
    this.eveningNotesRange,
  });
}

class CellRange {
  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;

  CellRange({
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
  });
}

class CSVMoodEntry {
  final DateTime date;
  final double? morningMood;
  final double? middayMood;
  final double? eveningMood;
  final String? morningNotes;
  final String? middayNotes;
  final String? eveningNotes;

  CSVMoodEntry({
    required this.date,
    this.morningMood,
    this.middayMood,
    this.eveningMood,
    this.morningNotes,
    this.middayNotes,
    this.eveningNotes,
  });
}

class CSVImportResult {
  final bool success;
  final String? error;
  final int importedEntries;
  final int skippedEntries;
  final int totalEntries;
  final List<String> errors;

  CSVImportResult({
    required this.success,
    this.error,
    this.importedEntries = 0,
    this.skippedEntries = 0,
    this.totalEntries = 0,
    this.errors = const [],
  });
}