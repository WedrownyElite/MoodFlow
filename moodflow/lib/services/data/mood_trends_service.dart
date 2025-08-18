// Updated mood_trends_service.dart with separate total days calculation
import 'dart:math';
import '../data/mood_data_service.dart';

class MoodTrendsService {
  /// Get mood data for a date range
  static Future<List<DayMoodData>> getMoodTrends({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final List<DayMoodData> trends = [];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dayData = DayMoodData(date: currentDate);

      // Load mood data for each time segment
      for (int i = 0; i < MoodDataService.timeSegments.length; i++) {
        final moodData = await MoodDataService.loadMood(currentDate, i);
        if (moodData != null && moodData['rating'] != null) {
          dayData.moods[i] = (moodData['rating'] as num).toDouble();
        }
      }

      trends.add(dayData);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return trends;
  }

  /// Calculate total days logged across ALL time (independent of date range)
  static Future<int> getTotalDaysLogged() async {
    final today = DateTime.now();
    final startDate = today.subtract(const Duration(days: 3650)); // Check last 10 years

    int totalDaysLogged = 0;

    DateTime currentDate = startDate;
    while (currentDate.isBefore(today) || currentDate.isAtSameMomentAs(today)) {
      bool hasAnyMood = false;

      // Check all segments for this day
      for (int segment = 0; segment < MoodDataService.timeSegments.length; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        if (moodData != null && moodData['rating'] != null) {
          hasAnyMood = true;
          break; // Found at least one mood for this day
        }
      }

      if (hasAnyMood) {
        totalDaysLogged++;
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return totalDaysLogged;
  }

  /// Calculate statistics from mood trends (for date range specific stats)
  /// BUT use separate total days logged calculation
  static Future<MoodStatistics> calculateStatistics(List<DayMoodData> trends) async {
    if (trends.isEmpty) {
      // Even if no trends in range, still get total days logged
      final totalDaysLogged = await getTotalDaysLogged();
      return MoodStatistics(
        daysLogged: totalDaysLogged,
        currentStreak: 0,
        overallAverage: 0.0,
        timeSegmentAverages: {},
        bestTimeSegment: 0,
      );
    }

    final allMoods = <double>[];
    final timeSegmentMoods = <int, List<double>>{
      0: [], // Morning
      1: [], // Midday  
      2: [], // Evening
    };

    // Calculate current streak and other range-specific statistics
    int currentStreak = 0;
    double? bestDayMood;
    DateTime? bestDay;
    double? worstDayMood;
    DateTime? worstDay;

// Process trends in reverse to calculate current streak
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (int i = trends.length - 1; i >= 0; i--) {
      final day = trends[i];
      final dayMoods = day.moods.values.where((mood) => mood != null).cast<double>().toList();

      if (dayMoods.isNotEmpty) {
        // Skip today unless it has mood data
        final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
        if (dayDate.isAtSameMomentAs(todayDate) && dayMoods.isEmpty) {
          continue; // Skip today if no mood logged yet
        }

        // Only count streak if we're starting from a valid day or continuing a streak
        if (i == trends.length - 1 || currentStreak > 0) {
          currentStreak++;
        }

        final dayAverage = dayMoods.reduce((a, b) => a + b) / dayMoods.length;
        allMoods.add(dayAverage);

        // Track best/worst days
        if (bestDayMood == null || dayAverage > bestDayMood) {
          bestDayMood = dayAverage;
          bestDay = day.date;
        }
        if (worstDayMood == null || dayAverage < worstDayMood) {
          worstDayMood = dayAverage;
          worstDay = day.date;
        }

        // Group by time segments
        for (int segment = 0; segment < 3; segment++) {
          if (day.moods[segment] != null) {
            timeSegmentMoods[segment]!.add(day.moods[segment]!);
          }
        }
      } else if (currentStreak > 0) {
        // Only break streak calculation, not the entire loop
        break;
      }
    }

    final overallAverage = allMoods.isNotEmpty ? allMoods.reduce((a, b) => a + b) / allMoods.length : 0.0;

    // Calculate time segment averages
    final timeSegmentAverages = <int, double>{};
    int bestTimeSegment = 0;
    double bestTimeAverage = 0.0;

    for (int segment = 0; segment < 3; segment++) {
      final moods = timeSegmentMoods[segment]!;
      if (moods.isNotEmpty) {
        final average = moods.reduce((a, b) => a + b) / moods.length;
        timeSegmentAverages[segment] = average;
        if (average > bestTimeAverage) {
          bestTimeAverage = average;
          bestTimeSegment = segment;
        }
      }
    }

    // Get total days logged across ALL time (not just this date range)
    final totalDaysLogged = await getTotalDaysLogged();

    return MoodStatistics(
      daysLogged: totalDaysLogged, // THIS IS NOW INDEPENDENT OF DATE RANGE
      currentStreak: currentStreak,
      overallAverage: overallAverage,
      bestDay: bestDay,
      bestDayMood: bestDayMood,
      worstDay: worstDay,
      worstDayMood: worstDayMood,
      timeSegmentAverages: timeSegmentAverages,
      bestTimeSegment: bestTimeSegment,
    );
  }

  /// Get mood data formatted for line chart
  static List<ChartPoint> getChartData(List<DayMoodData> trends, int timeSegment) {
    final points = <ChartPoint>[];

    for (int i = 0; i < trends.length; i++) {
      final day = trends[i];
      final mood = day.moods[timeSegment];
      if (mood != null) {
        points.add(ChartPoint(x: i.toDouble(), y: mood, date: day.date));
      }
    }

    return points;
  }

  /// Get average mood per day for overview chart
  static List<ChartPoint> getDailyAverageChart(List<DayMoodData> trends) {
    final points = <ChartPoint>[];

    for (int i = 0; i < trends.length; i++) {
      final day = trends[i];
      final moods = day.moods.values.where((mood) => mood != null).cast<double>().toList();

      if (moods.isNotEmpty) {
        final average = moods.reduce((a, b) => a + b) / moods.length;
        points.add(ChartPoint(x: i.toDouble(), y: average, date: day.date));
      }
    }

    return points;
  }
}

class DayMoodData {
  final DateTime date;
  final Map<int, double?> moods = {0: null, 1: null, 2: null}; // Morning, Midday, Evening

  DayMoodData({required this.date});

  bool get hasAnyMood => moods.values.any((mood) => mood != null);
}

class MoodStatistics {
  final int daysLogged;
  final int currentStreak;
  final double overallAverage;
  final DateTime? bestDay;
  final double? bestDayMood;
  final DateTime? worstDay;
  final double? worstDayMood;
  final Map<int, double> timeSegmentAverages;
  final int bestTimeSegment;

  MoodStatistics({
    required this.daysLogged,
    required this.currentStreak,
    required this.overallAverage,
    this.bestDay,
    this.bestDayMood,
    this.worstDay,
    this.worstDayMood,
    required this.timeSegmentAverages,
    required this.bestTimeSegment,
  });

  factory MoodStatistics.empty() {
    return MoodStatistics(
      daysLogged: 0,
      currentStreak: 0,
      overallAverage: 0.0,
      timeSegmentAverages: {},
      bestTimeSegment: 0,
    );
  }
}

class ChartPoint {
  final double x;
  final double y;
  final DateTime date;

  ChartPoint({required this.x, required this.y, required this.date});
}