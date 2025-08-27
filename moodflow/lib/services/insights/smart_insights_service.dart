// lib/services/insights/smart_insights_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mood_data_service.dart';
import '../data/correlation_data_service.dart';
import '../utils/logger.dart';
import 'pattern_detection_helper.dart';

// Core insight types and priorities
enum InsightType {
  actionable,
  prediction,
  achievement,
  celebration,
  concern,
  pattern,
  suggestion
}

enum AlertPriority {
  critical,
  high,
  medium,
  low
}

// Main SmartInsight class
class SmartInsight {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final AlertPriority priority;
  final DateTime createdAt;
  final double? confidence;
  final List<String>? actionSteps;
  final Map<String, dynamic> data;
  final String? actionText;
  final String? actionRoute;
  final bool isRead;

  SmartInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.confidence,
    this.actionSteps,
    this.data = const {},
    this.actionText,
    this.actionRoute,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'priority': priority.name,
    'createdAt': createdAt.toIso8601String(),
    'confidence': confidence,
    'actionSteps': actionSteps,
    'data': data,
    'actionText': actionText,
    'actionRoute': actionRoute,
    'isRead': isRead,
  };

  factory SmartInsight.fromJson(Map<String, dynamic> json) => SmartInsight(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: InsightType.values.firstWhere((e) => e.name == json['type']),
    priority: AlertPriority.values.firstWhere((e) => e.name == json['priority']),
    createdAt: DateTime.parse(json['createdAt']),
    confidence: json['confidence']?.toDouble(),
    actionSteps: json['actionSteps'] != null ? List<String>.from(json['actionSteps']) : null,
    data: Map<String, dynamic>.from(json['data'] ?? {}),
    actionText: json['actionText'],
    actionRoute: json['actionRoute'],
    isRead: json['isRead'] ?? false,
  );
}

// Weekly summary for reports
class WeeklySummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double averageMood;
  final int daysLogged;
  final int totalDays;
  final double bestDay;
  final String trend;
  final List<String> highlights;
  final List<String> concerns;
  final List<String> recommendations;

  WeeklySummary({
    required this.weekStart,
    required this.weekEnd,
    required this.averageMood,
    required this.daysLogged,
    required this.totalDays,
    required this.bestDay,
    required this.trend,
    required this.highlights,
    required this.concerns,
    required this.recommendations,
  });
}

// Data structure for comprehensive analysis
class ComprehensiveAnalysisData {
  final List<DayAnalysisData> days;
  ComprehensiveAnalysisData({required this.days});
}

class DayAnalysisData {
  final DateTime date;
  final Map<int, double> moods;
  final CorrelationData? correlationData;
  final double averageMood;

  DayAnalysisData({
    required this.date,
    required this.moods,
    this.correlationData,
    required this.averageMood,
  });
}

class WeeklyData {
  final double averageMood;
  final int daysLogged;
  final double bestDay;
  final String trend;

  WeeklyData({
    required this.averageMood,
    required this.daysLogged,
    required this.bestDay,
    required this.trend,
  });
}

// Main service class
class SmartInsightsService {
  static const String _insightsKey = 'enhanced_smart_insights';
  static const String _lastAnalysisKey = 'last_enhanced_analysis_date';
  static const String _userPatternsKey = 'enhanced_user_patterns';

