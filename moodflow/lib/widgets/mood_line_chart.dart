import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../services/data/mood_trends_service.dart';
import '../services/data/mood_data_service.dart';

class MoodLineChart extends StatelessWidget {
  final List<DayMoodData> trendData;

  const MoodLineChart({super.key, required this.trendData});

  void _showMaximizedChart(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(10),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mood Trends - Detailed View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Expanded chart
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      painter: MoodLineChartPainter(trendData, isMaximized: true),
                      child: Container(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return GestureDetector(
      onTap: () => _showMaximizedChart(context),
      child: Stack(
        children: [
          CustomPaint(
            painter: MoodLineChartPainter(trendData),
            child: Container(),
          ),
          // Tap hint
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Tap to expand',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MoodLineChartPainter extends CustomPainter {
  final List<DayMoodData> trendData;
  final bool isMaximized;
  
  MoodLineChartPainter(this.trendData, {this.isMaximized = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (trendData.isEmpty) return;

    final padding = isMaximized ? 60.0 : 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2 - (isMaximized ? 80 : 60); // Extra space for legend

    // Draw background
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade50
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid lines
    _drawGrid(canvas, size, padding, chartWidth, chartHeight);

    // Draw axes
    _drawAxes(canvas, size, padding, chartWidth, chartHeight);

    // Draw mood lines
    _drawMoodLines(canvas, size, padding, chartWidth, chartHeight);

    // Draw legend
    _drawLegend(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size, double padding, double chartWidth, double chartHeight) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    // Horizontal grid lines (mood levels)
    for (int i = 1; i <= 10; i++) {
      final y = padding + chartHeight - (chartHeight * (i / 10));
      canvas.drawLine(
        Offset(padding, y),
        Offset(padding + chartWidth, y),
        gridPaint,
      );
    }

    // Vertical grid lines (time intervals)
    final intervalCount = (trendData.length / 7).ceil().clamp(1, 8);
    for (int i = 0; i <= intervalCount; i++) {
      final x = padding + (chartWidth * (i / intervalCount));
      canvas.drawLine(
        Offset(x, padding),
        Offset(x, padding + chartHeight),
        gridPaint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size, double padding, double chartWidth, double chartHeight) {
    final axisPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2;

    // Y-axis
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, padding + chartHeight),
      axisPaint,
    );

    // X-axis
    canvas.drawLine(
      Offset(padding, padding + chartHeight),
      Offset(padding + chartWidth, padding + chartHeight),
      axisPaint,
    );

    // Y-axis labels (mood values) - using ui.TextDirection
    for (int i = 1; i <= 10; i++) {
      final y = padding + chartHeight - (chartHeight * (i / 10));
      
      final textStyle = const TextStyle(color: Colors.black54, fontSize: 12);
      final textSpan = TextSpan(text: '$i', style: textStyle);
      final textPainter = TextPainter(text: textSpan);
      textPainter.textDirection = ui.TextDirection.ltr;
      textPainter.layout();
      textPainter.paint(canvas, Offset(padding - 25, y - textPainter.height / 2));
    }
  }

  void _drawMoodLines(Canvas canvas, Size size, double padding, double chartWidth, double chartHeight) {
    final colors = [
      Colors.orange, // Morning
      Colors.blue,   // Midday
      Colors.purple, // Evening
    ];

    for (int segment = 0; segment < 3; segment++) {
      final points = MoodTrendsService.getChartData(trendData, segment);
      if (points.isEmpty) continue;

      final linePaint = Paint()
        ..color = colors[segment]
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final circlePaint = Paint()
        ..color = colors[segment]
        ..style = PaintingStyle.fill;

      final path = Path();
      bool isFirstPoint = true;

      for (final point in points) {
        final x = padding + (chartWidth * (point.x / (trendData.length - 1)));
        final y = padding + chartHeight - (chartHeight * ((point.y - 1) / 9));

        if (isFirstPoint) {
          path.moveTo(x, y);
          isFirstPoint = false;
        } else {
          path.lineTo(x, y);
        }

        // Draw circle at data point
        canvas.drawCircle(Offset(x, y), 4, circlePaint);
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw average line
    final averagePoints = MoodTrendsService.getDailyAverageChart(trendData);
    if (averagePoints.isNotEmpty) {
      final averagePaint = Paint()
        ..color = Colors.green.shade600
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      bool isFirstPoint = true;

      for (final point in averagePoints) {
        final x = padding + (chartWidth * (point.x / (trendData.length - 1)));
        final y = padding + chartHeight - (chartHeight * ((point.y - 1) / 9));

        if (isFirstPoint) {
          path.moveTo(x, y);
          isFirstPoint = false;
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, averagePaint);
    }
  }

  void _drawLegend(Canvas canvas, Size size) {
    final legendItems = [
      {'color': Colors.orange, 'label': 'Morning'},
      {'color': Colors.blue, 'label': 'Midday'},
      {'color': Colors.purple, 'label': 'Evening'},
      {'color': Colors.green.shade600, 'label': 'Average'},
    ];

    double xOffset = 20;
    const yOffset = 10.0;

    for (final item in legendItems) {
      // Draw color indicator
      final colorPaint = Paint()
        ..color = item['color'] as Color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(xOffset, yOffset), 6, colorPaint);

      // Draw label - using ui.TextDirection
      final textStyle = const TextStyle(color: Colors.black87, fontSize: 12);
      final textSpan = TextSpan(text: item['label'] as String, style: textStyle);
      final textPainter = TextPainter(text: textSpan);
      textPainter.textDirection = ui.TextDirection.ltr;
      textPainter.layout();
      textPainter.paint(canvas, Offset(xOffset + 15, yOffset - textPainter.height / 2));
      textPainter.layout();
      textPainter.paint(canvas, Offset(xOffset + 15, yOffset - textPainter.height / 2));

      xOffset += textPainter.width + 35;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}