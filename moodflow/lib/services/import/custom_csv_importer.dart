import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../data/mood_data_service.dart';

class CustomCSVImporter {
  /// Import your specific CSV format
  /// A: Date, B: Morning Notes, C: Day Mood, D: Mid-Day Notes, E: Night Mood, F: Night Notes
  static Future<CustomImportResult> importYourCSV(String filePath) async {
    try {
      print('🔄 Starting custom CSV import for: $filePath');

      // Read the file
      final file = File(filePath);
      final content = await file.readAsString();

      // Parse CSV with robust settings for your multiline text
      final csvData = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        eol: '\n',
        allowInvalid: true,
        shouldParseNumbers: false,
      ).convert(content);

      print('📊 Parsed ${csvData.length} rows from CSV');

      if (csvData.length < 2) {
        throw Exception('CSV file must have at least a header row and one data row');
      }

      int imported = 0;
      int skipped = 0;
      final errors = <String>[];

      // Process rows 2-55 (index 1-54, skipping header at index 0)
      for (int i = 1; i < csvData.length && i <= 54; i++) {
        try {
          final row = csvData[i];
          final rowNum = i + 1; // Human-readable row number

          // Ensure row has enough columns
          if (row.length < 6) {
            errors.add('Row $rowNum: Not enough columns (has ${row.length}, need 6)');
            continue;
          }

          // Extract data with safe indexing
          final dateStr = _safeGet(row, 0).trim();
          final morningNotes = _safeGet(row, 1).trim();
          final dayMoodStr = _safeGet(row, 2).trim();
          final middayNotes = _safeGet(row, 3).trim();
          final nightMoodStr = _safeGet(row, 4).trim();
          final nightNotes = _safeGet(row, 5).trim();

          print('📝 Row $rowNum: Date="$dateStr", DayMood="$dayMoodStr", NightMood="$nightMoodStr"');

          // Skip empty rows
          if (dateStr.isEmpty && dayMoodStr.isEmpty && nightMoodStr.isEmpty) {
            print('⏭️ Skipping empty row $rowNum');
            continue;
          }

          // Parse date
          final date = _parseDate(dateStr);
          if (date == null) {
            errors.add('Row $rowNum: Could not parse date "$dateStr"');
            continue;
          }

          // Parse moods
          final dayMood = _parseMood(dayMoodStr);
          final nightMood = _parseMood(nightMoodStr);

          if (dayMood == null && nightMood == null) {
            errors.add('Row $rowNum: No valid mood ratings found');
            continue;
          }

          // Import day mood (morning segment) - OVERWRITE existing data
          if (dayMood != null) {
            await MoodDataService.saveMood(date, 0, dayMood, morningNotes);
            imported++;
            print('✅ Imported/Overwrote day mood: $dayMood for $date');
          }

          // Import midday notes only (no mood rating in your data) - OVERWRITE existing data
          if (middayNotes.isNotEmpty) {
            final existing = await MoodDataService.loadMood(date, 1);
            await MoodDataService.saveMood(date, 1, existing?['rating'] ?? 5.0, middayNotes);
            print('📝 Added/Overwrote midday notes for $date');
          }

          // Import night mood (evening segment) - OVERWRITE existing data
          if (nightMood != null) {
            await MoodDataService.saveMood(date, 2, nightMood, nightNotes);
            imported++;
            print('✅ Imported/Overwrote night mood: $nightMood for $date');
          }

        } catch (e) {
          errors.add('Row ${i + 1}: Import error - $e');
          print('❌ Error on row ${i + 1}: $e');
        }
      }

      print('🎉 Import completed: $imported imported, $skipped skipped, ${errors.length} errors');

      return CustomImportResult(
        success: true,
        imported: imported,
        skipped: skipped,
        errors: errors,
      );

    } catch (e) {
      print('💥 Import failed: $e');
      return CustomImportResult(
        success: false,
        error: e.toString(),
        errors: [],
      );
    }
  }

  static String _safeGet(List<dynamic> row, int index) {
    if (index < row.length && row[index] != null) {
      return row[index].toString();
    }
    return '';
  }

  static DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Your dates are in M/d/yyyy format (like 6/15/2025)
    final formats = [
      'M/d/yyyy',
      'MM/dd/yyyy',
      'M/dd/yyyy',
      'MM/d/yyyy',
      'yyyy-MM-dd',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateStr);
      } catch (_) {
        continue;
      }
    }

    print('❌ Could not parse date: "$dateStr"');
    return null;
  }

  static double? _parseMood(String moodStr) {
    if (moodStr.isEmpty) return null;

    try {
      final value = double.parse(moodStr.trim());
      if (value >= 0 && value <= 10) {
        return value;
      }
    } catch (_) {
      // Not a number
    }

    return null;
  }
}

class CustomImportResult {
  final bool success;
  final int imported;
  final int skipped;
  final List<String> errors;
  final String? error;

  CustomImportResult({
    required this.success,
    this.imported = 0,
    this.skipped = 0,
    this.errors = const [],
    this.error,
  });
}