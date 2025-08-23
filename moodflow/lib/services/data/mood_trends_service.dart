// Updated mood_trends_service.dart - Fixed streak calculation
import 'dart:convert';
import '../data/mood_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodTrendsService {
  /// Get mood data for a date range - OPTIMIZED VERSION
  static Future<List<DayMoodData>> getMoodTrends({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final trends = <DayMoodData>[];

    // Hard limit to prevent excessive loading
    final daysDiff = endDate.difference(startDate).inDays;
    if (daysDiff > 365) {
      endDate = startDate.add(const Duration(days: 365));
    }

    // Pre-load all SharedPreferences keys at once
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().where((key) => key.startsWith('mood_')).toSet();

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dayData = DayMoodData(date: currentDate);

      // Check all segments for this day using pre-loaded keys
      for (int i = 0; i < 3; i++) {
        final key = MoodDataService.getKeyForDateSegment(currentDate, i);
        if (allKeys.contains(key)) {
          final jsonString = prefs.getString(key);
          if (jsonString != null) {
            try {
              final data = jsonDecode(jsonString) as Map<String, dynamic>;
              if (data['rating'] != null) {
                dayData.moods[i] = (data['rating'] as num).toDouble();
              }
            } catch (e) {
              // Skip invalid data
            }
          }
        }
      }

      trends.add(dayData);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return trends;
  }

  /// Process a batch of days efficiently
  static Future<List<DayMoodData>> _processDayBatch(DateTime startDate, DateTime endDate) async {
    final batch = <DayMoodData>[];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dayData = DayMoodData(date: currentDate);

      // Check all segments for this day
      for (int i = 0; i < 3; i++) {
        final moodData = await MoodDataService.loadMoodCached(currentDate, i);
        if (moodData != null && moodData['rating'] != null) {
          dayData.moods[i] = (moodData['rating'] as num).toDouble();
        }
      }

      batch.add(dayData);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return batch;
  }

// Cache for expensive calculations
  static final Map<String, int> _totalDaysCache = {};
  static DateTime? _lastTotalDaysCacheTime;

  /// Get total days logged with caching
  static Future<int> getTotalDaysLogged() async {
    final prefs = await SharedPreferences.getInstance();
    final moodKeys = prefs.getKeys().where((key) => key.startsWith('mood_')).toList();

    // Extract unique dates from keys (format: mood_YYYY-MM-DD_segment)
    final uniqueDates = <String>{};
    for (final key in moodKeys) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        uniqueDates.add(parts[1]); // The date part
      }
    }

    return uniqueDates.length;
  }

  /// Calculate statistics for a specific date range (affects most stats)
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
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().where((key) => key.startsWith('mood_')).toSet();

    int streak = 0;
    final today = DateTime.now();
    DateTime currentDate = DateTime(today.year, today.month, today.day);

    // Check up to 365 days back maximum
    for (int i = 0; i < 365; i++) {
      bool hasAnyMood = false;

      // Check if any segment has data for this day
      for (int segment = 0; segment < 3; segment++) {
        final key = MoodDataService.getKeyForDateSegment(currentDate, segment);
        if (allKeys.contains(key)) {
          final jsonString = prefs.getString(key);
          if (jsonString != null) {
            try {
              final data = jsonDecode(jsonString) as Map<String, dynamic>;
              if (data['rating'] != null) {
                hasAnyMood = true;
                break;
              }
            } catch (e) {
              // Skip invalid data
            }
          }
        }
      }

      if (hasAnyMood) {
        streak++;
      } else {
        break; // Streak broken
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