  /// Generate comprehensive insights
  static Future<List<SmartInsight>> generateInsights({bool forceRefresh = false}) async {
    final insights = <SmartInsight>[];

    // Check if we need to run analysis
    if (!forceRefresh && !await _shouldRunAnalysis()) {
      return await loadInsights();
    }

    Logger.smartInsightService('🧠 Generating enhanced smart insights...');

    try {
      // Get comprehensive mood and correlation data
      final analysisData = await _gatherComprehensiveData();

      if (analysisData.days.length < 3) {
        Logger.smartInsightService('⚠️ Not enough data for enhanced insights (${analysisData.days.length} days)');
        return insights;
      }

      // 1. Actionable Pattern Recognition
      insights.addAll(await _generateActionablePatterns(analysisData));

      // 2. Predictive Intelligence
      insights.addAll(await _generatePredictiveInsights(analysisData));

      // 3. Personalized Recommendations Engine
      insights.addAll(await _generatePersonalizedRecommendations(analysisData));

      // 4. Environmental Intelligence
      insights.addAll(await _generateEnvironmentalIntelligence(analysisData));

      // 5. Achievement and Progress Tracking
      insights.addAll(await _generateAchievementInsights(analysisData));

      // Sort by priority and confidence
      insights.sort((a, b) {
        final priorityA = _getPriorityScore(a.priority);
        final priorityB = _getPriorityScore(b.priority);
        if (priorityA != priorityB) return priorityB.compareTo(priorityA);

        final confidenceA = a.confidence ?? 0.0;
        final confidenceB = b.confidence ?? 0.0;
        return confidenceB.compareTo(confidenceA);
      });

      // Save insights and update analysis timestamp
      await _saveInsights(insights.take(15).toList());
      await _updateLastAnalysis();

      Logger.smartInsightService('✅ Generated ${insights.length} enhanced insights');
      return insights.take(15).toList();

    } catch (e) {
      Logger.smartInsightService('❌ Error generating enhanced insights: $e');
      return [];
    }
  }

  /// Generate actionable pattern recognition insights
  static Future<List<SmartInsight>> _generateActionablePatterns(
      ComprehensiveAnalysisData data) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Morning Advantage Detection
    final morningAdvantage = PatternDetectionHelper.detectMorningAdvantage(data);
    if (morningAdvantage != null) {
      insights.add(SmartInsight(
        id: 'morning_advantage_${now.millisecondsSinceEpoch}',
        title: '🌅 Morning Advantage Detected',
        description: 'You score ${morningAdvantage.advantage.toStringAsFixed(1)} points higher in mornings (${morningAdvantage.morningAvg.toStringAsFixed(1)} vs ${morningAdvantage.eveningAvg.toStringAsFixed(1)})',
        type: InsightType.actionable,
        priority: AlertPriority.high,
        createdAt: now,
        confidence: morningAdvantage.confidence,
        actionSteps: [
          'Schedule important tasks before 11 AM',
          'Try 10-minute morning sunlight exposure',
          'Plan challenging conversations for morning hours',
          'Consider meditation or protein-rich breakfast in the morning',
        ],
        data: {
          'morningAverage': morningAdvantage.morningAvg,
          'eveningAverage': morningAdvantage.eveningAvg,
          'advantage': morningAdvantage.advantage,
        },
        actionText: 'Optimize Schedule',
        actionRoute: '/correlation',
      ));
    }

    // Sleep Quality Pattern Analysis
    final sleepPattern = PatternDetectionHelper.analyzeSleepPattern(data);
    if (sleepPattern != null) {
      insights.add(SmartInsight(
        id: 'sleep_pattern_${now.millisecondsSinceEpoch}',
        title: '😴 Sleep Quality Impact',
        description: sleepPattern.description,
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: sleepPattern.confidence,
        actionSteps: sleepPattern.actionSteps,
        data: sleepPattern.data,
        actionText: 'Sleep Better',
      ));
    }

    // Exercise Magic Analysis
    final exercisePattern = PatternDetectionHelper.analyzeExercisePattern(data);
    if (exercisePattern != null) {
      insights.add(SmartInsight(
        id: 'exercise_magic_${now.millisecondsSinceEpoch}',
        title: '💪 Exercise Magic',
        description: exercisePattern.description,
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: exercisePattern.confidence,
        actionSteps: exercisePattern.actionSteps,
        data: exercisePattern.data,
        actionText: 'Get Moving',
      ));
    }

