import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mood_data_service.dart';
import '../data/correlation_data_service.dart';
import '../notifications/real_notification_service.dart';
import '../utils/logger.dart';

enum InsightType {
  pattern,
  achievement,
  concern,
  suggestion,
  celebration,
  prediction, // New: Predictive insights
  actionable, // New: Actionable recommendations
}

enum AlertPriority {
  low,
  medium,
  high,
  critical,
}

class SmartInsight {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final AlertPriority priority;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final bool isRead;
  final String? actionText;
  final String? actionRoute;
  final List<String>? actionSteps; // New: Specific action steps
  final double? confidence; // New: Confidence level (0-1)

  SmartInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.data = const {},
    this.isRead = false,
    this.actionText,
    this.actionRoute,
    this.actionSteps,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'priority': priority.name,
        'createdAt': createdAt.toIso8601String(),
        'data': data,
        'isRead': isRead,
        'actionText': actionText,
        'actionRoute': actionRoute,
        'actionSteps': actionSteps,
        'confidence': confidence,
      };

  factory SmartInsight.fromJson(Map<String, dynamic> json) => SmartInsight(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: InsightType.values.firstWhere((e) => e.name == json['type']),
    priority:
    AlertPriority.values.firstWhere((e) => e.name == json['priority']),
    createdAt: DateTime.parse(json['createdAt']),
    data: json['data'] ?? {},
    isRead: json['isRead'] ?? false,
    actionText: json['actionText'],
    actionRoute: json['actionRoute'],
    actionSteps: json['actionSteps'] != null
        ? List<String>.from(json['actionSteps'])
        : null,
    confidence: json['confidence']?.toDouble(),
  );

  SmartInsight markAsRead() => SmartInsight(
    id: id,
    title: title,
    description: description,
    type: type,
    priority: priority,
    createdAt: createdAt,
    data: data,
    isRead: true,
    actionText: actionText,
    actionRoute: actionRoute,
    actionSteps: actionSteps,
    confidence: confidence,
  );
}

class WeeklySummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double averageMood;
  final int daysLogged;
  final int totalDays;
  final double bestDay;
  final double worstDay;
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
    required this.worstDay,
    required this.trend,
    required this.highlights,
    required this.concerns,
    required this.recommendations,
  });
}

class PredictiveInsight {
  final String prediction;
  final double confidence;
  final String reasoning;
  final List<String> preventativeActions;

  PredictiveInsight({
    required this.prediction,
    required this.confidence,
    required this.reasoning,
    required this.preventativeActions,
  });
}

class MonthlySummary {
  final DateTime monthStart;
  final DateTime monthEnd;
  final double averageMood;
  final int daysLogged;
  final int totalDays;
  final int streakDays;
  final Map<String, double> timeOfDayAverages;
  final String bestWeek;
  final String worstWeek;
  final List<String> achievements;
  final List<String> insights;
  final List<String> goalsForNextMonth;

  MonthlySummary({
    required this.monthStart,
    required this.monthEnd,
    required this.averageMood,
    required this.daysLogged,
    required this.totalDays,
    required this.streakDays,
    required this.timeOfDayAverages,
    required this.bestWeek,
    required this.worstWeek,
    required this.achievements,
    required this.insights,
    required this.goalsForNextMonth,
  });
}

class SmartInsightsService {
  static const String _insightsKey = 'smart_insights';
  static const String _settingsKey = 'insights_settings';
  static const String _lastAnalysisKey = 'last_analysis_date';
  static const String _userPatternsKey = 'user_patterns';

  /// Generate all types of enhanced insights
  static Future<List<SmartInsight>> generateInsights(
      {bool forceRefresh = false}) async {
    final insights = <SmartInsight>[];

    // Check if we need to run analysis (once per day)
    if (!forceRefresh && !await _shouldRunAnalysis()) {
      return await loadInsights();
    }

    Logger.analyticsService('🧠 Generating enhanced smart insights...');

    // Enhanced pattern analysis with actionable insights
    insights.addAll(await _analyzeActionablePatterns());

    // Achievement detection with progress tracking
    insights.addAll(await _detectAchievementsWithProgress());

    // Concern monitoring with early warning
    insights.addAll(await _detectEarlyWarnings());

    // Celebration moments with context
    insights.addAll(await _detectContextualCelebrations());

    // NEW: Predictive insights
    insights.addAll(await _generatePredictiveInsights());

    // NEW: Personalized actionable suggestions
    insights.addAll(await _generateActionableSuggestions());

    // NEW: Context-aware recommendations
    insights.addAll(await _generateContextAwareSuggestions());

    // Save insights and update analysis timestamp
    await _saveInsights(insights);
    await _updateLastAnalysis();

    Logger.analyticsService('✅ Generated ${insights.length} enhanced insights');
    return insights;
  }

  /// NEW: Generate predictive insights for tomorrow/this week
  static Future<List<SmartInsight>> _generatePredictiveInsights() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Analyze historical patterns to predict tomorrow
    final tomorrowPrediction = await _predictTomorrowMood();
    if (tomorrowPrediction != null) {
      insights.add(SmartInsight(
        id: 'prediction_tomorrow_${now.millisecondsSinceEpoch}',
        title: '🔮 Tomorrow\'s Forecast',
        description: tomorrowPrediction.prediction,
        type: InsightType.prediction,
        priority: tomorrowPrediction.confidence > 0.7 ? AlertPriority.high : AlertPriority.medium,
        createdAt: now,
        confidence: tomorrowPrediction.confidence,
        actionSteps: tomorrowPrediction.preventativeActions,
        data: {'reasoning': tomorrowPrediction.reasoning},
        actionText: 'View Action Plan',
      ));
    }

    // Predict upcoming challenges
    final upcomingChallenges = await _predictUpcomingChallenges();
    insights.addAll(upcomingChallenges);

