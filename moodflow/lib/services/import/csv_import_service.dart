import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../data/mood_data_service.dart';
import '../data/backup_models.dart';
import '../backup/backup_service.dart';

class CSVImportService {
  /// Parse a CSV file and return the raw data
  static Future<List<List<String>>> parseCSVFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      final csvData = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        textEndDelimiter: '"',
        eol: '\n',
      ).convert(content);

      // Convert all cells to strings for easier processing
      return csvData.map((row) =>
          row.map((cell) => cell?.toString() ?? '').toList()
      ).toList();
    } catch (e) {
      throw Exception('Failed to parse CSV file: $e');
    }
  }

  /// Import mood data from CSV using user-defined ranges
  static Future<CSVImportResult> importMoodData({
    required String filePath,
    required CSVMappingConfig config,
  }) async {
    try {
      final csvData = await parseCSVFile(filePath);

      if (csvData.isEmpty) {
        return CSVImportResult(
          success: false,
          error: 'CSV file is empty',
        );
      }

      final results = <CSVMoodEntry>[];
      final errors = <String>[];

      // Extract data from specified ranges
      final dateRange = _parseRange(config.dateRange);
      final morningRange = config.morningRange != null ? _parseRange(config.morningRange!) : null;
      final middayRange = config.middayRange != null ? _parseRange(config.middayRange!) : null;
      final eveningRange = config.eveningRange != null ? _parseRange(config.eveningRange!) : null;
      final morningNotesRange = config.morningNotesRange != null ? _parseRange(config.morningNotesRange!) : null;
      final middayNotesRange = config.middayNotesRange != null ? _parseRange(config.middayNotesRange!) : null;
      final eveningNotesRange = config.eveningNotesRange != null ? _parseRange(config.eveningNotesRange!) : null;

      // Determine if we're using row-based or column-based layout
      final isRowBased = _isRowBasedLayout(dateRange, morningRange, middayRange, eveningRange);

      if (isRowBased) {
        // Row-based: each row represents a day
        await _processRowBasedData(
          csvData, config, dateRange, morningRange, middayRange, eveningRange,
          morningNotesRange, middayNotesRange, eveningNotesRange,
          results, errors,
        );
      } else {
        // Column-based: each column represents a day
        await _processColumnBasedData(
          csvData, config, dateRange, morningRange, middayRange, eveningRange,
          morningNotesRange, middayNotesRange, eveningNotesRange,
          results, errors,
        );
      }

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
          if (entry.morningMood != null && existingMorning == null) {
            await MoodDataService.saveMood(
                entry.date, 0, entry.morningMood!, entry.morningNotes ?? ''
            );
            importedCount++;
          } else if (entry.morningMood != null) {
            skippedCount++;
          }

          // Save midday mood if provided and doesn't exist
          if (entry.middayMood != null && existingMidday == null) {
            await MoodDataService.saveMood(
                entry.date, 1, entry.middayMood!, entry.middayNotes ?? ''
            );
            importedCount++;
          } else if (entry.middayMood != null) {
            skippedCount++;
          }

          // Save evening mood if provided and doesn't exist
          if (entry.eveningMood != null && existingEvening == null) {
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

      return CSVImportResult(
        success: true,
        importedEntries: importedCount,
        skippedEntries: skippedCount,
        totalEntries: results.length,
        errors: errors,
      );

    } catch (e) {
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
    // In row-based layout, iterate through rows
    for (int row = dateRange.startRow; row <= dateRange.endRow; row++) {
      if (row >= csvData.length) break;

      try {
        // Extract date
        final dateCell = _getCellValue(csvData, row, dateRange.startCol);
        final date = _parseDate(dateCell, config.dateFormat);
        if (date == null) continue;

        // Extract mood values
        final morningMood = morningRange != null
            ? _parseMoodValue(_getCellValue(csvData, row, morningRange.startCol))
            : null;
        final middayMood = middayRange != null
            ? _parseMoodValue(_getCellValue(csvData, row, middayRange.startCol))
            : null;
        final eveningMood = eveningRange != null
            ? _parseMoodValue(_getCellValue(csvData, row, eveningRange.startCol))
            : null;

        // Extract notes
        final morningNotes = morningNotesRange != null
            ? _getCellValue(csvData, row, morningNotesRange.startCol)
            : null;
        final middayNotes = middayNotesRange != null
            ? _getCellValue(csvData, row, middayNotesRange.startCol)
            : null;
        final eveningNotes = eveningNotesRange != null
            ? _getCellValue(csvData, row, eveningNotesRange.startCol)
            : null;

        if (morningMood != null || middayMood != null || eveningMood != null) {
          results.add(CSVMoodEntry(
            date: date,
            morningMood: morningMood,
            middayMood: middayMood,
            eveningMood: eveningMood,
            morningNotes: morningNotes,
            middayNotes: middayNotes,
            eveningNotes: eveningNotes,
          ));
        }
      } catch (e) {
        errors.add('Error processing row ${row + 1}: $e');
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
        final date = _parseDate(dateCell, config.dateFormat);
        if (date == null) continue;

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
            morningNotes: morningNotes,
            middayNotes: middayNotes,
            eveningNotes: eveningNotes,
          ));
        }
      } catch (e) {
        errors.add('Error processing column ${_columnToLetter(col)}: $e');
      }
    }
  }

  static String _getCellValue(List<List<String>> csvData, int row, int col) {
    if (row >= csvData.length || col >= csvData[row].length) return '';
    return csvData[row][col].trim();
  }

  static DateTime? _parseDate(String dateString, String dateFormat) {
    if (dateString.isEmpty) return null;

    try {
      // Try the user-specified format first
      if (dateFormat.isNotEmpty) {
        final formatter = DateFormat(dateFormat);
        return formatter.parse(dateString);
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
      ];

      for (final format in commonFormats) {
        try {
          final formatter = DateFormat(format);
          return formatter.parse(dateString);
        } catch (_) {
          continue;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static double? _parseMoodValue(String moodString) {
    if (moodString.isEmpty) return null;

    try {
      final value = double.parse(moodString);
      // Validate mood range (1-10)
      if (value >= 1 && value <= 10) {
        return value;
      }
      return null;
    } catch (e) {
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

  /// Get preview of CSV data for the user to define ranges
  static Future<List<List<String>>> getCSVPreview(String filePath, {int maxRows = 10, int maxCols = 10}) async {
    final csvData = await parseCSVFile(filePath);

    final preview = <List<String>>[];
    for (int i = 0; i < csvData.length && i < maxRows; i++) {
      final row = <String>[];
      for (int j = 0; j < csvData[i].length && j < maxCols; j++) {
        row.add(csvData[i][j]);
      }
      preview.add(row);
    }

    return preview;
  }
}

class CSVMappingConfig {
  final String dateRange; // e.g., "A1:A10"
  final String dateFormat; // e.g., "yyyy-MM-dd"
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