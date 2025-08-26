import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../services/data/mood_trends_service.dart';

enum ChartAggregation { daily, weekly, monthly }

class MoodLineChart extends StatefulWidget {
  final List<DayMoodData> trendData;
  final ChartAggregation aggregation;

  const MoodLineChart({
    super.key,
    required this.trendData,
    this.aggregation = ChartAggregation.daily,
  });

  @override
  State<MoodLineChart> createState() => _MoodLineChartState();
}

class _MoodLineChartState extends State<MoodLineChart> {
  // Track which lines are visible
  final Map<String, bool> _lineVisibility = {
    'Morning': true,
    'Midday': true,
    'Evening': true,
    'Average': true,
  };

  void _toggleLine(String lineName) {
    setState(() {
      _lineVisibility[lineName] = !_lineVisibility[lineName]!;
    });
  }

  List<AggregatedDataPoint> _aggregateData() {
    if (widget.trendData.isEmpty) return [];

    try {
      switch (widget.aggregation) {
        case ChartAggregation.daily:
          return _getDailyData();
        case ChartAggregation.weekly:
          return _getWeeklyData();
        case ChartAggregation.monthly:
          return _getMonthlyData();
      }
    } catch (e) {
      debugPrint('Error aggregating data: $e');
      return [];
    }
  }

  List<AggregatedDataPoint> _getDailyData() {
    return widget.trendData.asMap().entries.map((entry) {
      final index = entry.key;
      final day = entry.value;

      final moods = <int, double>{};
      for (int segment = 0; segment < 3; segment++) {
        if (day.moods[segment] != null) {
          moods[segment] = day.moods[segment]!;
        }
      }

      return AggregatedDataPoint(
        index: index.toDouble(),
        date: day.date,
        moods: moods,
        label: DateFormat('MMM d').format(day.date),
      );
    }).toList();
  }

  List<AggregatedDataPoint> _getWeeklyData() {
    if (widget.trendData.isEmpty) return [];

    final weeklyData = <DateTime, Map<int, List<double>>>{};

    // Group data by week (Sunday to Saturday)
    for (final day in widget.trendData) {
      final weekStart = _getWeekStart(day.date);
      weeklyData.putIfAbsent(weekStart, () => {0: [], 1: [], 2: []});

      for (int segment = 0; segment < 3; segment++) {
        if (day.moods[segment] != null) {
          weeklyData[weekStart]![segment]!.add(day.moods[segment]!);
        }
      }
    }

    // Calculate weekly averages
    final result = <AggregatedDataPoint>[];
    final sortedWeeks = weeklyData.keys.toList()..sort();

    for (int i = 0; i < sortedWeeks.length; i++) {
      final week = sortedWeeks[i];
      final weekData = weeklyData[week]!;
      final averages = <int, double>{};

      for (int segment = 0; segment < 3; segment++) {
        final segmentData = weekData[segment]!;
        if (segmentData.isNotEmpty) {
          averages[segment] =
              segmentData.reduce((a, b) => a + b) / segmentData.length;
        }
      }

      result.add(AggregatedDataPoint(
        index: i.toDouble(),
        date: week,
        moods: averages,
        label: 'Week of ${DateFormat('MMM d').format(week)}',
      ));
    }

    return result;
  }

  List<AggregatedDataPoint> _getMonthlyData() {
    if (widget.trendData.isEmpty) return [];

    final monthlyData = <DateTime, Map<int, List<double>>>{};

    // Group data by month
    for (final day in widget.trendData) {
      final monthStart = DateTime(day.date.year, day.date.month, 1);
      monthlyData.putIfAbsent(monthStart, () => {0: [], 1: [], 2: []});

      for (int segment = 0; segment < 3; segment++) {
        if (day.moods[segment] != null) {
          monthlyData[monthStart]![segment]!.add(day.moods[segment]!);
        }
      }
    }

    // Calculate monthly averages
    final result = <AggregatedDataPoint>[];
    final sortedMonths = monthlyData.keys.toList()..sort();

    for (int i = 0; i < sortedMonths.length; i++) {
      final month = sortedMonths[i];
      final monthData = monthlyData[month]!;
      final averages = <int, double>{};

      for (int segment = 0; segment < 3; segment++) {
        final segmentData = monthData[segment]!;
        if (segmentData.isNotEmpty) {
          averages[segment] =
              segmentData.reduce((a, b) => a + b) / segmentData.length;
        }
      }

      result.add(AggregatedDataPoint(
        index: i.toDouble(),
        date: month,
        moods: averages,
        label: DateFormat('MMM yyyy').format(month),
      ));
    }

    return result;
  }

