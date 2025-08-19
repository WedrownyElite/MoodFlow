import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/backup_models.dart';
import '../backup/backup_service.dart';
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
                    )).toList(),
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
              )).toList(),
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