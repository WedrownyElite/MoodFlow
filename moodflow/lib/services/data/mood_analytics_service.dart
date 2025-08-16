import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mood_data_service.dart';

class MoodAnalyticsService {
  static const String _correlationsKey = 'mood_correlations';
  static const String _goalsKey = 'mood_goals';

  /// Save correlation data (weather, sleep, exercise, etc.)
  static Future<void> saveCorrelationData(DateTime date, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'correlation_${date.toIso8601String().substring(0, 10)}';
    await prefs.setString(key, jsonEncode(data));
  }

  /// Load correlation data for a specific date
  static Future<Map<String, dynamic>?> loadCorrelationData(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'correlation_${date.toIso8601String().substring(0, 10)}';
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Generate mood predictions based on historical data
  static Future<MoodPredictions> generatePredictions() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 90)); // 3 months of data
    
    final dayOfWeekMoods = <int, List<double>>{};
    final timeOfDayMoods = <int, List<double>>{};
    final weatherMoods = <String, List<double>>{};
    
    // Collect historical data
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate)) {
      final dayOfWeek = currentDate.weekday;
      
      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        final correlationData = await loadCorrelationData(currentDate);
        
        if (moodData != null && moodData['rating'] != null) {
          final mood = (moodData['rating'] as num).toDouble();
          
          // Day of week patterns
          dayOfWeekMoods.putIfAbsent(dayOfWeek, () => []).add(mood);
          
          // Time of day patterns
          timeOfDayMoods.putIfAbsent(segment, () => []).add(mood);
          
          // Weather patterns
          if (correlationData != null && correlationData['weather'] != null) {
            final weather = correlationData['weather'] as String;
            weatherMoods.putIfAbsent(weather, () => []).add(mood);
          }
        }
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return MoodPredictions(
      dayOfWeekAverages: _calculateAverages(dayOfWeekMoods),
      timeOfDayAverages: _calculateAverages(timeOfDayMoods),
      weatherAverages: _calculateWeatherAverages(weatherMoods),
      bestDayOfWeek: _findBestKey(dayOfWeekMoods),
      bestTimeOfDay: _findBestKey(timeOfDayMoods),
      bestWeather: _findBestWeatherKey(weatherMoods),
    );
  }

  /// Generate weekly/monthly reports
  static Future<MoodReport> generateReport(DateTime startDate, DateTime endDate) async {
    final moodEntries = <MoodReportEntry>[];
    double totalMood = 0;
    int moodCount = 0;
    final segmentTotals = <int, double>{0: 0, 1: 0, 2: 0};
    final segmentCounts = <int, int>{0: 0, 1: 0, 2: 0};
    
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dayMoods = <int, double>{};
      final correlationData = await loadCorrelationData(currentDate);
      
      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        if (moodData != null && moodData['rating'] != null) {
          final mood = (moodData['rating'] as num).toDouble();
          dayMoods[segment] = mood;
          
          totalMood += mood;
          moodCount++;
          
          segmentTotals[segment] = (segmentTotals[segment] ?? 0) + mood;
          segmentCounts[segment] = (segmentCounts[segment] ?? 0) + 1;
        }
      }
      
      if (dayMoods.isNotEmpty) {
        moodEntries.add(MoodReportEntry(
          date: currentDate,
          moods: dayMoods,
          correlationData: correlationData,
        ));
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    final segmentAverages = <int, double>{};
    for (int segment = 0; segment < 3; segment++) {
      if (segmentCounts[segment]! > 0) {
        segmentAverages[segment] = segmentTotals[segment]! / segmentCounts[segment]!;
      }
    }
    
    return MoodReport(
      startDate: startDate,
      endDate: endDate,
      entries: moodEntries,
      overallAverage: moodCount > 0 ? totalMood / moodCount : 0,
      segmentAverages: segmentAverages,
      totalDaysLogged: moodEntries.length,
      insights: _generateInsights(moodEntries, segmentAverages),
    );
  }

  /// Save and load goals
  static Future<void> saveGoals(List<MoodGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = goals.map((goal) => goal.toJson()).toList();
    await prefs.setString(_goalsKey, jsonEncode(goalsJson));
  }

  static Future<List<MoodGoal>> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = prefs.getString(_goalsKey);
    if (goalsJson == null) return [];
    
    try {
      final List<dynamic> goalsList = jsonDecode(goalsJson);
      return goalsList.map((json) => MoodGoal.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Helper methods
  static Map<K, double> _calculateAverages<K>(Map<K, List<double>> data) {
    final averages = <K, double>{};
    data.forEach((key, values) {
      if (values.isNotEmpty) {
        averages[key] = values.reduce((a, b) => a + b) / values.length;
      }
    });
    return averages;
  }

  static Map<String, double> _calculateWeatherAverages(Map<String, List<double>> data) {
    final averages = <String, double>{};
    data.forEach((key, values) {
      if (values.isNotEmpty) {
        averages[key] = values.reduce((a, b) => a + b) / values.length;
      }
    });
    return averages;
  }

  static K? _findBestKey<K>(Map<K, List<double>> data) {
    K? bestKey;
    double bestAverage = 0;
    
    data.forEach((key, values) {
      if (values.isNotEmpty) {
        final average = values.reduce((a, b) => a + b) / values.length;
        if (average > bestAverage) {
          bestAverage = average;
          bestKey = key;
        }
      }
    });
    
    return bestKey;
  }

  static String? _findBestWeatherKey(Map<String, List<double>> data) {
    String? bestKey;
    double bestAverage = 0;
    
    data.forEach((key, values) {
      if (values.isNotEmpty) {
        final average = values.reduce((a, b) => a + b) / values.length;
        if (average > bestAverage) {
          bestAverage = average;
          bestKey = key;
        }
      }
    });
    
    return bestKey;
  }

  static List<String> _generateInsights(List<MoodReportEntry> entries, Map<int, double> segmentAverages) {
    final insights = <String>[];
    
    // Time of day insights
    final segments = ['morning', 'midday', 'evening'];
    if (segmentAverages.isNotEmpty) {
      final bestSegment = segmentAverages.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add("You tend to feel best in the ${segments[bestSegment.key]} (${bestSegment.value.toStringAsFixed(1)}/10)");
    }
    
    // Trend insights
    if (entries.length >= 7) {
      final recentEntries = entries.take(7).toList();
      final olderEntries = entries.skip(entries.length - 7).toList();
      
      final recentAvg = _calculateDayAverages(recentEntries);
      final olderAvg = _calculateDayAverages(olderEntries);
      
      if (recentAvg > olderAvg + 0.5) {
        insights.add("Your mood has been improving recently! Keep it up! 📈");
      } else if (recentAvg < olderAvg - 0.5) {
        insights.add("Your mood has been lower lately. Consider self-care activities 💙");
      }
    }
    
    return insights;
  }

  static double _calculateDayAverages(List<MoodReportEntry> entries) {
    double total = 0;
    int count = 0;
    
    for (final entry in entries) {
      for (final mood in entry.moods.values) {
        total += mood;
        count++;
      }
    }
    
    return count > 0 ? total / count : 0;
  }
}

class MoodPredictions {
  final Map<int, double> dayOfWeekAverages; // 1-7 (Monday-Sunday)
  final Map<int, double> timeOfDayAverages; // 0-2 (Morning, Midday, Evening)
  final Map<String, double> weatherAverages;
  final int? bestDayOfWeek;
  final int? bestTimeOfDay;
  final String? bestWeather;

  MoodPredictions({
    required this.dayOfWeekAverages,
    required this.timeOfDayAverages,
    required this.weatherAverages,
    this.bestDayOfWeek,
    this.bestTimeOfDay,
    this.bestWeather,
  });
}

class MoodReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<MoodReportEntry> entries;
  final double overallAverage;
  final Map<int, double> segmentAverages;
  final int totalDaysLogged;
  final List<String> insights;

  MoodReport({
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.overallAverage,
    required this.segmentAverages,
    required this.totalDaysLogged,
    required this.insights,
  });
}

class MoodReportEntry {
  final DateTime date;
  final Map<int, double> moods;
  final Map<String, dynamic>? correlationData;

  MoodReportEntry({
    required this.date,
    required this.moods,
    this.correlationData,
  });
}

class MoodGoal {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final double targetValue;
  final int targetDays;
  final DateTime createdDate;
  final DateTime? completedDate;
  final bool isCompleted;

  MoodGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.targetDays,
    required this.createdDate,
    this.completedDate,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString(),
      'targetValue': targetValue,
      'targetDays': targetDays,
      'createdDate': createdDate.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  static MoodGoal fromJson(Map<String, dynamic> json) {
    return MoodGoal(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: GoalType.values.firstWhere((e) => e.toString() == json['type']),
      targetValue: json['targetValue'],
      targetDays: json['targetDays'],
      createdDate: DateTime.parse(json['createdDate']),
      completedDate: json['completedDate'] != null ? DateTime.parse(json['completedDate']) : null,
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

enum GoalType {
  averageMood,    // "Maintain 7+ average mood"
  consecutiveDays, // "Log mood 7 days in a row"
  minimumMood,    // "Have no days below 5"
  improvementStreak, // "Improve mood 3 days in a row"
}