  DateTime _getWeekStart(DateTime date) {
    // Get the Sunday of the week containing this date
    final weekday = date.weekday;
    final daysFromSunday = weekday % 7; // Sunday = 0, Monday = 1, etc.
    return DateTime(date.year, date.month, date.day - daysFromSunday);
  }

  String _getAggregationDisplayName(ChartAggregation aggregation) {
    switch (aggregation) {
      case ChartAggregation.daily:
        return 'Daily';
      case ChartAggregation.weekly:
        return 'Weekly';
      case ChartAggregation.monthly:
        return 'Monthly';
    }
  }

  void _showMaximizedChart(BuildContext context) {
    // Force landscape orientation for maximized chart
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: SizedBox(
                width: double.maxFinite,
                height: double.maxFinite,
                child: Column(
                  children: [
                    // Ultra compact header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mood Trends - ${_getAggregationDisplayName(widget.aggregation)} View',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                            onPressed: () {
                              SystemChrome.setPreferredOrientations([
                                DeviceOrientation.portraitUp,
                                DeviceOrientation.portraitDown,
                                DeviceOrientation.landscapeLeft,
                                DeviceOrientation.landscapeRight,
                              ]);
                              Navigator.of(context).pop();
                            },
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                          ),
                        ],
                      ),
                    ),
                    // Expanded chart with minimal padding
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CustomPaint(
                          painter: AggregatedMoodLineChartPainter(
                            _aggregateData(),
                            isMaximized: true,
                            lineVisibility: _lineVisibility,
                            aggregation: widget.aggregation,
                            onLegendTap: (lineName) {
                              setDialogState(() {
                                _lineVisibility[lineName] =
                                    !_lineVisibility[lineName]!;
                              });
                            },
                          ),
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
      },
    ).then((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aggregatedData = _aggregateData();

    if (aggregatedData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Column(
      children: [
        // Chart without legend
        Expanded(
          child: GestureDetector(
            onTap: () => _showMaximizedChart(context),
            child: Stack(
              children: [
                CustomPaint(
                  painter: AggregatedMoodLineChartPainter(
                    aggregatedData,
                    isMaximized: false,
                    lineVisibility: _lineVisibility,
                    aggregation: widget.aggregation,
                    showLegend: false, // Don't show legend in minimized chart
                  ),
                  child: Container(),
                ),
                // Tap hint
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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
          ),
        ),

        // External legend for minimized view
        const SizedBox(height: 12),
        _buildExternalLegend(),
      ],
    );
  }

  Widget _buildExternalLegend() {
    final legendItems = [
      {'color': Colors.orange, 'label': 'Morning'},
      {'color': Colors.blue, 'label': 'Midday'},
      {'color': Colors.purple, 'label': 'Evening'},
      {'color': Colors.green.shade600, 'label': 'Average'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: legendItems.map((item) {
          final label = item['label'] as String;
          final color = item['color'] as Color;
          final isVisible = _lineVisibility[label] ?? true;

          return GestureDetector(
            onTap: () => _toggleLine(label),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isVisible ? color : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isVisible
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MoodLineChartPainter extends CustomPainter {
  final List<DayMoodData> trendData;
  final bool isMaximized;
  final Map<String, bool> lineVisibility;
  final bool showLegend;
  final Function(String)? onLegendTap;

  MoodLineChartPainter(
    this.trendData, {
    this.isMaximized = false,
    required this.lineVisibility,
    this.showLegend = true,
    this.onLegendTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trendData.isEmpty) return;

    // Asymmetric padding - more left, less right
    final leftPadding = isMaximized ? 80.0 : 50.0;
    final rightPadding = isMaximized ? 30.0 : 20.0;
    final topBottomPadding = isMaximized ? 30.0 : 30.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height -
        topBottomPadding * 2 -
        (isMaximized && showLegend ? 45 : 0);

    // Draw background
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade50
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid lines
    _drawGrid(
        canvas, size, leftPadding, topBottomPadding, chartWidth, chartHeight);

    // Draw axes
    _drawAxes(canvas, size, leftPadding, rightPadding, topBottomPadding,
        chartWidth, chartHeight);

    // Draw mood lines
    _drawMoodLines(
        canvas, size, leftPadding, topBottomPadding, chartWidth, chartHeight);

    // Draw legend only for maximized view
    if (isMaximized && showLegend) {
      _drawLegend(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant MoodLineChartPainter oldDelegate) {
    // REPLACE the existing shouldRepaint with this optimized version:
    return trendData != oldDelegate.trendData ||
        isMaximized != oldDelegate.isMaximized ||
        lineVisibility != oldDelegate.lineVisibility ||
        showLegend != oldDelegate.showLegend;
  }

  void _drawGrid(Canvas canvas, Size size, double leftPadding,
      double topPadding, double chartWidth, double chartHeight) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    // Horizontal grid lines (mood levels)
    for (int i = 1; i <= 10; i++) {
      final y = topPadding + chartHeight - (chartHeight * (i / 10));
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );
    }

    // Vertical grid lines
    if (trendData.length > 1) {
      final maxGridLines = isMaximized ? 8 : 5;
      final dataPointInterval =
          (trendData.length / maxGridLines).ceil().clamp(1, trendData.length);

      for (int i = 0; i < trendData.length; i += dataPointInterval) {
        final x = leftPadding + (chartWidth * (i / (trendData.length - 1)));
        canvas.drawLine(
          Offset(x, topPadding),
          Offset(x, topPadding + chartHeight),
          gridPaint,
        );
      }

      if ((trendData.length - 1) % dataPointInterval != 0) {
        final x = leftPadding + chartWidth;
        canvas.drawLine(
          Offset(x, topPadding),
          Offset(x, topPadding + chartHeight),
          gridPaint,
        );
      }
    }
  }

  void _drawAxes(
      Canvas canvas,
      Size size,
      double leftPadding,
      double rightPadding,
      double topPadding,
      double chartWidth,
      double chartHeight) {
    final axisPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2;

    // Y-axis
    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );

    // X-axis
    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(leftPadding + chartWidth, topPadding + chartHeight),
      axisPaint,
    );

    // Y-axis labels (mood values)
    for (int i = 1; i <= 10; i++) {
      final y = topPadding + chartHeight - (chartHeight * (i / 10));

      final textStyle = TextStyle(
        color: Colors.black54,
        fontSize: isMaximized ? 14 : 11,
        fontWeight: FontWeight.w500,
      );
      final textSpan = TextSpan(text: '$i', style: textStyle);
      final textPainter = TextPainter(text: textSpan);
      textPainter.textDirection = ui.TextDirection.ltr;
      textPainter.layout();

      textPainter.paint(
          canvas,
          Offset(
              leftPadding - textPainter.width - 8, y - textPainter.height / 2));
    }

    // X-axis labels (dates)
    if (trendData.length > 1) {
      final maxLabels = isMaximized ? 8 : 4;
      final labelInterval =
          (trendData.length / maxLabels).ceil().clamp(1, trendData.length);

      for (int i = 0; i < trendData.length; i += labelInterval) {
        final x = leftPadding + (chartWidth * (i / (trendData.length - 1)));
        final date = trendData[i].date;

        final dateText = isMaximized
            ? DateFormat('MMM d').format(date)
            : DateFormat('M/d').format(date);

        final textStyle = TextStyle(
          color: Colors.black54,
          fontSize: isMaximized ? 12 : 10,
          fontWeight: FontWeight.w500,
        );
        final textSpan = TextSpan(text: dateText, style: textStyle);
        final textPainter = TextPainter(text: textSpan);
        textPainter.textDirection = ui.TextDirection.ltr;
        textPainter.layout();

        textPainter.paint(canvas,
            Offset(x - textPainter.width / 2, topPadding + chartHeight + 8));
      }

      if ((trendData.length - 1) % labelInterval != 0) {
        final x = leftPadding + chartWidth;
        final date = trendData.last.date;
        final dateText = isMaximized
            ? DateFormat('MMM d').format(date)
            : DateFormat('M/d').format(date);

        final textStyle = TextStyle(
          color: Colors.black54,
          fontSize: isMaximized ? 12 : 10,
          fontWeight: FontWeight.w500,
        );
        final textSpan = TextSpan(text: dateText, style: textStyle);
        final textPainter = TextPainter(text: textSpan);
        textPainter.textDirection = ui.TextDirection.ltr;
        textPainter.layout();

        textPainter.paint(canvas,
            Offset(x - textPainter.width / 2, topPadding + chartHeight + 8));
      }
    }

    // Add "Mood Rating" label on Y-axis
    if (isMaximized) {
      final yAxisLabelStyle = const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
      final yAxisTextSpan =
          TextSpan(text: 'Mood Rating', style: yAxisLabelStyle);
      final yAxisTextPainter = TextPainter(text: yAxisTextSpan);
      yAxisTextPainter.textDirection = ui.TextDirection.ltr;
      yAxisTextPainter.layout();

      canvas.save();
      canvas.translate(20, topPadding + chartHeight / 2);
      canvas.rotate(-1.5708);
      yAxisTextPainter.paint(canvas, Offset(-yAxisTextPainter.width / 2, 0));
      canvas.restore();
    }

    // Add "Date" label on X-axis (maximized only)
    if (isMaximized) {
      final xAxisLabelStyle = const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
      final xAxisTextSpan = TextSpan(text: 'Date', style: xAxisLabelStyle);
      final xAxisTextPainter = TextPainter(text: xAxisTextSpan);
      xAxisTextPainter.textDirection = ui.TextDirection.ltr;
      xAxisTextPainter.layout();

      xAxisTextPainter.paint(
          canvas,
          Offset(leftPadding + chartWidth / 2 - xAxisTextPainter.width / 2,
              topPadding + chartHeight + 35));
    }
  }

  void _drawMoodLines(Canvas canvas, Size size, double leftPadding,
      double topPadding, double chartWidth, double chartHeight) {
    final colors = [
      Colors.orange, // Morning
      Colors.blue, // Midday
      Colors.purple, // Evening
    ];

    final lineNames = ['Morning', 'Midday', 'Evening'];

    for (int segment = 0; segment < 3; segment++) {
      final lineName = lineNames[segment];
      if (!(lineVisibility[lineName] ?? true)) continue; // Skip if hidden

      final points = MoodTrendsService.getChartData(trendData, segment);
      if (points.isEmpty) continue;

      final linePaint = Paint()
        ..color = colors[segment]
        ..strokeWidth = isMaximized ? 4 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final circlePaint = Paint()
        ..color = colors[segment]
        ..style = PaintingStyle.fill;

      final path = Path();
      bool isFirstPoint = true;

      for (final point in points) {
        final x =
            leftPadding + (chartWidth * (point.x / (trendData.length - 1)));
        final y =
            topPadding + chartHeight - (chartHeight * ((point.y - 1) / 9));

        if (isFirstPoint) {
          path.moveTo(x, y);
          isFirstPoint = false;
        } else {
          path.lineTo(x, y);
        }

        canvas.drawCircle(Offset(x, y), isMaximized ? 5 : 4, circlePaint);
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw average line
    if (lineVisibility['Average'] ?? true) {
      final averagePoints = MoodTrendsService.getDailyAverageChart(trendData);
      if (averagePoints.isNotEmpty) {
        final averagePaint = Paint()
          ..color = Colors.green.shade600
          ..strokeWidth = isMaximized ? 3 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final path = Path();
        bool isFirstPoint = true;

        for (final point in averagePoints) {
          final x =
              leftPadding + (chartWidth * (point.x / (trendData.length - 1)));
          final y =
              topPadding + chartHeight - (chartHeight * ((point.y - 1) / 9));

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
  }

  void _drawLegend(Canvas canvas, Size size) {
    final legendItems = [
      {'color': Colors.orange, 'label': 'Morning'},
      {'color': Colors.blue, 'label': 'Midday'},
      {'color': Colors.purple, 'label': 'Evening'},
      {'color': Colors.green.shade600, 'label': 'Average'},
    ];

    final legendHeight = 35.0;
    final legendY = size.height - legendHeight;
    final circleRadius = 6.0;
    final fontSize = 11.0;

    // Draw legend background
    final legendBgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final legendBorderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final legendRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, legendY - 5, size.width - 20, legendHeight - 5),
      const Radius.circular(6),
    );

    canvas.drawRRect(legendRect, legendBgPaint);
    canvas.drawRRect(legendRect, legendBorderPaint);

    // Single row layout for landscape mode
    final itemWidth = (size.width - 40) / legendItems.length;
    final itemY = legendY + (legendHeight / 2) - 5;

    for (int i = 0; i < legendItems.length; i++) {
      final item = legendItems[i];
      final label = item['label'] as String;
      final color = item['color'] as Color;
      final isVisible = lineVisibility[label] ?? true;
      final itemX = 20 + (i * itemWidth) + (itemWidth / 2) - 40;

      // Make the legend tappable by detecting taps (this would need gesture detection in a real implementation)
      final displayColor = isVisible ? color : Colors.grey.shade400;

      final colorPaint = Paint()
        ..color = displayColor
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(Offset(itemX, itemY), circleRadius, colorPaint);
      canvas.drawCircle(Offset(itemX, itemY), circleRadius, borderPaint);

      // Draw label
      final textStyle = TextStyle(
        color: isVisible ? Colors.black87 : Colors.grey.shade500,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      );
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(text: textSpan);
      textPainter.textDirection = ui.TextDirection.ltr;
      textPainter.layout();

      final textY = itemY - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(itemX + circleRadius + 6, textY));
    }
  }
}

// Data class for aggregated points
class AggregatedDataPoint {
  final double index;
  final DateTime date;
  final Map<int, double> moods; // segment -> average mood
  final String label;

  AggregatedDataPoint({
    required this.index,
    required this.date,
    required this.moods,
    required this.label,
  });

  double? get average {
    if (moods.isEmpty) return null;
    final validMoods =
        moods.values.where((mood) => mood.isFinite && !mood.isNaN).toList();
    if (validMoods.isEmpty) return null;

    final total = validMoods.fold(0.0, (sum, mood) => sum + mood);
    final avg = total / validMoods.length;

    return avg.isFinite && !avg.isNaN ? avg : null;
  }
}

// Updated chart painter for aggregated data
class AggregatedMoodLineChartPainter extends CustomPainter {
  final List<AggregatedDataPoint> aggregatedData;
  final bool isMaximized;
  final Map<String, bool> lineVisibility;
  final ChartAggregation aggregation;
  final bool showLegend;
  final Function(String)? onLegendTap;

  AggregatedMoodLineChartPainter(
    this.aggregatedData, {
    this.isMaximized = false,
    required this.lineVisibility,
    required this.aggregation,
    this.showLegend = true,
    this.onLegendTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (aggregatedData.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Asymmetric padding - more left, less right
    final leftPadding = isMaximized ? 80.0 : 50.0;
    final rightPadding = isMaximized ? 30.0 : 20.0;
    final topBottomPadding = isMaximized ? 30.0 : 30.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height -
        topBottomPadding * 2 -
        (isMaximized && showLegend ? 45 : 0);

    // Draw background
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade50
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid, axes, and mood lines using aggregated data
    _drawGrid(
        canvas, size, leftPadding, topBottomPadding, chartWidth, chartHeight);
    _drawAxes(canvas, size, leftPadding, rightPadding, topBottomPadding,
        chartWidth, chartHeight);
    _drawMoodLines(
        canvas, size, leftPadding, topBottomPadding, chartWidth, chartHeight);

    // Draw legend only for maximized view
    if (isMaximized && showLegend) {
      _drawLegend(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double leftPadding,
      double topPadding, double chartWidth, double chartHeight) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    // Horizontal grid lines (mood levels)
    for (int i = 1; i <= 10; i++) {
      final y = topPadding + chartHeight - (chartHeight * (i / 10));
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );
    }

    // Vertical grid lines
    if (aggregatedData.length > 1) {
      final maxGridLines = isMaximized ? 8 : 5;
      final dataPointInterval = (aggregatedData.length / maxGridLines)
          .ceil()
          .clamp(1, aggregatedData.length);

      for (int i = 0; i < aggregatedData.length; i += dataPointInterval) {
        final x =
            leftPadding + (chartWidth * (i / (aggregatedData.length - 1)));
        canvas.drawLine(
          Offset(x, topPadding),
          Offset(x, topPadding + chartHeight),
          gridPaint,
        );
      }
    }
  }

  void _drawAxes(
      Canvas canvas,
      Size size,
      double leftPadding,
      double rightPadding,
      double topPadding,
      double chartWidth,
      double chartHeight) {
    final axisPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2;

    // Y-axis
    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );

    // X-axis
    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(leftPadding + chartWidth, topPadding + chartHeight),
      axisPaint,
    );

    // Y-axis labels (mood values)
    for (int i = 1; i <= 10; i++) {
      final y = topPadding + chartHeight - (chartHeight * (i / 10));

      final textStyle = TextStyle(
        color: Colors.black54,
        fontSize: isMaximized ? 14 : 11,
        fontWeight: FontWeight.w500,
      );
      final textSpan = TextSpan(text: '$i', style: textStyle);
      final textPainter = TextPainter(text: textSpan);
      textPainter.textDirection = ui.TextDirection.ltr;
      textPainter.layout();

      textPainter.paint(
          canvas,
          Offset(
              leftPadding - textPainter.width - 8, y - textPainter.height / 2));
    }

    // X-axis labels using aggregated data labels
    if (aggregatedData.length > 1) {
      final maxLabels = isMaximized ? 8 : 4;
      final labelInterval = (aggregatedData.length / maxLabels)
          .ceil()
          .clamp(1, aggregatedData.length);

      for (int i = 0; i < aggregatedData.length; i += labelInterval) {
        final x =
            leftPadding + (chartWidth * (i / (aggregatedData.length - 1)));
        final dataPoint = aggregatedData[i];

        String dateText;
        switch (aggregation) {
          case ChartAggregation.daily:
            dateText = isMaximized
                ? DateFormat('MMM d').format(dataPoint.date)
                : DateFormat('M/d').format(dataPoint.date);
            break;
          case ChartAggregation.weekly:
            dateText = isMaximized
                ? 'Week ${DateFormat('MMM d').format(dataPoint.date)}'
                : DateFormat('M/d').format(dataPoint.date);
            break;
          case ChartAggregation.monthly:
            dateText = DateFormat('MMM y').format(dataPoint.date);
            break;
        }

        final textStyle = TextStyle(
          color: Colors.black54,
          fontSize: isMaximized ? 12 : 10,
          fontWeight: FontWeight.w500,
        );
        final textSpan = TextSpan(text: dateText, style: textStyle);
        final textPainter = TextPainter(text: textSpan);
        textPainter.textDirection = ui.TextDirection.ltr;
        textPainter.layout();

        textPainter.paint(canvas,
            Offset(x - textPainter.width / 2, topPadding + chartHeight + 8));
      }
    }

    // Add axis labels for maximized view
    if (isMaximized) {
      final yAxisLabelStyle = const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
      final yAxisTextSpan =
          TextSpan(text: 'Mood Rating', style: yAxisLabelStyle);
      final yAxisTextPainter = TextPainter(text: yAxisTextSpan);
      yAxisTextPainter.textDirection = ui.TextDirection.ltr;
      yAxisTextPainter.layout();

      canvas.save();
      canvas.translate(20, topPadding + chartHeight / 2);
      canvas.rotate(-1.5708);
      yAxisTextPainter.paint(canvas, Offset(-yAxisTextPainter.width / 2, 0));
      canvas.restore();

      final xAxisLabelStyle = const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
      final xAxisTextSpan = TextSpan(text: 'Date', style: xAxisLabelStyle);
      final xAxisTextPainter = TextPainter(text: xAxisTextSpan);
      xAxisTextPainter.textDirection = ui.TextDirection.ltr;
      xAxisTextPainter.layout();

      xAxisTextPainter.paint(
          canvas,
          Offset(leftPadding + chartWidth / 2 - xAxisTextPainter.width / 2,
              topPadding + chartHeight + 35));
    }
  }

  void _drawMoodLines(Canvas canvas, Size size, double leftPadding,
      double topPadding, double chartWidth, double chartHeight) {
    final colors = [Colors.orange, Colors.blue, Colors.purple];
    final lineNames = ['Morning', 'Midday', 'Evening'];

    // Draw segment lines
    for (int segment = 0; segment < 3; segment++) {
      final lineName = lineNames[segment];
      if (!(lineVisibility[lineName] ?? true)) continue;

      final points = aggregatedData
          .where((point) => point.moods[segment] != null)
          .toList();
      if (points.isEmpty) continue;

      final linePaint = Paint()
        ..color = colors[segment]
        ..strokeWidth = isMaximized ? 4 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final circlePaint = Paint()
        ..color = colors[segment]
        ..style = PaintingStyle.fill;

      final path = Path();
      bool isFirstPoint = true;

      for (final point in points) {
        if (aggregatedData.length <= 1) continue;

        final x = leftPadding +
            (chartWidth * (point.index / (aggregatedData.length - 1)));
        final y = topPadding +
            chartHeight -
            (chartHeight * ((point.moods[segment]! - 1) / 9));

        // Check for invalid values
        if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) continue;

        if (isFirstPoint) {
          path.moveTo(x, y);
          isFirstPoint = false;
        } else {
          path.lineTo(x, y);
        }

        canvas.drawCircle(Offset(x, y), isMaximized ? 5 : 4, circlePaint);
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw average line
    if (lineVisibility['Average'] ?? true) {
      final averagePoints =
          aggregatedData.where((point) => point.average != null).toList();
      if (averagePoints.isNotEmpty) {
        final averagePaint = Paint()
          ..color = Colors.green.shade600
          ..strokeWidth = isMaximized ? 3 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final path = Path();
        bool isFirstPoint = true;

        for (final point in averagePoints) {
          if (aggregatedData.length <= 1) continue;

          final x = leftPadding +
              (chartWidth * (point.index / (aggregatedData.length - 1)));
          final y = topPadding +
              chartHeight -
              (chartHeight * ((point.average! - 1) / 9));

          // Check for invalid values
          if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) continue;

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
  }

  void _drawLegend(Canvas canvas, Size size) {
    final legendItems = [
      {'color': Colors.orange, 'label': 'Morning'},
      {'color': Colors.blue, 'label': 'Midday'},
      {'color': Colors.purple, 'label': 'Evening'},
      {'color': Colors.green.shade600, 'label': 'Average'},
    ];

    final legendHeight = 35.0;
    final legendY = size.height - legendHeight;
    final circleRadius = 6.0;
    final fontSize = 11.0;

    // Draw legend background
    final legendBgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final legendBorderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final legendRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, legendY - 5, size.width - 20, legendHeight - 5),
      const Radius.circular(6),
    );

    canvas.drawRRect(legendRect, legendBgPaint);
    canvas.drawRRect(legendRect, legendBorderPaint);

    // Draw legend items
    final itemWidth = (size.width - 40) / legendItems.length;
    final itemY = legendY + (legendHeight / 2) - 5;

    for (int i = 0; i < legendItems.length; i++) {
      final item = legendItems[i];
      final label = item['label'] as String;
      final color = item['color'] as Color;
      final isVisible = lineVisibility[label] ?? true;
      final itemX = 20 + (i * itemWidth) + (itemWidth / 2) - 40;

      final displayColor = isVisible ? color : Colors.grey.shade400;

      final colorPaint = Paint()
        ..color = displayColor
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(Offset(itemX, itemY), circleRadius, colorPaint);
      canvas.drawCircle(Offset(itemX, itemY), circleRadius, borderPaint);

      // Draw label
      final textStyle = TextStyle(
        color: isVisible ? Colors.black87 : Colors.grey.shade500,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      );
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(text: textSpan);
      textPainter.textDirection = ui.TextDirection.ltr;
      textPainter.layout();

      final textY = itemY - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(itemX + circleRadius + 6, textY));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