    return insights;
  }

  /// NEW: Generate actionable suggestions based on user's specific data
  static Future<List<SmartInsight>> _generateActionableSuggestions() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Analyze last 30 days for personalized recommendations
    final last30Days = await _getLast30DaysMoodData();
    if (last30Days.length < 10) return insights;

    // Find user's optimal conditions
    final optimalConditions = await _findOptimalConditions(last30Days);

    for (final condition in optimalConditions) {
      insights.add(SmartInsight(
        id: 'optimal_${condition['type']}_${now.millisecondsSinceEpoch}',
        title: '⭐ Your ${condition['type']} Sweet Spot',
        description: condition['description'],
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        actionSteps: condition['actionSteps'],
        confidence: condition['confidence'],
        data: condition['data'],
        actionText: 'Try This Week',
      ));
    }

    // Generate specific mood boosters
    final moodBoosters = await _generatePersonalizedMoodBoosters(last30Days);
    insights.addAll(moodBoosters);

    return insights;
  }

  /// NEW: Enhanced pattern analysis with specific actions
  static Future<List<SmartInsight>> _analyzeActionablePatterns() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final moodData = await _getMoodDataWithCorrelations(thirtyDaysAgo, now);
    if (moodData.length < 7) return insights;

    // Time-of-day patterns with specific actions
    insights.addAll(await _analyzeTimeOfDayPatternsEnhanced(moodData));

    // Weekly patterns with optimization suggestions
    insights.addAll(await _analyzeWeeklyPatternsEnhanced(moodData));

    // Environmental correlations with actionable advice
    insights.addAll(await _analyzeEnvironmentalCorrelations(moodData));

    // Trigger identification with avoidance strategies
    insights.addAll(await _identifyTriggersWithStrategies(moodData));

    return insights;
  }
  
  /// Analyze user patterns over time
  static Future<List<SmartInsight>> _analyzePatterns() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Collect mood data for pattern analysis
    final moodData = <DateTime, Map<int, double>>{};
    DateTime currentDate = thirtyDaysAgo;

    while (currentDate.isBefore(now) || currentDate.isAtSameMomentAs(now)) {
      final dayMoods = <int, double>{};
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(currentDate, segment);
        if (mood != null && mood['rating'] != null) {
          dayMoods[segment] = (mood['rating'] as num).toDouble();
        }
      }
      if (dayMoods.isNotEmpty) {
        moodData[currentDate] = dayMoods;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    if (moodData.length < 7) return insights;

    // Time-of-day patterns
    insights.addAll(await _analyzeTimeOfDayPatterns(moodData));

    // Weekly patterns
    insights.addAll(await _analyzeWeeklyPatterns(moodData));

    // Trend analysis
    insights.addAll(await _analyzeTrends(moodData));

    return insights;
  }

  /// Enhanced time-of-day analysis with specific optimization
  static Future<List<SmartInsight>> _analyzeTimeOfDayPatternsEnhanced(
      List<EnhancedDayData> moodData,
      ) async {
    final insights = <SmartInsight>[];
    final timeSegmentTotals = <int, List<double>>{0: [], 1: [], 2: []};
    final now = DateTime.now();

    // Collect all mood ratings by time segment
    for (final dayData in moodData) {
      for (final entry in dayData.moods.entries) {
        timeSegmentTotals[entry.key]!.add(entry.value);
      }
    }

    // Calculate averages and find patterns
    final averages = <int, double>{};
    timeSegmentTotals.forEach((segment, moods) {
      if (moods.isNotEmpty) {
        averages[segment] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (averages.length >= 2) {
      final sortedTimes = averages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final best = sortedTimes.first;
      final worst = sortedTimes.last;
      final difference = best.value - worst.value;

      if (difference >= 1.5) {
        final timeNames = ['morning', 'midday', 'evening'];
        final bestTime = timeNames[best.key];
        final worstTime = timeNames[worst.key];

        // Generate specific action steps
        final actionSteps = _generateTimeOptimizationSteps(best.key, worst.key);

        insights.add(SmartInsight(
          id: 'time_pattern_enhanced_${now.millisecondsSinceEpoch}',
          title: '🌅 Optimize Your ${bestTime.capitalize()} Power',
          description: 'You consistently feel ${difference.toStringAsFixed(1)} points better in the $bestTime (${best.value.toStringAsFixed(1)}/10) vs $worstTime (${worst.value.toStringAsFixed(1)}/10).',
          type: InsightType.actionable,
          priority: AlertPriority.high,
          createdAt: now,
          actionSteps: actionSteps,
          confidence: min(difference / 3.0, 1.0), // Higher difference = higher confidence
          data: {
            'bestTime': best.key,
            'worstTime': worst.key,
            'difference': difference,
            'bestAverage': best.value,
            'worstAverage': worst.value,
          },
          actionText: 'Optimize Schedule',
          actionRoute: '/correlation',
        ));
      }
    }

    return insights;
  }

  /// Generate specific steps for time optimization
  static List<String> _generateTimeOptimizationSteps(int bestTime, int worstTime) {
    final steps = <String>[];

    if (bestTime == 0) { // Morning is best
      steps.addAll([
        'Schedule your most important tasks before 11 AM',
        'Plan challenging conversations for morning hours',
        'Try 10 minutes of morning sunlight exposure',
        'Eat protein within 1 hour of waking',
      ]);
    } else if (bestTime == 1) { // Midday is best
      steps.addAll([
        'Block 1-2 PM for your most demanding work',
        'Use lunch break for energizing activities',
        'Schedule important calls between 12-3 PM',
      ]);
    } else { // Evening is best
      steps.addAll([
        'Save creative tasks for after 5 PM',
        'Plan social activities for evening hours',
        'Use morning for routine/administrative tasks',
      ]);
    }

    // Add protection for worst time
    if (worstTime == 0) {
      steps.add('Avoid scheduling stressful activities before 10 AM');
    } else if (worstTime == 1) {
      steps.add('Build in buffer time around midday for energy dips');
    } else {
      steps.add('Wind down routine starting 2 hours before bed');
    }

    return steps;
  }

  /// NEW: Enhanced weekly patterns with optimization suggestions
  static Future<List<SmartInsight>> _analyzeWeeklyPatternsEnhanced(
      List<EnhancedDayData> moodData,
      ) async {
    final insights = <SmartInsight>[];
    final weekdayMoods = <int, List<double>>{};
    final now = DateTime.now();

    // Group by weekday (1=Monday, 7=Sunday)
    for (final dayData in moodData) {
      final weekday = dayData.date.weekday;
      final dayAverage = dayData.moods.values.reduce((a, b) => a + b) / dayData.moods.length;
      weekdayMoods.putIfAbsent(weekday, () => []).add(dayAverage);
    }

    // Calculate weekday averages
    final weekdayAverages = <int, double>{};
    weekdayMoods.forEach((weekday, moods) {
      if (moods.length >= 2) {
        weekdayAverages[weekday] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (weekdayAverages.length >= 5) {
      // Need most days of week
      final sortedDays = weekdayAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestDay = sortedDays.first;
      final worstDay = sortedDays.last;
      final difference = bestDay.value - worstDay.value;

      if (difference >= 1.2) {
        final dayNames = [
          '',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];

        final actionSteps = _generateWeeklyOptimizationSteps(bestDay.key, worstDay.key);

        insights.add(SmartInsight(
          id: 'weekday_pattern_${now.millisecondsSinceEpoch}',
          title: '📅 ${dayNames[bestDay.key]}s Are Your Power Days',
          description: 'Your mood averages ${bestDay.value.toStringAsFixed(1)} on ${dayNames[bestDay.key]}s vs ${worstDay.value.toStringAsFixed(1)} on ${dayNames[worstDay.key]}s. Let\'s optimize your week!',
          type: InsightType.actionable,
          priority: AlertPriority.medium,
          createdAt: now,
          actionSteps: actionSteps,
          confidence: min(difference / 2.0, 1.0),
          data: {
            'bestDay': bestDay.key,
            'worstDay': worstDay.key,
            'difference': difference,
          },
          actionText: 'Optimize Week',
        ));
      }
    }

    return insights;
  }

  /// Generate weekly optimization steps
  static List<String> _generateWeeklyOptimizationSteps(int bestDay, int worstDay) {
    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final bestDayName = dayNames[bestDay];
    final worstDayName = dayNames[worstDay];

    return [
      'Schedule your biggest challenges and opportunities on ${bestDayName}s',
      'Plan something to look forward to every $worstDayName',
      'Use ${bestDayName}s for important decisions and conversations',
      'Build in extra self-care on ${worstDayName}s',
      'Consider lighter workloads on $worstDayName when possible',
    ];
  }

  /// NEW: Analyze environmental correlations
  static Future<List<SmartInsight>> _analyzeEnvironmentalCorrelations(
      List<EnhancedDayData> moodData,
      ) async {
    final insights = <SmartInsight>[];
    final weatherMoodMap = <WeatherCondition, List<double>>{};
    final now = DateTime.now();

    // Collect weather-mood correlations
    for (final dayData in moodData) {
      if (dayData.correlationData?.weather != null) {
        final avgMood = dayData.moods.values.reduce((a, b) => a + b) / dayData.moods.length;
        weatherMoodMap.putIfAbsent(dayData.correlationData!.weather!, () => []).add(avgMood);
      }
    }

    if (weatherMoodMap.length >= 2) {
      // Find most problematic weather
      final weatherAverages = <WeatherCondition, double>{};
      weatherMoodMap.forEach((weather, moods) {
        if (moods.length >= 3) {
          weatherAverages[weather] = moods.reduce((a, b) => a + b) / moods.length;
        }
      });

      if (weatherAverages.isNotEmpty) {
        final sortedWeather = weatherAverages.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        final worstWeather = sortedWeather.first;
        final bestWeather = sortedWeather.last;

        if (bestWeather.value - worstWeather.value >= 1.0) {
          final actionSteps = _generateWeatherActionSteps(worstWeather.key);

          insights.add(SmartInsight(
            id: 'weather_correlation_${now.millisecondsSinceEpoch}',
            title: '🌦️ Weather Impact Strategy',
            description: '${_getWeatherName(worstWeather.key).capitalize()} weather drops your mood to ${worstWeather.value.toStringAsFixed(1)}, while ${_getWeatherName(bestWeather.key)} days boost you to ${bestWeather.value.toStringAsFixed(1)}.',
            type: InsightType.actionable,
            priority: AlertPriority.medium,
            createdAt: now,
            actionSteps: actionSteps,
            confidence: 0.8,
            data: {
              'worstWeather': worstWeather.key.name,
              'bestWeather': bestWeather.key.name,
              'impact': bestWeather.value - worstWeather.value,
            },
            actionText: 'Weather Prep Kit',
          ));
        }
      }
    }

    return insights;
  }

  /// Generate weather-specific action steps
  static List<String> _generateWeatherActionSteps(WeatherCondition weather) {
    switch (weather) {
      case WeatherCondition.rainy:
        return [
          'Set up a cozy indoor space with warm lighting',
          'Plan engaging indoor activities (puzzles, books, crafts)',
          'Use a light therapy lamp for 20-30 minutes',
          'Schedule video calls with friends',
          'Prepare comfort foods and warm beverages',
        ];
      case WeatherCondition.cloudy:
        return [
          'Increase indoor lighting brightness',
          'Take vitamin D supplement',
          'Plan energizing indoor activities',
          'Practice gratitude journaling',
          'Get outside even for brief moments',
        ];
      case WeatherCondition.stormy:
        return [
          'Create a calming environment with soft music',
          'Practice deep breathing or meditation',
          'Avoid caffeine which can increase anxiety',
          'Plan soothing activities like reading or warm baths',
          'Stay connected with supportive people',
        ];
      case WeatherCondition.snowy:
        return [
          'Embrace the beauty with window gazing',
          'Plan cozy indoor activities',
          'Make warm, nourishing meals',
          'Use this time for restful activities',
          'Ensure good indoor lighting',
        ];
      case WeatherCondition.foggy:
        return [
          'Use bright indoor lighting',
          'Plan clear, focused activities',
          'Take extra care with transportation',
          'Create structure in your day',
          'Practice mindfulness to stay grounded',
        ];
      default:
        return [
          'Prepare indoor mood-boosting activities',
          'Ensure good lighting environment',
          'Stay connected with others',
          'Practice self-care strategies',
        ];
    }
  }

  /// NEW: Identify triggers with avoidance strategies
  static Future<List<SmartInsight>> _identifyTriggersWithStrategies(
      List<EnhancedDayData> moodData,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Analyze stress-mood correlations
    final stressMoodPairs = <int, List<double>>{};
    for (final dayData in moodData) {
      if (dayData.correlationData?.workStress != null) {
        final avgMood = dayData.moods.values.reduce((a, b) => a + b) / dayData.moods.length;
        stressMoodPairs.putIfAbsent(dayData.correlationData!.workStress!, () => []).add(avgMood);
      }
    }

    if (stressMoodPairs.length >= 3) {
      // Find correlation between stress levels and mood
      final stressAverages = <int, double>{};
      stressMoodPairs.forEach((stress, moods) {
        if (moods.length >= 2) {
          stressAverages[stress] = moods.reduce((a, b) => a + b) / moods.length;
        }
      });

      if (stressAverages.length >= 3) {
        final highStressEntries = stressAverages.entries.where((e) => e.key >= 7).toList();
        final lowStressEntries = stressAverages.entries.where((e) => e.key <= 4).toList();

        if (highStressEntries.isNotEmpty && lowStressEntries.isNotEmpty) {
          final highStressAvg = highStressEntries
              .map((e) => e.value)
              .reduce((a, b) => a + b) / highStressEntries.length;
          final lowStressAvg = lowStressEntries
              .map((e) => e.value)
              .reduce((a, b) => a + b) / lowStressEntries.length;

          final impact = lowStressAvg - highStressAvg;

          if (impact >= 1.0) {
            insights.add(SmartInsight(
              id: 'stress_trigger_${now.millisecondsSinceEpoch}',
              title: '⚠️ Work Stress Alert',
              description: 'High work stress (7+) drops your mood by ${impact.toStringAsFixed(1)} points (${highStressAvg.toStringAsFixed(1)} vs ${lowStressAvg.toStringAsFixed(1)} on low stress days).',
              type: InsightType.concern,
              priority: AlertPriority.high,
              createdAt: now,
              actionSteps: [
                'Identify your top 3 work stressors this week',
                'Practice 5-minute breathing exercises during high stress',
                'Set boundaries around work communications',
                'Plan stress-relief activities for high-stress days',
                'Consider delegating or postponing non-urgent tasks',
              ],
              confidence: min(impact / 2.0, 1.0),
              data: {
                'impact': impact,
                'highStressAvg': highStressAvg,
                'lowStressAvg': lowStressAvg,
              },
              actionText: 'Stress Management',
            ));
          }
        }
      }
    }

    return insights;
  }

  /// NEW: Predict tomorrow's mood and challenges
  static Future<PredictiveInsight?> _predictTomorrowMood() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowWeekday = tomorrow.weekday;

    // Analyze historical data for this weekday
    final historicalData = await _getHistoricalDataForWeekday(tomorrowWeekday);
    if (historicalData.length < 3) return null;

    final avgMood = historicalData.map((d) => d.averageMood).reduce((a, b) => a + b) / historicalData.length;
    final confidence = min(historicalData.length / 8.0, 1.0); // More data = higher confidence

    final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][tomorrowWeekday - 1];

    String prediction;
    List<String> actions = [];

    if (avgMood >= 7.5) {
      prediction = '$dayName looks promising! Your average for ${dayName}s is ${avgMood.toStringAsFixed(1)}/10. Perfect day to tackle bigger challenges.';
      actions = [
        'Schedule that important task you\'ve been postponing',
        'Plan something special to celebrate your good day',
        'Reach out to someone you care about',
        'Set an ambitious but achievable goal for the day',
      ];
    } else if (avgMood <= 5.5) {
      prediction = '$dayName tends to be challenging for you (avg ${avgMood.toStringAsFixed(1)}/10). Let\'s prepare your mood armor!';
      actions = await _generateMoodProtectionStrategies();
    } else {
      prediction = '$dayName typically rates ${avgMood.toStringAsFixed(1)}/10 for you. A steady day with room for improvement.';
      actions = [
        'Add one small mood-boosting activity to your day',
        'Practice your most effective stress management technique',
        'Plan one thing to look forward to',
        'Set realistic expectations and celebrate small wins',
      ];
    }

    return PredictiveInsight(
      prediction: prediction,
      confidence: confidence,
      reasoning: 'Based on ${historicalData.length} previous ${dayName}s',
      preventativeActions: actions,
    );
  }

  /// Generate mood protection strategies for difficult days
  static Future<List<String>> _generateMoodProtectionStrategies() async {
    final strategies = <String>[];

    // Get user's most effective interventions from correlation data
    final effectiveInterventions = await _getUserMostEffectiveInterventions();
    strategies.addAll(effectiveInterventions);

    // Add general protection strategies
    strategies.addAll([
      'Set up your environment for success the night before',
      'Plan a 15-minute mood check-in at lunch',
      'Have your emergency comfort kit ready',
      'Schedule one thing you genuinely look forward to',
      'Lower your expectations and be extra kind to yourself',
    ]);

    return strategies.take(5).toList(); // Return top 5
  }

  /// NEW: Find user's optimal conditions from their data
  static Future<List<Map<String, dynamic>>> _findOptimalConditions(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final conditions = <Map<String, dynamic>>[];

    // Analyze sleep patterns
    final sleepOptimal = await _findOptimalSleepPattern(moodData);
    if (sleepOptimal != null) conditions.add(sleepOptimal);

    // Analyze activity patterns
    final activityOptimal = await _findOptimalActivityPattern(moodData);
    if (activityOptimal != null) conditions.add(activityOptimal);

    // Analyze social patterns
    final socialOptimal = await _findOptimalSocialPattern(moodData);
    if (socialOptimal != null) conditions.add(socialOptimal);

    return conditions;
  }

  /// Find user's optimal sleep pattern from correlation data
  static Future<Map<String, dynamic>?> _findOptimalSleepPattern(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final sleepMoodPairs = <double, List<double>>{};

    // Collect sleep quality and next day mood correlations
    for (final date in moodData.keys) {
      final nextDay = date.add(const Duration(days: 1));
      if (moodData.containsKey(nextDay)) {
        final correlationData = await CorrelationDataService.loadCorrelationData(date);
        if (correlationData?.sleepQuality != null) {
          final nextDayMood = moodData[nextDay]!.values.reduce((a, b) => a + b) / moodData[nextDay]!.length;
          sleepMoodPairs.putIfAbsent(correlationData!.sleepQuality!, () => []).add(nextDayMood);
        }
      }
    }

    if (sleepMoodPairs.length < 3) return null;

    // Find optimal sleep quality range
    final averages = <double, double>{};
    sleepMoodPairs.forEach((sleepQuality, moods) {
      averages[sleepQuality] = moods.reduce((a, b) => a + b) / moods.length;
    });

    final bestSleep = averages.entries.reduce((a, b) => a.value > b.value ? a : b);

    if (bestSleep.value > 6.5) { // Only suggest if there's a meaningful pattern
      return {
        'type': 'Sleep Quality',
        'description': 'Your mood peaks when your sleep quality is ${bestSleep.key.toStringAsFixed(1)}/10 (resulting mood: ${bestSleep.value.toStringAsFixed(1)})',
        'actionSteps': [
          'Target ${(bestSleep.key * 0.8).toStringAsFixed(1)}-${bestSleep.key.toStringAsFixed(1)} sleep quality',
          'Track what helps you achieve ${bestSleep.key.toStringAsFixed(1)}/10 sleep',
          'Prioritize sleep optimization this week',
          'Notice patterns in your bedtime routine on best sleep days',
        ],
        'confidence': min(sleepMoodPairs[bestSleep.key]!.length / 5.0, 1.0),
        'data': {'optimalSleepQuality': bestSleep.key, 'resultingMood': bestSleep.value},
      };
    }

    return null;
  }

  /// Find optimal activity pattern
  static Future<Map<String, dynamic>?> _findOptimalActivityPattern(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final activityMoodPairs = <ActivityLevel, List<double>>{};

    for (final date in moodData.keys) {
      final correlationData = await CorrelationDataService.loadCorrelationData(date);
      if (correlationData?.exerciseLevel != null) {
        final dayMood = moodData[date]!.values.reduce((a, b) => a + b) / moodData[date]!.length;
        activityMoodPairs.putIfAbsent(correlationData!.exerciseLevel!, () => []).add(dayMood);
      }
    }

    if (activityMoodPairs.length < 2) return null;

    final averages = <ActivityLevel, double>{};
    activityMoodPairs.forEach((level, moods) {
      if (moods.length >= 2) {
        averages[level] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (averages.isEmpty) return null;

    final bestActivity = averages.entries.reduce((a, b) => a.value > b.value ? a : b);
    final baselineMood = averages[ActivityLevel.none] ?? 6.0;
    final boost = bestActivity.value - baselineMood;

    if (boost >= 0.8) {
      return {
        'type': 'Exercise Level',
        'description': '${_getActivityLevelName(bestActivity.key)} boosts your mood by ${boost.toStringAsFixed(1)} points (${bestActivity.value.toStringAsFixed(1)} vs ${baselineMood.toStringAsFixed(1)} baseline)',
        'actionSteps': _getExerciseActionSteps(bestActivity.key),
        'confidence': min(activityMoodPairs[bestActivity.key]!.length / 5.0, 1.0),
        'data': {'optimalActivity': bestActivity.key.name, 'boost': boost},
      };
    }

    return null;
  }

  /// Find optimal social pattern
  static Future<Map<String, dynamic>?> _findOptimalSocialPattern(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final socialMoodPairs = <SocialActivity, List<double>>{};

    for (final date in moodData.keys) {
      final correlationData = await CorrelationDataService.loadCorrelationData(date);
      if (correlationData?.socialActivity != null) {
        final dayMood = moodData[date]!.values.reduce((a, b) => a + b) / moodData[date]!.length;
        socialMoodPairs.putIfAbsent(correlationData!.socialActivity!, () => []).add(dayMood);
      }
    }

    if (socialMoodPairs.length < 2) return null;

    final averages = <SocialActivity, double>{};
    socialMoodPairs.forEach((activity, moods) {
      if (moods.length >= 2) {
        averages[activity] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (averages.isEmpty) return null;

    final bestSocial = averages.entries.reduce((a, b) => a.value > b.value ? a : b);
    final baselineMood = averages[SocialActivity.none] ?? 6.5;
    final boost = bestSocial.value - baselineMood;

    if (boost >= 0.8) {
      return {
        'type': 'Social Activity',
        'description': '${_getSocialActivityName(bestSocial.key)} activities boost your mood by ${boost.toStringAsFixed(1)} points',
        'actionSteps': _getSocialActionSteps(bestSocial.key),
        'confidence': min(socialMoodPairs[bestSocial.key]!.length / 5.0, 1.0),
        'data': {'optimalSocial': bestSocial.key.name, 'boost': boost},
      };
    }

    return null;
  }

  /// NEW: Context-aware suggestions based on calendar, weather, etc.
  static Future<List<SmartInsight>> _generateContextAwareSuggestions() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Weather-based suggestions
    final weatherSuggestion = await _generateWeatherBasedSuggestion();
    if (weatherSuggestion != null) insights.add(weatherSuggestion);

    // Day-of-week specific suggestions
    final daySpecificSuggestion = await _generateDaySpecificSuggestion();
    if (daySpecificSuggestion != null) insights.add(daySpecificSuggestion);

    // Seasonal adjustment suggestions
    final seasonalSuggestion = await _generateSeasonalSuggestion();
    if (seasonalSuggestion != null) insights.add(seasonalSuggestion);

    return insights;
  }

  /// Generate weather-based actionable suggestions
  static Future<SmartInsight?> _generateWeatherBasedSuggestion() async {
    final weatherCorrelations = await _analyzeWeatherMoodCorrelations();
    if (weatherCorrelations.isEmpty) return null;

    final now = DateTime.now();

    // Find user's weather sensitivity
    final worstWeather = weatherCorrelations.entries
        .reduce((a, b) => a.value < b.value ? a : b);

    if (worstWeather.value < 6.0) { // Significantly affected by weather
      final weatherName = worstWeather.key.replaceAll('_', ' ');

      return SmartInsight(
        id: 'weather_strategy_${now.millisecondsSinceEpoch}',
        title: '🌦️ Weather Warrior Strategy',
        description: '${weatherName.capitalize()} days drop your mood to ${worstWeather.value.toStringAsFixed(1)}. Here\'s your personalized weather game plan.',
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        actionSteps: _generateWeatherSpecificActions(worstWeather.key),
        confidence: 0.8,
        data: {'problematicWeather': worstWeather.key, 'impactLevel': worstWeather.value},
        actionText: 'Prepare for Weather',
      );
    }

    return null;
  }

  /// Generate day-specific suggestion
  static Future<SmartInsight?> _generateDaySpecificSuggestion() async {
    final now = DateTime.now();
    final today = now.weekday;

    // Get historical data for today's weekday
    final todayHistorical = await _getHistoricalDataForWeekday(today);
    if (todayHistorical.length < 4) return null;

    final avgForToday = todayHistorical.map((d) => d.averageMood).reduce((a, b) => a + b) / todayHistorical.length;

    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final todayName = dayNames[today - 1];

    if (avgForToday <= 6.0) {
      return SmartInsight(
        id: 'day_specific_${now.millisecondsSinceEpoch}',
        title: '📅 ${todayName} Strategy',
        description: '${todayName}s typically rate ${avgForToday.toStringAsFixed(1)} for you. Here\'s your personalized $todayName game plan.',
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        actionSteps: [
          'Start with your most effective mood booster',
          'Schedule easier tasks and build in extra breaks',
          'Plan one thing to genuinely look forward to',
          'Connect with supportive people',
          'Practice extra self-compassion today',
        ],
        confidence: min(todayHistorical.length / 8.0, 1.0),
        data: {'weekday': today, 'historicalAverage': avgForToday},
        actionText: 'Optimize Today',
      );
    }

    return null;
  }

  /// Generate seasonal suggestion
  static Future<SmartInsight?> _generateSeasonalSuggestion() async {
    final now = DateTime.now();
    final currentMonth = now.month;

    // Analyze seasonal patterns if we have enough historical data
    final seasonalData = await _getSeasonalMoodData();
    if (seasonalData.isEmpty) return null;

    final currentSeason = _getCurrentSeason(currentMonth);
    final seasonalAvg = seasonalData[currentSeason];

    if (seasonalAvg != null && seasonalAvg < 6.5) {
      return SmartInsight(
        id: 'seasonal_${currentSeason}_${now.millisecondsSinceEpoch}',
        title: '🍂 Seasonal Adjustment',
        description: '$currentSeason tends to be challenging for you (avg ${seasonalAvg.toStringAsFixed(1)}). Time for seasonal self-care!',
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        actionSteps: _getSeasonalActionSteps(currentSeason),
        confidence: 0.7,
        data: {'season': currentSeason, 'seasonalAverage': seasonalAvg},
        actionText: 'Seasonal Care',
      );
    }

    return null;
  }

  /// Enhanced achievement detection with progress insights
  static Future<List<SmartInsight>> _detectAchievementsWithProgress() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Current streak with next milestone
    final currentStreak = await _getCurrentStreak();
    final nextMilestone = _getNextMilestone(currentStreak);

    if (nextMilestone != null) {
      final daysToGo = nextMilestone - currentStreak;

      insights.add(SmartInsight(
        id: 'streak_progress_${now.millisecondsSinceEpoch}',
        title: '🔥 ${currentStreak}-Day Streak!',
        description: 'Just $daysToGo more days to reach your ${nextMilestone}-day milestone!',
        type: InsightType.achievement,
        priority: AlertPriority.medium,
        createdAt: now,
        actionSteps: [
          'Set a reminder for your usual mood logging time',
          'Prepare a celebration for reaching $nextMilestone days',
          'Share your progress with someone who supports you',
        ],
        confidence: 0.9,
        data: {
          'currentStreak': currentStreak,
          'nextMilestone': nextMilestone,
          'daysToGo': daysToGo,
        },
        actionText: 'Keep Going!',
      ));
    }

    // Mood improvement achievements
    insights.addAll(await _detectMoodImprovementAchievements());

    // Consistency achievements
    insights.addAll(await _detectConsistencyAchievements());

    return insights;
  }

  /// Detect early warning signs
  static Future<List<SmartInsight>> _detectEarlyWarnings() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    final last14Days = await _getLast14DaysMoodData();
    if (last14Days.length < 10) return insights;

    // Check for consistently low moods
    final lowMoodDays = last14Days.values
        .where((dayMoods) => dayMoods.values.every((mood) => mood <= 4.0))
        .length;

    if (lowMoodDays >= 5) {
      insights.add(SmartInsight(
        id: 'low_mood_concern_${now.millisecondsSinceEpoch}',
        title: '💙 Extra Support Reminder',
        description: 'You\'ve had $lowMoodDays days recently with low mood ratings. Remember that reaching out for support is a sign of strength.',
        type: InsightType.concern,
        priority: AlertPriority.critical,
        createdAt: now,
        actionSteps: [
          'Consider talking to someone you trust about how you\'re feeling',
          'Review what self-care strategies have helped you before',
          'Think about professional support if this continues',
          'Be extra gentle and patient with yourself',
          'Focus on small, manageable goals',
        ],
        confidence: 0.9,
        data: {'lowMoodDays': lowMoodDays},
        actionText: 'Find Resources',
      ));
    }

    // Check for declining trend
    final trendInsight = await _detectMoodTrend();
    if (trendInsight != null) insights.add(trendInsight);

    return insights;
  }

  /// Detect contextual celebrations
  static Future<List<SmartInsight>> _detectContextualCelebrations() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final todayMoods = <int, double>{};

    // Check today's moods
    for (int segment = 0; segment < 3; segment++) {
      final mood = await MoodDataService.loadMood(today, segment);
      if (mood != null && mood['rating'] != null) {
        todayMoods[segment] = (mood['rating'] as num).toDouble();
      }
    }

    // Perfect day celebration
    if (todayMoods.length == 3 && todayMoods.values.every((mood) => mood >= 8.0)) {
      insights.add(SmartInsight(
        id: 'perfect_day_${now.millisecondsSinceEpoch}',
        title: '🎉 Perfect Day Achievement!',
        description: 'All your mood ratings today are 8+ (${todayMoods.values.map((m) => m.toStringAsFixed(1)).join(", ")})! This is worth celebrating!',
        type: InsightType.celebration,
        priority: AlertPriority.high,
        createdAt: now,
        actionSteps: [
          'Take a moment to acknowledge this achievement',
          'Notice what contributed to this great day',
          'Plan to repeat the successful elements',
          'Share this win with someone who cares about you',
          'Treat yourself to something special',
        ],
        confidence: 1.0,
        data: {'moods': todayMoods},
        actionText: 'Celebrate!',
      ));
    }

    // Personal best celebration
    final personalBestInsight = await _checkForPersonalBest();
    if (personalBestInsight != null) insights.add(personalBestInsight);

    return insights;
  }

  /// Predict upcoming challenges based on patterns
  static Future<List<SmartInsight>> _predictUpcomingChallenges() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Check for recurring low mood patterns
    final weeklyPattern = await _analyzeWeeklyMoodPattern();
    if (weeklyPattern != null) {
      final nextChallengingDay = _findNextChallengingDay(weeklyPattern);
      if (nextChallengingDay != null) {
        insights.add(nextChallengingDay);
      }
    }

    // Check for monthly/cyclical patterns
    final cyclicalWarning = await _detectCyclicalPattern();
    if (cyclicalWarning != null) {
      insights.add(cyclicalWarning);
    }

    return insights;
  }

  /// Generate personalized mood boosters
  static Future<List<SmartInsight>> _generatePersonalizedMoodBoosters(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Find user's most effective activities from correlation data
    final effectiveActivities = await _findMostEffectiveActivities(moodData);

    for (final activity in effectiveActivities.take(2)) {
      insights.add(SmartInsight(
        id: 'mood_booster_${activity['type']}_${now.millisecondsSinceEpoch}',
        title: '⚡ Your ${activity['name']} Superpower',
        description: '${activity['name']} consistently boosts your mood by ${activity['boost'].toStringAsFixed(1)} points. Time to use this superpower!',
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        actionSteps: activity['actionSteps'],
        confidence: activity['confidence'],
        data: activity,
        actionText: 'Try This Week',
      ));
    }

    return insights;
  }

  // Helper methods and data processing functions

  /// Get mood data with correlations for enhanced analysis
  static Future<List<EnhancedDayData>> _getMoodDataWithCorrelations(
      DateTime startDate,
      DateTime endDate,
      ) async {
    final data = <EnhancedDayData>[];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dayMoods = <int, double>{};

      // Get mood data
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(currentDate, segment);
        if (mood != null && mood['rating'] != null) {
          dayMoods[segment] = (mood['rating'] as num).toDouble();
        }
      }

      // Get correlation data
      final correlationData = await CorrelationDataService.loadCorrelationData(currentDate);

      if (dayMoods.isNotEmpty || correlationData != null) {
        data.add(EnhancedDayData(
          date: currentDate,
          moods: dayMoods,
          correlationData: correlationData,
        ));
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return data;
  }

  /// Get exercise action steps based on optimal level
  static List<String> _getExerciseActionSteps(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.light:
        return [
          'Take a 15-minute walk during lunch break',
          'Try gentle yoga or stretching',
          'Dance to 3-4 favorite songs',
          'Do gardening or light household activities',
        ];
      case ActivityLevel.moderate:
        return [
          'Schedule 30-45 minutes of cardio 3x this week',
          'Try a fitness class or online workout',
          'Go for a bike ride or swim',
          'Play an active sport you enjoy',
        ];
      case ActivityLevel.intense:
        return [
          'Book that high-intensity class you\'ve been considering',
          'Set a new personal fitness challenge',
          'Try interval training or heavy lifting',
          'Join a competitive sports league',
        ];
      default:
        return ['Find gentle ways to move your body'];
    }
  }

  /// Get social action steps based on optimal activity
  static List<String> _getSocialActionSteps(SocialActivity activity) {
    switch (activity) {
      case SocialActivity.friends:
        return [
          'Schedule a coffee date or call with a close friend',
          'Plan a fun group activity for this weekend',
          'Join a hobby group or meetup',
          'Reach out to someone you haven\'t talked to in a while',
        ];
      case SocialActivity.family:
        return [
          'Plan quality time with family members',
          'Schedule a family meal or activity',
          'Call a family member you miss',
          'Create new family traditions or memories',
        ];
      case SocialActivity.work:
        return [
          'Suggest a team coffee break or lunch',
          'Join or organize workplace social events',
          'Build stronger relationships with colleagues',
          'Find opportunities for positive work interactions',
        ];
      case SocialActivity.party:
        return [
          'Attend that event you\'ve been considering',
          'Host a small gathering for friends',
          'Say yes to the next social invitation',
          'Plan a celebration for recent accomplishments',
        ];
      case SocialActivity.date:
        return [
          'Plan a special date with your partner',
          'Try a new activity together',
          'Schedule regular quality time together',
          'Create romantic moments in daily life',
        ];
      default:
        return ['Consider gentle social connections that feel comfortable'];
    }
  }

  /// Generate weather-specific action steps
  static List<String> _generateWeatherSpecificActions(String weatherType) {
    switch (weatherType) {
      case 'rainy':
        return [
          'Set up a cozy indoor space with good lighting',
          'Plan engaging indoor activities (puzzles, cooking, crafts)',
          'Use a light therapy lamp for 20-30 minutes',
          'Schedule video calls with friends',
          'Have comfort foods ready',
        ];
      case 'cloudy':
        return [
          'Take vitamin D supplement',
          'Use bright indoor lighting',
          'Plan energizing activities',
          'Practice gratitude journaling',
        ];
      case 'stormy':
        return [
          'Create a calming environment with soft music',
          'Practice breathing exercises or meditation',
          'Avoid caffeine which can increase anxiety',
          'Plan soothing activities like reading or warm baths',
        ];
      default:
        return [
          'Prepare indoor mood-boosting activities',
          'Ensure good indoor lighting',
          'Stay connected with others',
        ];
    }
  }

  /// Get activity level name
  static String _getActivityLevelName(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.none: return 'Rest';
      case ActivityLevel.light: return 'Light Movement';
      case ActivityLevel.moderate: return 'Moderate Exercise';
      case ActivityLevel.intense: return 'Intense Workouts';
    }
  }

  /// Get social activity name
  static String _getSocialActivityName(SocialActivity activity) {
    switch (activity) {
      case SocialActivity.none: return 'Solo Time';
      case SocialActivity.friends: return 'Friend Time';
      case SocialActivity.family: return 'Family Time';
      case SocialActivity.work: return 'Work Social';
      case SocialActivity.party: return 'Social Events';
      case SocialActivity.date: return 'Date Activities';
    }
  }

  /// Get weather name
  static String _getWeatherName(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny: return 'sunny';
      case WeatherCondition.cloudy: return 'cloudy';
      case WeatherCondition.rainy: return 'rainy';
      case WeatherCondition.stormy: return 'stormy';
      case WeatherCondition.snowy: return 'snowy';
      case WeatherCondition.foggy: return 'foggy';
    }
  }

  /// Find most effective activities for mood boosting
  static Future<List<Map<String, dynamic>>> _findMostEffectiveActivities(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final activities = <Map<String, dynamic>>[];

    // Analyze exercise patterns
    final exerciseEffect = await _analyzeExerciseEffect(moodData);
    if (exerciseEffect != null) activities.add(exerciseEffect);

    // Analyze social activity patterns
    final socialEffect = await _analyzeSocialEffect(moodData);
    if (socialEffect != null) activities.add(socialEffect);

    // Sort by effectiveness
    activities.sort((a, b) => b['boost'].compareTo(a['boost']));

    return activities;
  }

  /// Analyze exercise effect on mood
  static Future<Map<String, dynamic>?> _analyzeExerciseEffect(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final exerciseEffects = <ActivityLevel, List<double>>{};

    for (final date in moodData.keys) {
      final correlationData = await CorrelationDataService.loadCorrelationData(date);
      if (correlationData?.exerciseLevel != null) {
        final dayMood = moodData[date]!.values.reduce((a, b) => a + b) / moodData[date]!.length;
        exerciseEffects.putIfAbsent(correlationData!.exerciseLevel!, () => []).add(dayMood);
      }
    }

    if (exerciseEffects.length < 2) return null;

    // Find most effective exercise level
    final averages = <ActivityLevel, double>{};
    exerciseEffects.forEach((level, moods) {
      if (moods.length >= 3) {
        averages[level] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (averages.isEmpty) return null;

    final bestLevel = averages.entries.reduce((a, b) => a.value > b.value ? a : b);
    final baselineMood = averages[ActivityLevel.none] ?? 6.0;
    final boost = bestLevel.value - baselineMood;

    if (boost >= 0.8) {
      return {
        'type': 'exercise',
        'name': _getActivityLevelName(bestLevel.key),
        'boost': boost,
        'confidence': min(exerciseEffects[bestLevel.key]!.length / 5.0, 1.0),
        'actionSteps': _getExerciseActionSteps(bestLevel.key),
      };
    }

    return null;
  }

  /// Analyze social effect on mood
  static Future<Map<String, dynamic>?> _analyzeSocialEffect(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final socialEffects = <SocialActivity, List<double>>{};

    for (final date in moodData.keys) {
      final correlationData = await CorrelationDataService.loadCorrelationData(date);
      if (correlationData?.socialActivity != null) {
        final dayMood = moodData[date]!.values.reduce((a, b) => a + b) / moodData[date]!.length;
        socialEffects.putIfAbsent(correlationData!.socialActivity!, () => []).add(dayMood);
      }
    }

    if (socialEffects.length < 2) return null;

    final averages = <SocialActivity, double>{};
    socialEffects.forEach((activity, moods) {
      if (moods.length >= 2) {
        averages[activity] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (averages.isEmpty) return null;

    final bestSocial = averages.entries.reduce((a, b) => a.value > b.value ? a : b);
    final baselineMood = averages[SocialActivity.none] ?? 6.0;
    final boost = bestSocial.value - baselineMood;

    if (boost >= 0.8) {
      return {
        'type': 'social',
        'name': _getSocialActivityName(bestSocial.key),
        'boost': boost,
        'confidence': min(socialEffects[bestSocial.key]!.length / 3.0, 1.0),
        'actionSteps': _getSocialActionSteps(bestSocial.key),
      };
    }

    return null;
  }

  /// Get user's most effective interventions
  static Future<List<String>> _getUserMostEffectiveInterventions() async {
    final interventions = <String>[];
    final last30Days = await _getLast30DaysMoodData();

    // Check sleep impact
    final sleepImpact = await _analyzeSleepImpact(last30Days);
    if (sleepImpact != null && sleepImpact > 0.5) {
      interventions.add('Prioritize getting 7-8 hours of quality sleep tonight');
    }

    // Check exercise impact
    final exerciseImpact = await _getOptimalExerciseForUser();
    if (exerciseImpact != null) {
      interventions.add('Do ${exerciseImpact.toLowerCase()} - it typically boosts your mood');
    }

    // Add social intervention if effective
    final socialImpact = await _analyzeSocialImpact(last30Days);
    if (socialImpact != null && socialImpact > 0.5) {
      interventions.add('Connect with someone who usually lifts your spirits');
    }

    return interventions.take(3).toList();
  }

  /// Analyze sleep impact on mood
  static Future<double?> _analyzeSleepImpact(Map<DateTime, Map<int, double>> moodData) async {
    final correlations = <double>[];

    for (final date in moodData.keys) {
      final correlationData = await CorrelationDataService.loadCorrelationData(date);
      if (correlationData?.sleepQuality != null) {
        final nextDay = date.add(const Duration(days: 1));
        if (moodData.containsKey(nextDay)) {
          final nextDayMood = moodData[nextDay]!.values.reduce((a, b) => a + b) / moodData[nextDay]!.length;
          // Simple correlation estimate
          correlations.add((correlationData!.sleepQuality! / 10.0) * (nextDayMood / 10.0));
        }
      }
    }

    if (correlations.length < 5) return null;
    return correlations.reduce((a, b) => a + b) / correlations.length;
  }

  static Future<List<SmartInsight>> _analyzeWeeklyPatterns(
    Map<DateTime, Map<int, double>> moodData,
  ) async {
    final insights = <SmartInsight>[];
    final weekdayMoods = <int, List<double>>{};

    // Group by weekday (1=Monday, 7=Sunday)
    moodData.forEach((date, dayMoods) {
      final weekday = date.weekday;
      final dayAverage =
          dayMoods.values.reduce((a, b) => a + b) / dayMoods.length;
      weekdayMoods.putIfAbsent(weekday, () => []).add(dayAverage);
    });

    // Calculate weekday averages
    final weekdayAverages = <int, double>{};
    weekdayMoods.forEach((weekday, moods) {
      if (moods.length >= 2) {
        weekdayAverages[weekday] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (weekdayAverages.length >= 5) {
      // Need most days of week
      final sortedDays = weekdayAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestDay = sortedDays.first;
      final worstDay = sortedDays.last;
      final difference = bestDay.value - worstDay.value;

      if (difference >= 1.2) {
        final dayNames = [
          '',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];

        insights.add(SmartInsight(
          id: 'weekday_pattern_${DateTime.now().millisecondsSinceEpoch}',
          title: '${dayNames[bestDay.key]}s are your best days',
          description:
              'Your mood averages ${bestDay.value.toStringAsFixed(1)} on ${dayNames[bestDay.key]}s vs ${worstDay.value.toStringAsFixed(1)} on ${dayNames[worstDay.key]}s',
          type: InsightType.pattern,
          priority: AlertPriority.medium,
          createdAt: DateTime.now(),
          data: {
            'bestDay': bestDay.key,
            'worstDay': worstDay.key,
            'difference': difference,
          },
          actionText: 'Plan your week',
        ));
      }
    }

    return insights;
  }

  static Future<List<SmartInsight>> _analyzeTrends(
    Map<DateTime, Map<int, double>> moodData,
  ) async {
    final insights = <SmartInsight>[];

    if (moodData.length < 14) return insights;

    // Calculate daily averages and sort by date
    final dailyAverages = <DateTime, double>{};
    moodData.forEach((date, dayMoods) {
      dailyAverages[date] =
          dayMoods.values.reduce((a, b) => a + b) / dayMoods.length;
    });

    final sortedDates = dailyAverages.keys.toList()..sort();
    final recentWeek = sortedDates.reversed.take(7).toList();
    final previousWeek = sortedDates.reversed.skip(7).take(7).toList();

    if (recentWeek.length >= 5 && previousWeek.length >= 5) {
      final recentAvg = recentWeek
              .map((date) => dailyAverages[date]!)
              .reduce((a, b) => a + b) /
          recentWeek.length;

      final previousAvg = previousWeek
              .map((date) => dailyAverages[date]!)
              .reduce((a, b) => a + b) /
          previousWeek.length;

      final change = recentAvg - previousAvg;

      if (change.abs() >= 1.0) {
        if (change > 0) {
          insights.add(SmartInsight(
            id: 'trend_improving_${DateTime.now().millisecondsSinceEpoch}',
            title: '📈 Your mood is improving!',
            description:
                'This week you\'re averaging ${recentAvg.toStringAsFixed(1)}, up ${change.toStringAsFixed(1)} points from last week (${previousAvg.toStringAsFixed(1)})',
            type: InsightType.celebration,
            priority: AlertPriority.medium,
            createdAt: DateTime.now(),
            data: {
              'recentAverage': recentAvg,
              'previousAverage': previousAvg,
              'change': change,
            },
            actionText: 'See trends',
            actionRoute: '/trends',
          ));
        } else {
          insights.add(SmartInsight(
            id: 'trend_declining_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Your mood has been lower lately',
            description:
                'This week you\'re averaging ${recentAvg.toStringAsFixed(1)}, down ${change.abs().toStringAsFixed(1)} points from last week. Consider some self-care activities.',
            type: InsightType.concern,
            priority: AlertPriority.high,
            createdAt: DateTime.now(),
            data: {
              'recentAverage': recentAvg,
              'previousAverage': previousAvg,
              'change': change,
            },
            actionText: 'View suggestions',
            actionRoute: '/ai-analysis',
          ));
        }
      }
    }

    return insights;
  }

  /// Detect achievements and milestones
  static Future<List<SmartInsight>> _detectAchievements() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Calculate current streak
    int currentStreak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 365; i++) {
      bool hasAnyMood = false;
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(checkDate, segment);
        if (mood != null && mood['rating'] != null) {
          hasAnyMood = true;
          break;
        }
      }

      if (hasAnyMood) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Streak achievements
    final streakMilestones = [7, 14, 30, 50, 100, 365];
    for (final milestone in streakMilestones) {
      if (currentStreak == milestone) {
        String emoji = '🔥';
        String description = '$milestone days of consistent mood tracking!';

        if (milestone >= 100) {
          emoji = '🏆';
          description = '$milestone days! You\'re a mood tracking champion!';
        } else if (milestone >= 30) {
          emoji = '⭐';
          description = '$milestone days! You\'ve built a strong habit!';
        }

        insights.add(SmartInsight(
          id: 'streak_${milestone}_${now.millisecondsSinceEpoch}',
          title: '$emoji $milestone Day Streak!',
          description: description,
          type: InsightType.achievement,
          priority: AlertPriority.high,
          createdAt: now,
          data: {'streak': currentStreak, 'milestone': milestone},
          actionText: 'Share achievement',
        ));
        break;
      }
    }

    // High mood consistency
    final last30Days = await _getLast30DaysMoodData();
    if (last30Days.length >= 20) {
      final highMoodDays = last30Days.values
          .where((dayMoods) => dayMoods.values.any((mood) => mood >= 7.0))
          .length;

      final percentage = (highMoodDays / last30Days.length) * 100;

      if (percentage >= 70) {
        insights.add(SmartInsight(
          id: 'high_mood_consistency_${now.millisecondsSinceEpoch}',
          title: '🌟 Great mood consistency!',
          description:
              '${percentage.round()}% of your recent days had mood ratings of 7+. You\'re doing amazing!',
          type: InsightType.achievement,
          priority: AlertPriority.medium,
          createdAt: now,
          data: {'percentage': percentage, 'highMoodDays': highMoodDays},
        ));
      }
    }

    return insights;
  }

  /// Detect concerning patterns
  static Future<List<SmartInsight>> _detectConcerns() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    final last14Days = await _getLast14DaysMoodData();
    if (last14Days.length < 10) return insights;

    // Check for consistently low moods
    final lowMoodDays = last14Days.values
        .where((dayMoods) => dayMoods.values.every((mood) => mood <= 4.0))
        .length;

    if (lowMoodDays >= 5) {
      insights.add(SmartInsight(
        id: 'low_mood_concern_${now.millisecondsSinceEpoch}',
        title: 'Consider reaching out for support',
        description:
            'You\'ve had $lowMoodDays days recently with consistently low mood ratings. Remember that it\'s okay to ask for help.',
        type: InsightType.concern,
        priority: AlertPriority.critical,
        createdAt: now,
        data: {'lowMoodDays': lowMoodDays},
        actionText: 'Find resources',
      ));
    }

    // Check for declining sleep correlation
    final correlationData = <CorrelationData>[];
    for (final date in last14Days.keys) {
      final correlation =
          await CorrelationDataService.loadCorrelationData(date);
      if (correlation != null && correlation.sleepQuality != null) {
        correlationData.add(correlation);
      }
    }

    if (correlationData.length >= 7) {
      final recentSleep = correlationData
          .where((c) => c.date.isAfter(now.subtract(const Duration(days: 7))))
          .map((c) => c.sleepQuality!)
          .toList();

      if (recentSleep.length >= 5) {
        final avgSleep =
            recentSleep.reduce((a, b) => a + b) / recentSleep.length;

        if (avgSleep <= 4.0) {
          insights.add(SmartInsight(
            id: 'poor_sleep_concern_${now.millisecondsSinceEpoch}',
            title: 'Your sleep quality needs attention',
            description:
                'Your recent sleep quality averages ${avgSleep.toStringAsFixed(1)}/10. Poor sleep can significantly impact your mood.',
            type: InsightType.concern,
            priority: AlertPriority.high,
            createdAt: now,
            data: {'averageSleep': avgSleep},
            actionText: 'Sleep tips',
          ));
        }
      }
    }

    return insights;
  }

  /// Detect celebration moments
  static Future<List<SmartInsight>> _detectCelebrations() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final todayMoods = <int, double>{};

    // Check today's moods
    for (int segment = 0; segment < 3; segment++) {
      final mood = await MoodDataService.loadMood(today, segment);
      if (mood != null && mood['rating'] != null) {
        todayMoods[segment] = (mood['rating'] as num).toDouble();
      }
    }

    // Perfect day celebration
    if (todayMoods.length == 3 &&
        todayMoods.values.every((mood) => mood >= 8.0)) {
      insights.add(SmartInsight(
        id: 'perfect_day_${now.millisecondsSinceEpoch}',
        title: '🎉 Perfect day!',
        description:
            'All your mood ratings today are 8+ (${todayMoods.values.map((m) => m.toStringAsFixed(1)).join(", ")}). Celebrate this amazing day!',
        type: InsightType.celebration,
        priority: AlertPriority.high,
        createdAt: now,
        data: {'moods': todayMoods},
      ));
    }

    // Personal best celebration
    final last90Days = await _getLast90DaysMoodData();
    if (last90Days.isNotEmpty && todayMoods.isNotEmpty) {
      final todayAvg =
          todayMoods.values.reduce((a, b) => a + b) / todayMoods.length;
      final historicalAverages = last90Days.values
          .map((dayMoods) =>
              dayMoods.values.reduce((a, b) => a + b) / dayMoods.length)
          .toList()
        ..sort();

      if (historicalAverages.length >= 30 &&
          todayAvg >= historicalAverages.last) {
        insights.add(SmartInsight(
          id: 'personal_best_${now.millisecondsSinceEpoch}',
          title: '🏆 Personal best!',
          description:
              'Today\'s average mood (${todayAvg.toStringAsFixed(1)}) ties your highest in the last 90 days!',
          type: InsightType.celebration,
          priority: AlertPriority.medium,
          createdAt: now,
          data: {'todayAverage': todayAvg},
        ));
      }
    }

    return insights;
  }

  /// Generate personalized suggestions
  static Future<List<SmartInsight>> _generateSuggestions() async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Analyze correlation data for suggestions
    final correlationInsights = await CorrelationDataService.generateInsights();

    for (final correlation in correlationInsights.take(2)) {
      if (correlation.strength >= 0.5) {
        String title = '';
        String description = '';

        switch (correlation.category) {
          case 'weather':
            title = '☀️ Weather tip';
            description =
                'Based on your data, ${correlation.description.toLowerCase()}. Plan outdoor activities on sunny days!';
            break;
          case 'sleep':
            title = '😴 Sleep matters';
            description =
                '${correlation.description}. Consider a consistent bedtime routine.';
            break;
          case 'exercise':
            title = '🏃‍♀️ Move your body';
            description =
                '${correlation.description}. Even light activity can help!';
            break;
        }

        if (title.isNotEmpty) {
          insights.add(SmartInsight(
            id: 'suggestion_${correlation.category}_${now.millisecondsSinceEpoch}',
            title: title,
            description: description,
            type: InsightType.suggestion,
            priority: AlertPriority.low,
            createdAt: now,
            data: correlation.data,
          ));
        }
      }
    }

    return insights;
  }

  /// Schedule adaptive notifications
  static Future<void> scheduleAdaptiveReminders() async {
    final userPatterns = await _getUserPatterns();
    final settings = await _getInsightsSettings();

    if (!settings['adaptiveReminders']) return;

    // Schedule streak protection reminder
    final currentStreak = await _getCurrentStreak();
    if (currentStreak >= 7) {
      final now = DateTime.now();
      final hasLoggedToday = await _hasLoggedToday();

      if (!hasLoggedToday && now.hour >= 20) {
        await RealNotificationService.showNotification(
          id: 5001,
          title: '🔥 Don\'t break your $currentStreak-day streak!',
          body:
              'You\'ve been doing great with consistent tracking. Log your mood before bed.',
          payload: jsonEncode({
            'type': 'streak_protection',
            'streak': currentStreak,
          }),
        );
      }
    }

    // Schedule pattern-based reminders
    if (userPatterns['bestTime'] != null) {
      final bestTime = userPatterns['bestTime'] as int;
      final timeNames = ['morning', 'midday', 'evening'];

      // Encourage logging at their best time
      final reminderTimes = [9, 13, 19]; // Default times
      await RealNotificationService.scheduleDailyNotification(
        id: 5002 + bestTime,
        title: 'Perfect timing! ⭐',
        body:
            'This is typically your best ${timeNames[bestTime]} time. How are you feeling?',
        time: NotificationTime(reminderTimes[bestTime], 0),
        payload: jsonEncode({
          'type': 'optimal_time_reminder',
          'segment': bestTime,
        }),
      );
    }
  }

  /// Generate weekly summary
  static Future<WeeklySummary> generateWeeklySummary(
      [DateTime? weekStart]) async {
    weekStart ??=
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final weekMoodData = <DateTime, Map<int, double>>{};
    DateTime currentDate = weekStart;

    while (currentDate.isBefore(weekEnd.add(const Duration(days: 1)))) {
      final dayMoods = <int, double>{};
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(currentDate, segment);
        if (mood != null && mood['rating'] != null) {
          dayMoods[segment] = (mood['rating'] as num).toDouble();
        }
      }
      if (dayMoods.isNotEmpty) {
        weekMoodData[currentDate] = dayMoods;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    if (weekMoodData.isEmpty) {
      return WeeklySummary(
        weekStart: weekStart,
        weekEnd: weekEnd,
        averageMood: 0,
        daysLogged: 0,
        totalDays: 7,
        bestDay: 0,
        worstDay: 0,
        trend: 'stable',
        highlights: ['Start logging to see insights'],
        concerns: [],
        recommendations: ['Begin tracking your moods daily'],
      );
    }

    // Calculate statistics
    final dailyAverages = <double>[];
    for (final dayMoods in weekMoodData.values) {
      dailyAverages
          .add(dayMoods.values.reduce((a, b) => a + b) / dayMoods.length);
    }

    final averageMood =
        dailyAverages.reduce((a, b) => a + b) / dailyAverages.length;
    final bestDay = dailyAverages.reduce(max);
    final worstDay = dailyAverages.reduce(min);

    // Determine trend
    String trend = 'stable';
    if (dailyAverages.length >= 4) {
      final firstHalf = dailyAverages.take(dailyAverages.length ~/ 2).toList();
      final secondHalf = dailyAverages.skip(dailyAverages.length ~/ 2).toList();

      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

      if (secondAvg - firstAvg >= 0.8) {
        trend = 'improving';
      } else if (firstAvg - secondAvg >= 0.8) {
        trend = 'declining';
      }
    }

    // Generate highlights and recommendations
    final highlights = <String>[];
    final concerns = <String>[];
    final recommendations = <String>[];

    if (averageMood >= 7.5) {
      highlights.add(
          'Great week! Your average mood was ${averageMood.toStringAsFixed(1)}');
    }

    if (weekMoodData.length >= 6) {
      highlights
          .add('Excellent consistency - logged ${weekMoodData.length}/7 days');
    }

    if (bestDay >= 9.0) {
      highlights.add(
          'You had an amazing day with ${bestDay.toStringAsFixed(1)} average mood!');
    }

    if (trend == 'improving') {
      highlights.add('Your mood improved throughout the week');
    } else if (trend == 'declining') {
      concerns.add('Your mood declined this week - consider self-care');
      recommendations.add('Try activities that usually boost your mood');
    }

    if (weekMoodData.length < 5) {
      recommendations.add('Try to log moods more consistently');
    }

    return WeeklySummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      averageMood: averageMood,
      daysLogged: weekMoodData.length,
      totalDays: 7,
      bestDay: bestDay,
      worstDay: worstDay,
      trend: trend,
      highlights: highlights,
      concerns: concerns,
      recommendations: recommendations,
    );
  }

  // Helper methods
  static Future<Map<DateTime, Map<int, double>>>
      _getLast30DaysMoodData() async {
    return await _getMoodDataForPeriod(30);
  }

  static Future<Map<DateTime, Map<int, double>>>
      _getLast14DaysMoodData() async {
    return await _getMoodDataForPeriod(14);
  }

  static Future<Map<DateTime, Map<int, double>>>
      _getLast90DaysMoodData() async {
    return await _getMoodDataForPeriod(90);
  }

  static Future<Map<DateTime, Map<int, double>>> _getMoodDataForPeriod(
      int days) async {
    final moodData = <DateTime, Map<int, double>>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayMoods = <int, double>{};

      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(date, segment);
        if (mood != null && mood['rating'] != null) {
          dayMoods[segment] = (mood['rating'] as num).toDouble();
        }
      }

      if (dayMoods.isNotEmpty) {
        moodData[date] = dayMoods;
      }
    }

    return moodData;
  }

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
    final existingInsights = await loadInsights();

    // Merge with existing insights, avoiding duplicates
    final allInsights = [...existingInsights, ...insights];
    final uniqueInsights = <SmartInsight>[];
    final seenIds = <String>{};

    for (final insight in allInsights.reversed) {
      if (!seenIds.contains(insight.id)) {
        uniqueInsights.insert(0, insight);
        seenIds.add(insight.id);
      }
    }

    // Keep only recent insights (last 30 days)
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    final recentInsights = uniqueInsights
        .where((insight) => insight.createdAt.isAfter(cutoffDate))
        .toList();

    final jsonData = recentInsights.map((insight) => insight.toJson()).toList();
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
      Logger.analyticsService('Error loading insights: $e');
      return [];
    }
  }

  static Future<void> _updateLastAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAnalysisKey, DateTime.now().toIso8601String());
  }

  static Future<Map<String, dynamic>> _getUserPatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final patternsString = prefs.getString(_userPatternsKey);

    if (patternsString == null) return {};

    return jsonDecode(patternsString) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _getInsightsSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsString = prefs.getString(_settingsKey);

    if (settingsString == null) {
      return {
        'adaptiveReminders': true,
        'weeklyReports': true,
        'monthlyReports': true,
        'patternAlerts': true,
        'celebrations': true,
      };
    }

    return jsonDecode(settingsString) as Map<String, dynamic>;
  }

  static Future<int> _getCurrentStreak() async {
    int streak = 0;
    final now = DateTime.now();
    DateTime currentDate = DateTime(now.year, now.month, now.day);

    // Check up to 365 days back maximum
    for (int i = 0; i < 365; i++) {
      bool hasAnyMood = false;

      // Check if any segment has data for this day
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
        break; // Streak broken
      }

      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  static Future<bool> _hasLoggedToday() async {
    final today = DateTime.now();
    for (int segment = 0; segment < 3; segment++) {
      final mood = await MoodDataService.loadMood(today, segment);
      if (mood != null && mood['rating'] != null) {
        return true;
      }
    }
    return false;
  }
}
