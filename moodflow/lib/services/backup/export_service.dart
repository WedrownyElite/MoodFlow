import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/backup_models.dart';
import '../backup/backup_service.dart';
import '../data/mood_data_service.dart';
import '../ai/mood_analysis_service.dart';
import '../data/mood_data_service.dart';

class ExportService {
  /// Export mood data to CSV format
  static Future<String> exportToCSV({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final exportData = await BackupService.exportAllData();

    // Filter data by date range if provided
    var moodEntries = exportData.moodEntries;
    if (startDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isAfter(startDate.subtract(const Duration(days: 1)))
      ).toList();
    }
    if (endDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();
    }

    // Sort by date and segment
    moodEntries.sort((a, b) {
      final dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) return dateComparison;
      return a.segment.compareTo(b.segment);
    });

    // Create CSV rows
    List<List<dynamic>> rows = [];

    // Add header row
    rows.add([
      'Date',
      'Time Segment',
      'Mood Rating',
      'Notes',
      'Logged At',
      'Last Modified'
    ]);

    // Add data rows
    for (final entry in moodEntries) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(entry.date),
        MoodDataService.timeSegments[entry.segment],
        entry.rating,
        entry.note.replaceAll('\n', ' ').replaceAll('\r', ''), // Clean newlines
        DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.loggedAt),
        entry.lastModified != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.lastModified!)
            : 'N/A',
      ]);
    }

    // Convert to CSV string
    String csvString = const ListToCsvConverter().convert(rows);

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'moodflow_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);

    return file.path;
  }

  /// Export mood data to CSV with options
  static Future<String> exportToCSVWithOptions({
    bool includeMoods = true,
    bool includeWeather = true,
    bool includeSleep = true,
    bool includeActivity = true,
    bool includeCorrelations = true,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final exportData = await BackupService.exportSelectedData(
      includeMoods: includeMoods,
      includeWeather: includeWeather,
      includeSleep: includeSleep,
      includeActivity: includeActivity,
      includeCorrelations: includeCorrelations,
      startDate: startDate,
      endDate: endDate,
    );

    // Filter data by date range if provided
    var moodEntries = exportData.moodEntries;
    var correlationEntries = exportData.correlationEntries;

    if (startDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isAfter(startDate.subtract(const Duration(days: 1)))
      ).toList();
      correlationEntries = correlationEntries.where((entry) =>
          entry.date.isAfter(startDate.subtract(const Duration(days: 1)))
      ).toList();
    }
    if (endDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();
      correlationEntries = correlationEntries.where((entry) =>
          entry.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();
    }

    // Create CSV rows
    List<List<dynamic>> rows = [];

    // Dynamic header based on included data
    List<String> headers = ['Date'];
    if (includeMoods) {
      headers.addAll(['Time Segment', 'Mood Rating', 'Notes', 'Logged At']);
    }
    if (includeWeather) {
      headers.addAll(['Weather Condition', 'Temperature', 'Weather Description']);
    }
    if (includeSleep) {
      headers.addAll(['Sleep Quality', 'Bedtime', 'Wake Time', 'Sleep Duration']);
    }
    if (includeActivity) {
      headers.addAll(['Exercise Level', 'Social Activity']);
    }
    if (includeCorrelations) {
      headers.addAll(['Work Stress', 'Custom Tags', 'Additional Notes']);
    }

    rows.add(headers);

    // Create a map of correlation data by date for easier lookup
    final correlationMap = <String, CorrelationEntryExport>{};
    for (final corr in correlationEntries) {
      correlationMap[DateFormat('yyyy-MM-dd').format(corr.date)] = corr;
    }

    // Add data rows
    if (includeMoods && moodEntries.isNotEmpty) {
      for (final entry in moodEntries) {
        List<dynamic> row = [DateFormat('yyyy-MM-dd').format(entry.date)];

        if (includeMoods) {
          row.addAll([
            MoodDataService.timeSegments[entry.segment],
            entry.rating,
            entry.note.replaceAll('\n', ' ').replaceAll('\r', ''),
            DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.loggedAt),
          ]);
        }

        // Add correlation data for this date if available
        final dateKey = DateFormat('yyyy-MM-dd').format(entry.date);
        final correlation = correlationMap[dateKey];

        if (includeWeather) {
          row.addAll([
            correlation?.weather ?? ' ',
            correlation?.temperature?.toString() ?? ' ',
            correlation?.weatherDescription ?? ' ',
          ]);
        }
        if (includeSleep) {
          row.addAll([
            correlation?.sleepQuality?.toString() ?? '',
            correlation?.bedtime != null ? DateFormat('HH:mm').format(correlation!.bedtime!) : '',
            correlation?.wakeTime != null ? DateFormat('HH:mm').format(correlation!.wakeTime!) : '',
            correlation?.sleepDurationMinutes != null ? '${correlation!.sleepDurationMinutes! ~/ 60}h ${correlation.sleepDurationMinutes! % 60}m' : '',
          ]);
        }
        if (includeActivity) {
          row.addAll([
            correlation?.exerciseLevel ?? '',
            correlation?.socialActivity ?? '',
          ]);
        }
        if (includeCorrelations) {
          row.addAll([
            correlation?.workStress?.toString() ?? '',
            correlation?.customTags.join('; ') ?? '',
            correlation?.notes ?? '',
          ]);
        }

        rows.add(row);
      }
    }

    // Convert to CSV string
    String csvString = const ListToCsvConverter().convert(rows);

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'moodflow_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);

    return file.path;
  }

  /// Export mood data to PDF with options
  /// Export mood data to PDF with options
  static Future<String> exportToPDFWithOptions({
    bool includeMoods = true,
    bool includeWeather = true,
    bool includeSleep = true,
    bool includeActivity = true,
    bool includeCorrelations = true,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final exportData = await BackupService.exportSelectedData(
      includeMoods: includeMoods,
      includeWeather: includeWeather,
      includeSleep: includeSleep,
      includeActivity: includeActivity,
      includeCorrelations: includeCorrelations,
      startDate: startDate,
      endDate: endDate,
    );

    // Filter and organize data
    var moodEntries = exportData.moodEntries;
    var correlationEntries = exportData.correlationEntries;

    if (startDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isAfter(startDate.subtract(const Duration(days: 1)))
      ).toList();
      correlationEntries = correlationEntries.where((entry) =>
          entry.date.isAfter(startDate.subtract(const Duration(days: 1)))
      ).toList();
    }
    if (endDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();
      correlationEntries = correlationEntries.where((entry) =>
          entry.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();
    }

    // Create combined data structure
    final combinedData = _createCombinedDataStructure(
      moodEntries,
      correlationEntries,
      startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      endDate ?? DateTime.now(),
    );

    // Create PDF document
    final pdf = pw.Document();

    // Add title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'MoodFlow Professional Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo800,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Export Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              ),
              if (startDate != null || endDate != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Date Range: ${startDate != null ? DateFormat('MMM d, yyyy').format(startDate) : 'Beginning'} - ${endDate != null ? DateFormat('MMM d, yyyy').format(endDate) : 'Present'}',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Text(
                'Included Data: ${_getIncludedDataDescription(includeMoods, includeWeather, includeSleep, includeActivity, includeCorrelations)}',
                style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 30),
              if (includeMoods && moodEntries.isNotEmpty) _buildSummarySection(moodEntries),
            ],
          );
        },
      ),
    );

    // Add combined data table if we have any data
    if (combinedData.isNotEmpty) {
      _addCombinedDataPages(
          pdf,
          combinedData,
          includeMoods,
          includeWeather,
          includeSleep,
          includeActivity,
          includeCorrelations
      );
    }

    // Add goals section if available
    if (exportData.goals.isNotEmpty) {
      _addGoalsPage(pdf, exportData.goals);
    }

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'moodflow_professional_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Export AI analyses only
  static Future<String> exportAIAnalyses() async {
    try {
      final analyses = await MoodAnalysisService.getSavedAnalyses();

      if (analyses.isEmpty) {
        throw Exception('No AI analyses found to export');
      }

      final exportData = {
        'appVersion': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'exportType': 'ai_analyses_only',
        'totalAnalyses': analyses.length,
        'savedAnalyses': analyses.map((analysis) => analysis.toJson()).toList(),
      };

      final jsonString = jsonEncode(exportData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'moodflow_ai_analyses_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      return file.path;
    } catch (e) {
      throw Exception('Failed to export AI analyses: $e');
    }
  }

  static String _getIncludedDataDescription(bool moods, bool weather, bool sleep, bool activity, bool correlations) {
    final included = <String>[];
    if (moods) included.add('Moods');
    if (weather) included.add('Weather');
    if (sleep) included.add('Sleep');
    if (activity) included.add('Activity');
    if (correlations) included.add('All Correlations');
    return included.join(', ');
  }

  static void _addCorrelationDataPages(pw.Document pdf, List<CorrelationEntryExport> entries, bool includeWeather, bool includeSleep, bool includeActivity, bool includeCorrelations) {
    const int entriesPerPage = 20;

    for (int startIndex = 0; startIndex < entries.length; startIndex += entriesPerPage) {
      final endIndex = (startIndex + entriesPerPage < entries.length)
          ? startIndex + entriesPerPage
          : entries.length;

      final pageEntries = entries.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Daily Factors Data (${startIndex + 1} - $endIndex of ${entries.length})',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 15),
                ...pageEntries.map((entry) => _buildCorrelationEntryWidget(entry, includeWeather, includeSleep, includeActivity, includeCorrelations)),
              ],
            );
          },
        ),
      );
    }
  }

  static pw.Widget _buildCorrelationEntryWidget(CorrelationEntryExport entry, bool includeWeather, bool includeSleep, bool includeActivity, bool includeCorrelations) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            DateFormat('EEEE, MMM d, yyyy').format(entry.date),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          if (includeWeather && (entry.weather != null || entry.temperature != null)) ...[
            pw.Text('Weather: ${entry.weather ?? 'N/A'}${entry.temperature != null ? ', ${entry.temperature}°' : ''}', style: pw.TextStyle(fontSize: 10)),
          ],
          if (includeSleep && entry.sleepQuality != null) ...[
            pw.Text('Sleep Quality: ${entry.sleepQuality}/10', style: pw.TextStyle(fontSize: 10)),
          ],
          if (includeActivity && entry.exerciseLevel != null) ...[
            pw.Text('Exercise: ${entry.exerciseLevel}', style: pw.TextStyle(fontSize: 10)),
          ],
          if (includeCorrelations && entry.workStress != null) ...[
            pw.Text('Work Stress: ${entry.workStress}/10', style: pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }

  /// Export mood data to PDF format
  static Future<String> exportToPDF({
    DateTime? startDate,
    DateTime? endDate,
    bool includeCharts = false,
  }) async {
    final exportData = await BackupService.exportAllData();

    // Filter data by date range if provided
    var moodEntries = exportData.moodEntries;
    if (startDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isAfter(startDate.subtract(const Duration(days: 1)))
      ).toList();
    }
    if (endDate != null) {
      moodEntries = moodEntries.where((entry) =>
          entry.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();
    }

    // Sort by date and segment
    moodEntries.sort((a, b) {
      final dateComparison = a.date.compareTo(b.date);
      if (dateComparison != 0) return dateComparison;
      return a.segment.compareTo(b.segment);
    });

    // Create PDF document
    final pdf = pw.Document();

    // Add title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'MoodFlow Export Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Export Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 14),
              ),
              if (startDate != null || endDate != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Date Range: ${startDate != null ? DateFormat('MMM d, yyyy').format(startDate) : 'Beginning'} - ${endDate != null ? DateFormat('MMM d, yyyy').format(endDate) : 'Present'}',
                  style: pw.TextStyle(fontSize: 14),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Text(
                'Total Entries: ${moodEntries.length}',
                style: pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 30),
              _buildSummarySection(moodEntries),
            ],
          );
        },
      ),
    );

    // Add mood entries table
    if (moodEntries.isNotEmpty) {
      _addMoodEntriesPages(pdf, moodEntries);
    }

    // Add goals section
    if (exportData.goals.isNotEmpty) {
      _addGoalsPage(pdf, exportData.goals);
    }

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'moodflow_export_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Share exported file
  static Future<void> shareFile(String filePath, {String? subject}) async {
    final file = XFile(filePath);
    final fileName = filePath.split('/').last;

    await Share.shareXFiles(
      [file],
      subject: subject ?? 'MoodFlow Export - $fileName',
      text: 'Here\'s my mood tracking data exported from MoodFlow.',
    );
  }

  /// Get export file info
  static Future<Map<String, dynamic>> getExportInfo(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return {'exists': false};
    }

    final stat = await file.stat();
    final fileName = filePath.split('/').last;
    final fileExtension = fileName.split('.').last.toUpperCase();

    return {
      'exists': true,
      'name': fileName,
      'size': _formatFileSize(stat.size),
      'type': fileExtension,
      'created': stat.modified,
    };
  }

  /// Format file size for display
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Build summary section for PDF
  static pw.Widget _buildSummarySection(List<MoodEntryExport> entries) {
    if (entries.isEmpty) {
      return pw.Text('No mood entries to analyze.');
    }

    // Calculate statistics
    final totalRatings = entries.map((e) => e.rating).toList();
    final averageRating = totalRatings.reduce((a, b) => a + b) / totalRatings.length;

    final segmentCounts = <int, int>{0: 0, 1: 0, 2: 0};
    final segmentAverages = <int, double>{0: 0, 1: 0, 2: 0};
    final segmentTotals = <int, double>{0: 0, 1: 0, 2: 0};

    for (final entry in entries) {
      segmentCounts[entry.segment] = (segmentCounts[entry.segment] ?? 0) + 1;
      segmentTotals[entry.segment] = (segmentTotals[entry.segment] ?? 0) + entry.rating;
    }

    for (int i = 0; i < 3; i++) {
      if (segmentCounts[i]! > 0) {
        segmentAverages[i] = segmentTotals[i]! / segmentCounts[i]!;
      }
    }

    final uniqueDays = entries.map((e) => DateFormat('yyyy-MM-dd').format(e.date)).toSet().length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Summary Statistics',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 15),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            ]),
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Overall Average Mood')),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(averageRating.toStringAsFixed(1))),
            ]),
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Days with Data')),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$uniqueDays')),
            ]),
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Morning Average')),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(segmentCounts[0]! > 0 ? segmentAverages[0]!.toStringAsFixed(1) : 'N/A')),
            ]),
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Midday Average')),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(segmentCounts[1]! > 0 ? segmentAverages[1]!.toStringAsFixed(1) : 'N/A')),
            ]),
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Evening Average')),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(segmentCounts[2]! > 0 ? segmentAverages[2]!.toStringAsFixed(1) : 'N/A')),
            ]),
          ],
        ),
      ],
    );
  }

  /// Create combined data structure merging moods and correlations by day
  static List<CombinedDayData> _createCombinedDataStructure(
      List<MoodEntryExport> moodEntries,
      List<CorrelationEntryExport> correlationEntries,
      DateTime startDate,
      DateTime endDate,
      ) {
    final combinedData = <CombinedDayData>[];

    // Group mood entries by date
    final moodsByDate = <String, Map<int, MoodEntryExport>>{};
    for (final mood in moodEntries) {
      final dateKey = DateFormat('yyyy-MM-dd').format(mood.date);
      moodsByDate.putIfAbsent(dateKey, () => {});
      moodsByDate[dateKey]![mood.segment] = mood;
    }

    // Create correlation map by date
    final correlationsByDate = <String, CorrelationEntryExport>{};
    for (final corr in correlationEntries) {
      final dateKey = DateFormat('yyyy-MM-dd').format(corr.date);
      correlationsByDate[dateKey] = corr;
    }

    // Iterate through all days in range
    DateTime? firstDataDate;
    DateTime scanDate = startDate;
    while (scanDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(scanDate);
      final dayMoods = moodsByDate[dateKey];
      final dayCorrelation = correlationsByDate[dateKey];

      if ((dayMoods != null && dayMoods.isNotEmpty) || dayCorrelation != null) {
        firstDataDate = scanDate;
        break;
      }
      scanDate = scanDate.add(const Duration(days: 1));
    }

    // Use actual first data date or start date if no data found
    DateTime currentDate = firstDataDate ?? startDate;
    DateTime? missedRangeStart;

    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      final dayMoods = moodsByDate[dateKey];
      final dayCorrelation = correlationsByDate[dateKey];

      final hasData = (dayMoods != null && dayMoods.isNotEmpty) || dayCorrelation != null;

      if (hasData) {
        // If we were tracking missed days, close that range
        if (missedRangeStart != null) {
          final missedRangeEnd = currentDate.subtract(const Duration(days: 1));
          combinedData.add(CombinedDayData.missedRange(missedRangeStart, missedRangeEnd));
          missedRangeStart = null;
        }

        // Add actual data
        combinedData.add(CombinedDayData(
          date: currentDate,
          moods: dayMoods ?? {},
          correlation: dayCorrelation,
          isMissed: false,
        ));
      } else {
        // Start tracking missed days if not already
        missedRangeStart ??= currentDate;
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Close any remaining missed range
    if (missedRangeStart != null) {
      final missedRangeEnd = currentDate.subtract(const Duration(days: 1));
      combinedData.add(CombinedDayData.missedRange(missedRangeStart, missedRangeEnd));
    }

    return combinedData;
  }

  /// Add combined data pages to PDF
  static void _addCombinedDataPages(
      pw.Document pdf,
      List<CombinedDayData> combinedData,
      bool includeMoods,
      bool includeWeather,
      bool includeSleep,
      bool includeActivity,
      bool includeCorrelations,
      ) {
    const int entriesPerPage = 15; // Fewer entries per page for better readability

    for (int startIndex = 0; startIndex < combinedData.length; startIndex += entriesPerPage) {
      final endIndex = (startIndex + entriesPerPage < combinedData.length)
          ? startIndex + entriesPerPage
          : combinedData.length;

      final pageEntries = combinedData.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Daily Mood & Factors Report (${startIndex + 1} - $endIndex of ${combinedData.length})',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo800,
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    columnWidths: _getColumnWidths(includeMoods, includeWeather, includeSleep, includeActivity, includeCorrelations),
                    children: [
                      // Header row
                      _buildTableHeader(includeMoods, includeWeather, includeSleep, includeActivity, includeCorrelations),
                      // Data rows
                      ...pageEntries.expand((entry) => _buildDataRows(
                          entry,
                          includeMoods,
                          includeWeather,
                          includeSleep,
                          includeActivity,
                          includeCorrelations
                      )),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  /// Build table header
  static pw.TableRow _buildTableHeader(
      bool includeMoods,
      bool includeWeather,
      bool includeSleep,
      bool includeActivity,
      bool includeCorrelations
      ) {
    final headers = <pw.Widget>[
      _buildHeaderCell('Date'),
    ];

    if (includeMoods) {
      headers.addAll([
        _buildHeaderCell('Time'),
        _buildHeaderCell('Mood'),
        _buildHeaderCell('Notes'),
      ]);
    }

    if (includeWeather) {
      headers.addAll([
        _buildHeaderCell('Weather'),
        _buildHeaderCell('Temp'),
      ]);
    }

    if (includeSleep) {
      headers.addAll([
        _buildHeaderCell('Sleep'),
        _buildHeaderCell('Bedtime'),
      ]);
    }

    if (includeActivity) {
      headers.add(_buildHeaderCell('Exercise'));
    }

    if (includeCorrelations) {
      headers.add(_buildHeaderCell('Stress'));
    }

    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.indigo100),
      children: headers,
    );
  }

  /// Build header cell
  static pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.indigo800,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Build data rows for a day (can be multiple rows if multiple mood segments)
  static List<pw.TableRow> _buildDataRows(
      CombinedDayData dayData,
      bool includeMoods,
      bool includeWeather,
      bool includeSleep,
      bool includeActivity,
      bool includeCorrelations,
      ) {
    if (dayData.isMissed) {
      // Single row for missed days range
      return [_buildMissedDayRow(dayData, includeMoods, includeWeather, includeSleep, includeActivity, includeCorrelations)];
    }

    if (!includeMoods || dayData.moods.isEmpty) {
      // Single row with just correlation data
      return [_buildSingleDataRow(dayData, null, includeMoods, includeWeather, includeSleep, includeActivity, includeCorrelations)];
    }

    // Multiple rows for each mood segment
    final rows = <pw.TableRow>[];
    final sortedSegments = dayData.moods.keys.toList()..sort();

    for (int i = 0; i < sortedSegments.length; i++) {
      final segment = sortedSegments[i];
      final mood = dayData.moods[segment]!;
      final isFirstRow = i == 0;

      rows.add(_buildSingleDataRow(
        dayData,
        mood,
        includeMoods,
        includeWeather,
        includeSleep,
        includeActivity,
        includeCorrelations,
        showDateAndCorrelation: isFirstRow,
        rowIndex: i,
      ));
    }

    return rows;
  }

  /// Build missed day row
  static pw.TableRow _buildMissedDayRow(
      CombinedDayData dayData,
      bool includeMoods,
      bool includeWeather,
      bool includeSleep,
      bool includeActivity,
      bool includeCorrelations,
      ) {
    final cells = <pw.Widget>[];

    // Date cell
    cells.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: const pw.BoxDecoration(color: PdfColors.red100),
        child: pw.Text(
          dayData.missedRangeText ?? 'Missed Day',
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.red800,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );

    // Fill remaining cells with "No data" indicator
    final totalCells = _getTotalColumnCount(includeMoods, includeWeather, includeSleep, includeActivity, includeCorrelations);
    for (int i = 1; i < totalCells; i++) {
      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: const pw.BoxDecoration(color: PdfColors.red50),
          child: pw.Text(
            '—',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.red400),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );
    }

    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.red50),
      children: cells,
    );
  }

  /// Build single data row
  static pw.TableRow _buildSingleDataRow(
      CombinedDayData dayData,
      MoodEntryExport? mood,
      bool includeMoods,
      bool includeWeather,
      bool includeSleep,
      bool includeActivity,
      bool includeCorrelations, {
        bool showDateAndCorrelation = true,
        int rowIndex = 0,
      }) {
    final cells = <pw.Widget>[];

    // Alternating row colors with segment-specific colors
    PdfColor backgroundColor;
    if (mood != null) {
      switch (mood.segment) {
        case 0: // Morning
          backgroundColor = rowIndex % 2 == 0 ? PdfColors.orange50 : PdfColors.orange100;
          break;
        case 1: // Midday
          backgroundColor = rowIndex % 2 == 0 ? PdfColors.blue50 : PdfColors.blue100;
          break;
        case 2: // Evening
          backgroundColor = rowIndex % 2 == 0 ? PdfColors.purple50 : PdfColors.purple100;
          break;
        default:
          backgroundColor = rowIndex % 2 == 0 ? PdfColors.grey50 : PdfColors.grey100;
      }
    } else {
      backgroundColor = rowIndex % 2 == 0 ? PdfColors.grey50 : PdfColors.grey100;
    }

    // Date cell
    cells.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          showDateAndCorrelation ? DateFormat('MMM d, yyyy').format(dayData.date) : '',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: showDateAndCorrelation ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );

    if (includeMoods) {
      // Time segment
      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            mood != null ? MoodDataService.timeSegments[mood.segment] : '—',
            style: pw.TextStyle(fontSize: 9),
          ),
        ),
      );

      // Mood rating
      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            mood?.rating.toStringAsFixed(1) ?? '—',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: mood != null ? _getMoodColor(mood.rating) : PdfColors.grey500,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );

      // Notes
      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            mood?.note.isNotEmpty == true ? mood!.note.replaceAll('\n', ' ').replaceAll('\r', '') : '—',
            style: pw.TextStyle(fontSize: 8),
            maxLines: null, // Allow unlimited lines
            softWrap: true,
          ),
        ),
      );
    }

    if (includeWeather && showDateAndCorrelation) {
      cells.addAll([
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            dayData.correlation?.weather ?? '—',
            style: pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            dayData.correlation?.temperature?.toStringAsFixed(1) ?? '—',
            style: pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ]);
    } else if (includeWeather) {
      cells.addAll([
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(' ', style: pw.TextStyle(fontSize: 9)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(' ', style: pw.TextStyle(fontSize: 9)),
        ),
      ]);
    }

    if (includeSleep && showDateAndCorrelation) {
      cells.addAll([
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            dayData.correlation?.sleepQuality?.toStringAsFixed(1) ?? '—',
            style: pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            dayData.correlation?.bedtime != null
                ? DateFormat('HH:mm').format(dayData.correlation!.bedtime!)
                : '—',
            style: pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ]);
    } else if (includeSleep) {
      cells.addAll([
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(' ', style: pw.TextStyle(fontSize: 9)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(' ', style: pw.TextStyle(fontSize: 9)),
        ),
      ]);
    }

    if (includeActivity && showDateAndCorrelation) {
      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            dayData.correlation?.exerciseLevel ?? '—',
            style: pw.TextStyle(fontSize: 9),
          ),
        ),
      );
    } else if (includeActivity) {
      cells.add(pw.Container(padding: const pw.EdgeInsets.all(6)));
    }

    if (includeCorrelations && showDateAndCorrelation) {
      cells.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            dayData.correlation?.workStress?.toString() ?? '—',
            style: pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );
    } else if (includeCorrelations) {
      cells.add(pw.Container(padding: const pw.EdgeInsets.all(6)));
    }

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: backgroundColor),
      children: cells,
    );
  }

  /// Get mood color based on rating
  static PdfColor _getMoodColor(double rating) {
    if (rating >= 8) return PdfColors.green600;
    if (rating >= 6) return PdfColors.blue600;
    if (rating >= 4) return PdfColors.orange600;
    return PdfColors.red600;
  }

  /// Get column widths for table
  static Map<int, pw.TableColumnWidth> _getColumnWidths(
      bool includeMoods,
      bool includeWeather,
      bool includeSleep,
      bool includeActivity,
      bool includeCorrelations,
      ) {
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(80), // Date
    };

    int columnIndex = 1;

    if (includeMoods) {
      widths[columnIndex++] = const pw.FixedColumnWidth(50); // Time
      widths[columnIndex++] = const pw.FixedColumnWidth(40); // Mood
      widths[columnIndex++] = const pw.FlexColumnWidth(3);  // Notes
    }

    if (includeWeather) {
      widths[columnIndex++] = const pw.FixedColumnWidth(60); // Weather
      widths[columnIndex++] = const pw.FixedColumnWidth(40); // Temp
    }

    if (includeSleep) {
      widths[columnIndex++] = const pw.FixedColumnWidth(40); // Sleep
      widths[columnIndex++] = const pw.FixedColumnWidth(50); // Bedtime
    }

    if (includeActivity) {
      widths[columnIndex++] = const pw.FixedColumnWidth(60); // Exercise
    }

    if (includeCorrelations) {
      widths[columnIndex++] = const pw.FixedColumnWidth(40); // Stress
    }

    return widths;
  }

  /// Get total column count
  static int _getTotalColumnCount(
      bool includeMoods,
      bool includeWeather,
      bool includeSleep,
      bool includeActivity,
      bool includeCorrelations,
      ) {
    int count = 1; // Date column

    if (includeMoods) count += 3; // Time, Mood, Notes
    if (includeWeather) count += 2; // Weather, Temp
    if (includeSleep) count += 2; // Sleep, Bedtime
    if (includeActivity) count += 1; // Exercise
    if (includeCorrelations) count += 1; // Stress

    return count;
  }

  /// Add mood entries pages to PDF
  static void _addMoodEntriesPages(pw.Document pdf, List<MoodEntryExport> entries) {
    const int entriesPerPage = 25;

    for (int startIndex = 0; startIndex < entries.length; startIndex += entriesPerPage) {
      final endIndex = (startIndex + entriesPerPage < entries.length)
          ? startIndex + entriesPerPage
          : entries.length;

      final pageEntries = entries.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Mood Entries (${startIndex + 1} - $endIndex of ${entries.length})',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 15),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(80),  // Date
                    1: const pw.FixedColumnWidth(60),  // Segment
                    2: const pw.FixedColumnWidth(40),  // Rating
                    3: const pw.FlexColumnWidth(2),    // Notes
                    4: const pw.FixedColumnWidth(80),  // Logged At
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _buildTableCell('Date', true),
                        _buildTableCell('Time', true),
                        _buildTableCell('Rating', true),
                        _buildTableCell('Notes', true),
                        _buildTableCell('Logged', true),
                      ],
                    ),
                    // Data rows
                    ...pageEntries.map((entry) => pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('MM/dd/yy').format(entry.date)),
                        _buildTableCell(MoodDataService.timeSegments[entry.segment]),
                        _buildTableCell(entry.rating.toStringAsFixed(1)),
                        _buildTableCell(_truncateText(entry.note, 50)),
                        _buildTableCell(DateFormat('MM/dd HH:mm').format(entry.loggedAt)),
                      ],
                    )),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }
  }

  /// Add goals page to PDF
  static void _addGoalsPage(pw.Document pdf, List<MoodGoalExport> goals) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Mood Goals',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              ...goals.map((goal) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      goal.title,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(goal.description, style: pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      children: [
                        pw.Text('Created: ${DateFormat('MM/dd/yyyy').format(goal.createdDate)}',
                            style: pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(width: 20),
                        pw.Text('Status: ${goal.isCompleted ? "Completed" : "Active"}',
                            style: pw.TextStyle(fontSize: 10)),
                        if (goal.completedDate != null) ...[
                          pw.SizedBox(width: 20),
                          pw.Text('Completed: ${DateFormat('MM/dd/yyyy').format(goal.completedDate!)}',
                              style: pw.TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  /// Build table cell with consistent formatting
  static pw.Widget _buildTableCell(String text, [bool isHeader = false]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Truncate text to fit in table cells
  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}

/// Data class for combining mood and correlation data by day
class CombinedDayData {
  final DateTime date;
  final Map<int, MoodEntryExport> moods;
  final CorrelationEntryExport? correlation;
  final bool isMissed;
  final String? missedRangeText;

  CombinedDayData({
    required this.date,
    required this.moods,
    this.correlation,
    this.isMissed = false,
    this.missedRangeText,
  });

  /// Create a missed day range entry
  factory CombinedDayData.missedRange(DateTime startDate, DateTime endDate) {
    final daysDiff = endDate.difference(startDate).inDays;
    String rangeText;

    if (daysDiff == 0) {
      rangeText = 'Missed: ${DateFormat('MMM d').format(startDate)}';
    } else {
      rangeText = 'Missed: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)} (${daysDiff + 1} days)';
    }

    return CombinedDayData(
      date: startDate,
      moods: {},
      isMissed: true,
      missedRangeText: rangeText,
    );
  }
}