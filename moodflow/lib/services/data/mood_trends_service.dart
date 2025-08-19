// Updated mood_trends_service.dart - Fixed streak calculation
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

  /// NEW: Calculate statistics for a specific date range (affects most stats)
  /// But keeps global stats for days logged and streaks
  static Future<MoodStatistics> calculateStatisticsForDateRange(
      List<DayMoodData> trends,
      DateTime startDate,
      DateTime endDate
      ) async {
    if (trends.isEmpty) {
      // Even if no trends in range, still get total days logged and streaks
      final totalDaysLogged = await getTotalDaysLogged();
      final currentStreak = await _calculateCurrentStreakGlobal();
      return MoodStatistics(
        daysLogged: totalDaysLogged,
        currentStreak: currentStreak,
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

    // Calculate current streak globally, not just in date range
    final currentStreak = await _calculateCurrentStreakGlobal();
    double? bestDayMood;
    DateTime? bestDay;
    double? worstDayMood;
    DateTime? worstDay;

    // Process trends to calculate date-range specific statistics
    for (final day in trends) {
      final dayMoods = day.moods.values.where((mood) => mood != null).cast<double>().toList();

      if (dayMoods.isNotEmpty) {
        final dayAverage = dayMoods.reduce((a, b) => a + b) / dayMoods.length;
        allMoods.add(dayAverage);

        // Track best/worst days within the date range
        if (bestDayMood == null || dayAverage > bestDayMood) {
          bestDayMood = dayAverage;
          bestDay = day.date;
        }
        if (worstDayMood == null || dayAverage < worstDayMood) {
          worstDayMood = dayAverage;
          worstDay = day.date;
        }

        // Group by time segments within the date range
        for (int segment = 0; segment < 3; segment++) {
          if (day.moods[segment] != null) {
            timeSegmentMoods[segment]!.add(day.moods[segment]!);
          }
        }
      }
    }

    final overallAverage = allMoods.isNotEmpty ? allMoods.reduce((a, b) => a + b) / allMoods.length : 0.0;

    // Calculate time segment averages within the date range
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
      daysLogged: totalDaysLogged, // GLOBAL STAT - independent of date range
      currentStreak: currentStreak, // GLOBAL STAT - independent of date range
      overallAverage: overallAverage, // DATE RANGE SPECIFIC
      bestDay: bestDay, // DATE RANGE SPECIFIC
      bestDayMood: bestDayMood, // DATE RANGE SPECIFIC
      worstDay: worstDay, // DATE RANGE SPECIFIC
      worstDayMood: worstDayMood, // DATE RANGE SPECIFIC
      timeSegmentAverages: timeSegmentAverages, // DATE RANGE SPECIFIC
      bestTimeSegment: bestTimeSegment, // DATE RANGE SPECIFIC
    );
  }

  /// Calculate current streak globally with real-time updates
  static Future<int> _calculateCurrentStreakGlobal() async {
    int streak = 0;
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    // Check if user has logged any mood today
    bool hasLoggedToday = false;
    for (int segment = 0; segment < 3; segment++) {
      final mood = await MoodDataService.loadMood(todayDate, segment);
      if (mood != null && mood['rating'] != null) {
        hasLoggedToday = true;
        break;
      }
    }

    // Determine starting date for streak calculation
    DateTime streakStartDate;
    if (hasLoggedToday) {
      // User has logged today, so include today in streak calculation
      streakStartDate = todayDate;
    } else {
      // User hasn't logged today, so start from yesterday
      streakStartDate = todayDate.subtract(const Duration(days: 1));
    }

    // Calculate streak starting from the determined date
    DateTime currentDate = streakStartDate;

    for (int i = 0; i < 365; i++) { // Max 1 year
      bool hasAnyMood = false;

      // Check if this day has any moods
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(currentDate, segment);
        if (mood != null && mood['rating'] != null) {
          hasAnyMood = true;
          break;
        }
      }

      if (hasAnyMood) {
        streak++;
      } else {
        // No mood logged for this day - break the streak
        break;
      }

      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// LEGACY: Calculate statistics from mood trends (for backwards compatibility)
  /// This method is now deprecated in favor of calculateStatisticsForDateRange
  static Future<MoodStatistics> calculateStatistics(List<DayMoodData> trends) async {
    // For backwards compatibility, calculate stats for the entire trends list
    if (trends.isEmpty) {
      final totalDaysLogged = await getTotalDaysLogged();
      final currentStreak = await _calculateCurrentStreakGlobal();
      return MoodStatistics(
        daysLogged: totalDaysLogged,
        currentStreak: currentStreak,
        overallAverage: 0.0,
        timeSegmentAverages: {},
        bestTimeSegment: 0,
      );
    }

    // Use the date range of the trends data
    final startDate = trends.first.date;
    final endDate = trends.last.date;

    return await calculateStatisticsForDateRange(trends, startDate, endDate);
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