    return insights;
  }

  /// Generate predictive intelligence insights
  static Future<List<SmartInsight>> _generatePredictiveInsights(
      ComprehensiveAnalysisData data) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Tomorrow's Forecast
    final tomorrowForecast = PatternDetectionHelper.predictTomorrowMood(data);
    if (tomorrowForecast != null) {
      insights.add(SmartInsight(
        id: 'tomorrow_forecast_${now.millisecondsSinceEpoch}',
        title: '🔮 Tomorrow\'s Forecast',
        description: tomorrowForecast.prediction,
        type: InsightType.prediction,
        priority: tomorrowForecast.confidence > 0.7
            ? AlertPriority.high
            : AlertPriority.medium,
        createdAt: now,
        confidence: tomorrowForecast.confidence,
        actionSteps: tomorrowForecast.actionSteps,
        data: {
          'predictedMood': tomorrowForecast.predictedMood,
          'reasoning': tomorrowForecast.reasoning,
        },
        actionText: 'Prepare Day',
      ));
    }

    // Weekly Pattern Forecast
    final weeklyPattern = PatternDetectionHelper.analyzeWeeklyPattern(data);
    if (weeklyPattern != null) {
      insights.add(SmartInsight(
        id: 'weekly_pattern_${now.millisecondsSinceEpoch}',
        title: '📊 Weekly Pattern Insight',
        description: weeklyPattern.description,
        type: InsightType.pattern,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: weeklyPattern.confidence,
        actionSteps: weeklyPattern.actionSteps,
        data: weeklyPattern.data,
        actionText: 'Plan Week',
      ));
    }

    // Early Warning Detection
    final earlyWarning = PatternDetectionHelper.detectEarlyWarnings(data);
    if (earlyWarning != null) {
      insights.add(SmartInsight(
        id: 'early_warning_${now.millisecondsSinceEpoch}',
        title: '⚠️ Early Warning',
        description: earlyWarning.description,
        type: InsightType.concern,
        priority: AlertPriority.critical,
        createdAt: now,
        confidence: earlyWarning.confidence,
        actionSteps: earlyWarning.actionSteps,
        data: earlyWarning.data,
        actionText: 'Take Action',
      ));
    }

    return insights;
  }

  /// Generate personalized recommendations
  static Future<List<SmartInsight>> _generatePersonalizedRecommendations(
      ComprehensiveAnalysisData data) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Custom Mood Hacks
    final moodHacks = PatternDetectionHelper.generateCustomMoodHacks(data);
    for (final hack in moodHacks.take(2)) {
      insights.add(SmartInsight(
        id: 'mood_hack_${hack.type}_${now.millisecondsSinceEpoch}',
        title: '💡 ${hack.title}',
        description: hack.description,
        type: InsightType.suggestion,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: hack.confidence,
        actionSteps: hack.actionSteps,
        data: hack.data,
        actionText: 'Try This',
      ));
    }

    return insights;
  }

  /// Generate environmental intelligence insights
  static Future<List<SmartInsight>> _generateEnvironmentalIntelligence(
      ComprehensiveAnalysisData data) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Weather Impact Analysis
    final weatherImpact = PatternDetectionHelper.analyzeWeatherImpact(data);
    if (weatherImpact != null) {
      insights.add(SmartInsight(
        id: 'weather_impact_${now.millisecondsSinceEpoch}',
        title: '🌦️ Weather Warrior',
        description: weatherImpact.description,
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: weatherImpact.confidence,
        actionSteps: weatherImpact.actionSteps,
        data: weatherImpact.data,
        actionText: 'Weather Prep',
      ));
    }

    return insights;
  }

  /// Generate achievement insights
  static Future<List<SmartInsight>> _generateAchievementInsights(
      ComprehensiveAnalysisData data) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Streak celebration
    final currentStreak = await PatternDetectionHelper.calculateCurrentStreak(data);
    if (currentStreak >= 7) {
      insights.add(SmartInsight(
        id: 'streak_celebration_${now.millisecondsSinceEpoch}',
        title: '🎉 Amazing Streak!',
        description: 'You\'ve logged your mood for $currentStreak days in a row! Keep up the great work.',
        type: InsightType.celebration,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: 1.0,
        actionSteps: [
          'Celebrate this achievement - you\'re building a great habit!',
          'Keep the momentum going for even better insights',
          'Share your progress with someone who supports your journey',
        ],
        data: {'streak': currentStreak},
        actionText: 'Keep Going!',
      ));
    }

    // Progress insight
    final progressInsight = PatternDetectionHelper.analyzeProgress(data);
    if (progressInsight != null) {
      insights.add(SmartInsight(
        id: 'progress_insight_${now.millisecondsSinceEpoch}',
        title: '📈 Progress Update',
        description: progressInsight.description,
        type: InsightType.achievement,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: progressInsight.confidence,
        actionSteps: progressInsight.actionSteps,
        data: progressInsight.data,
        actionText: 'View Progress',
      ));
    }

    return insights;
  }

  /// Generate weekly summary
  static Future<WeeklySummary> generateWeeklySummary() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final data = await _gatherWeeklyData(weekStart, weekEnd);

    final highlights = <String>[];
    final concerns = <String>[];
    final recommendations = <String>[];

    if (data.averageMood > 7.0) {
      highlights.add('Great week overall with ${data.averageMood.toStringAsFixed(1)} average mood');
    }

    if (data.daysLogged >= 5) {
      highlights.add('Excellent consistency - ${data.daysLogged} days logged this week');
    } else {
      concerns.add('Only ${data.daysLogged} days logged - try for more consistency');
      recommendations.add('Set a daily reminder to log your mood');
    }

    if (data.averageMood < 6.0) {
      concerns.add('Lower than usual mood this week');
      recommendations.add('Focus on self-care activities that usually boost your mood');
    }

    return WeeklySummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      averageMood: data.averageMood,
      daysLogged: data.daysLogged,
      totalDays: 7,
      bestDay: data.bestDay,
      trend: data.trend,
      highlights: highlights,
      concerns: concerns,
      recommendations: recommendations,
    );
  }

  // Helper methods and data gathering
  static Future<ComprehensiveAnalysisData> _gatherComprehensiveData() async {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));
    final days = <DayAnalysisData>[];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(now) || currentDate.isAtSameMomentAs(now)) {
      final dayMoods = <int, double>{};

      // Get mood data for all segments
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(currentDate, segment);
        if (mood != null && mood['rating'] != null) {
          dayMoods[segment] = (mood['rating'] as num).toDouble();
        }
      }

      // Get correlation data
      final correlationData = await CorrelationDataService.loadCorrelationData(currentDate);

      if (dayMoods.isNotEmpty || correlationData != null) {
        final averageMood = dayMoods.isNotEmpty
            ? dayMoods.values.reduce((a, b) => a + b) / dayMoods.length
            : 0.0;

        days.add(DayAnalysisData(
          date: currentDate,
          moods: dayMoods,
          correlationData: correlationData,
          averageMood: averageMood,
        ));
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return ComprehensiveAnalysisData(days: days);
  }

  static Future<WeeklyData> _gatherWeeklyData(DateTime start, DateTime end) async {
    double totalMood = 0;
    int moodCount = 0;
    int daysLogged = 0;
    double bestDay = 0;

    DateTime currentDate = start;
    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      bool hasAnyMood = false;
      double dayTotal = 0;
      int dayCount = 0;

      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(currentDate, segment);
        if (mood != null && mood['rating'] != null) {
          final rating = (mood['rating'] as num).toDouble();
          dayTotal += rating;
          dayCount++;
          hasAnyMood = true;
        }
      }

      if (hasAnyMood) {
        daysLogged++;
        final dayAvg = dayTotal / dayCount;
        totalMood += dayAvg;
        moodCount++;
        if (dayAvg > bestDay) bestDay = dayAvg;
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return WeeklyData(
      averageMood: moodCount > 0 ? totalMood / moodCount : 0.0,
      daysLogged: daysLogged,
      bestDay: bestDay,
      trend: 'stable', // Simplified for now
    );
  }

  // Utility methods
  static int _getPriorityScore(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.critical: return 4;
      case AlertPriority.high: return 3;
      case AlertPriority.medium: return 2;
      case AlertPriority.low: return 1;
    }
  }

  // Storage methods
  static Future<bool> _shouldRunAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAnalysis = prefs.getString(_lastAnalysisKey);

    if (lastAnalysis == null) return true;

    final lastDate = DateTime.parse(lastAnalysis);
    final today = DateTime.now();

    return !_isSameDay(lastDate, today);
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static Future<void> _saveInsights(List<SmartInsight> insights) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = insights.map((insight) => insight.toJson()).toList();
    await prefs.setString(_insightsKey, jsonEncode(jsonData));
  }

  static Future<List<SmartInsight>> loadInsights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_insightsKey);

      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((json) => SmartInsight.fromJson(json)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      Logger.smartInsightService('Error loading insights: $e');
      return [];
    }
  }

  static Future<void> _updateLastAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAnalysisKey, DateTime.now().toIso8601String());
  }
}