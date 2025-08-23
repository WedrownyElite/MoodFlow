import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_trends_service.dart';
import '../screens/mood_trends_screen.dart';

class MoodHeatmap extends StatelessWidget {
  final List<DayMoodData> trendData;
  final TimeRange timeRange;

  const MoodHeatmap({
    super.key,
    required this.trendData,
    required this.timeRange,
  });

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // For week view, show a simple row
    if (timeRange == TimeRange.week) {
      return _buildWeekView();
    }

    // For longer periods, show calendar grid
    return _buildCalendarView();
  }

  Widget _buildWeekView() {
    return Column(
      children: [
        // Day labels
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Mood cells
        Row(
          children: List.generate(7, (index) {
            final dayData = index < trendData.length ? trendData[index] : null;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _buildDayCell(dayData, isWeekView: true),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildCalendarView() {
    final weeks = <List<DayMoodData?>>[];
    
    // Group days into weeks
    for (int i = 0; i < trendData.length; i += 7) {
      final week = <DayMoodData?>[];
      for (int j = 0; j < 7; j++) {
        final dayIndex = i + j;
        week.add(dayIndex < trendData.length ? trendData[dayIndex] : null);
      }
      weeks.add(week);
    }

    return Column(
      children: [
        // Day labels
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        ...weeks.map((week) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: week.map((dayData) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: _buildDayCell(dayData),
                  ),
                );
              }).toList(),
            ),
          );
        }),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildDayCell(DayMoodData? dayData, {bool isWeekView = false}) {
    final size = isWeekView ? 50.0 : 30.0;
    
    if (dayData == null || !dayData.hasAnyMood) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: isWeekView ? Center(
          child: Text(
            dayData?.date.day.toString() ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ) : null,
      );
    }

    // Calculate average mood for the day
    final moods = dayData.moods.values.where((mood) => mood != null).cast<double>().toList();
    final averageMood = moods.reduce((a, b) => a + b) / moods.length;
    
    // Get color based on mood
    final color = _getMoodColor(averageMood);
    
    return Tooltip(
      message: _buildTooltipMessage(dayData, averageMood),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: isWeekView ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayData.date.day.toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              averageMood.toStringAsFixed(1),
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        ) : moods.length > 1 ? _buildSegmentedCell(dayData, size) : null,
      ),
    );
  }

  Widget _buildSegmentedCell(DayMoodData dayData, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: List.generate(3, (segment) {
          final mood = dayData.moods[segment];
          final color = mood != null ? _getMoodColor(mood) : Colors.grey.shade300;
          return Expanded(
            child: Container(
              height: size,
              color: color,
            ),
          );
        }),
      ),
    );
  }

  Color _getMoodColor(double mood) {
    // Map mood (1-10) to color intensity
    final intensity = (mood - 1) / 9; // Normalize to 0-1
    
    if (intensity < 0.3) {
      // Red tones for low mood
      return Color.lerp(Colors.red.shade800, Colors.red.shade400, intensity / 0.3)!;
    } else if (intensity < 0.7) {
      // Orange/Yellow tones for medium mood
      return Color.lerp(Colors.orange.shade600, Colors.yellow.shade600, (intensity - 0.3) / 0.4)!;
    } else {
      // Green tones for high mood
      return Color.lerp(Colors.yellow.shade600, Colors.green.shade600, (intensity - 0.7) / 0.3)!;
    }
  }

  String _buildTooltipMessage(DayMoodData dayData, double averageMood) {
    final formatter = DateFormat('MMM d');
    final segments = ['Morning', 'Midday', 'Evening'];
    
    String message = '${formatter.format(dayData.date)}\n';
    message += 'Average: ${averageMood.toStringAsFixed(1)}\n';
    
    for (int i = 0; i < 3; i++) {
      final mood = dayData.moods[i];
      if (mood != null) {
        message += '${segments[i]}: ${mood.toStringAsFixed(1)}\n';
      }
    }
    
    return message.trim();
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Less', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          final mood = 1 + (index * 2.25); // 1, 3.25, 5.5, 7.75, 10
          return Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _getMoodColor(mood),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 8),
        const Text('More', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}