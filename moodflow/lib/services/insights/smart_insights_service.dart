// lib/services/insights/smart_insights_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mood_data_service.dart';
import '../data/correlation_data_service.dart';
import '../utils/logger.dart';

class SmartInsightsService {
  static const String _insightsKey = 'enhanced_smart_insights';
  static const String _lastAnalysisKey = 'last_enhanced_analysis_date';
  static const String _userPatternsKey = 'enhanced_user_patterns';
  static const String _predictiveModelKey = 'predictive_model_data';

  /// Generate comprehensive enhanced insights with predictive capabilities
  static Future<List<SmartInsight>> generateEnhancedInsights({
    bool forceRefresh = false,
  }) async {
    final insights = <SmartInsight>[];

    // Check if we need to run analysis
    if (!forceRefresh && !await _shouldRunAnalysis()) {
      return await loadInsights();
    }

    Logger.smartInsightService('🧠 Generating enhanced smart insights with AI...');

    try {
      // Get comprehensive mood and correlation data
      final analysisData = await _gatherComprehensiveData();

      if (analysisData.days.length < 7) {
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

      // 5. Relationship Mapping
      insights.addAll(await _generateRelationshipMapping(analysisData));

      // 6. Seasonal Intelligence
      insights.addAll(await _generateSeasonalIntelligence(analysisData));

      // 7. Cycle Recognition
      insights.addAll(await _generateCycleRecognition(analysisData));

      // 8. Goal Integration and Milestone Tracking
      insights.addAll(await _generateGoalIntegration(analysisData));

      // Sort by priority and confidence
      insights.sort((a, b) {
        final priorityA = _getPriorityScore(a.priority);
        final priorityB = _getPriorityScore(b.priority);
        if (priorityA != priorityB) return priorityB.compareTo(priorityA);

        final confidenceA = a.confidence ?? 0.0;
        final confidenceB = b.confidence ?? 0.0;
        return confidenceB.compareTo(confidenceA);
      });

      // Update user patterns for future predictions
      await _updateUserPatterns(analysisData);

      // Save insights and update analysis timestamp
      await _saveInsights(insights.take(20).toList()); // Keep top 20 insights
      await _updateLastAnalysis();

      Logger.smartInsightService('✅ Generated ${insights.length} enhanced insights');
      return insights.take(20).toList();

    } catch (e) {
      Logger.smartInsightService('❌ Error generating enhanced insights: $e');
      return [];
    }
  }

  /// Generate actionable pattern recognition insights
  static Future<List<SmartInsight>> _generateActionablePatterns(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Morning Advantage Detection
    final morningAdvantage = _detectMorningAdvantage(data);
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
          'Consider these proven mood boosters: meditation, protein-rich breakfast, gentle exercise',
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

    // Sleep Sweet Spot Analysis
    final sleepSweetSpot = _detectSleepSweetSpot(data);
    if (sleepSweetSpot != null) {
      insights.add(SmartInsight(
        id: 'sleep_sweet_spot_${now.millisecondsSinceEpoch}',
        title: '😴 Sleep Sweet Spot',
        description: 'Your optimal sleep quality is ${sleepSweetSpot.optimalQuality.toStringAsFixed(1)}/10 (not 8!), resulting in ${sleepSweetSpot.resultingMood.toStringAsFixed(1)} mood rating',
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: sleepSweetSpot.confidence,
        actionSteps: [
          'Target ${sleepSweetSpot.optimalQuality.toStringAsFixed(1)}/10 sleep quality consistently',
          'Track what helps you achieve this optimal sleep',
          'Notice patterns in your bedtime routine on best sleep days',
          'Consider sleep environment optimization',
        ],
        data: sleepSweetSpot.data,
        actionText: 'Sleep Optimization',
      ));
    }

    return insights;
  }

  /// Generate predictive intelligence insights
  static Future<List<SmartInsight>> _generatePredictiveInsights(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Tomorrow's Forecast
    final tomorrowForecast = _predictTomorrowMood(data);
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

    // Early Warning System
    final earlyWarnings = _detectEarlyWarnings(data);
    for (final warning in earlyWarnings) {
      insights.add(SmartInsight(
        id: 'early_warning_${warning.type}_${now.millisecondsSinceEpoch}',
        title: '⚠️ ${warning.title}',
        description: warning.description,
        type: InsightType.concern,
        priority: AlertPriority.critical,
        createdAt: now,
        confidence: warning.confidence,
        actionSteps: warning.preventativeActions,
        data: warning.data,
        actionText: 'Take Action',
      ));
    }

    return insights;
  }

  /// Generate personalized recommendations engine insights
  static Future<List<SmartInsight>> _generatePersonalizedRecommendations(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Custom Mood Hacks
    final moodHacks = _generateCustomMoodHacks(data);
    for (final hack in moodHacks.take(3)) {
      insights.add(SmartInsight(
        id: 'mood_hack_${hack.type}_${now.millisecondsSinceEpoch}',
        title: '💡 ${hack.title}',
        description: hack.description,
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: hack.confidence,
        actionSteps: hack.actionSteps,
        data: hack.data,
        actionText: 'Try This Week',
      ));
    }

    return insights;
  }

  /// Generate environmental intelligence insights
  static Future<List<SmartInsight>> _generateEnvironmentalIntelligence(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Weather Warrior Analysis
    final weatherImpact = _analyzeWeatherImpact(data);
    if (weatherImpact != null) {
      insights.add(SmartInsight(
        id: 'weather_warrior_${now.millisecondsSinceEpoch}',
        title: '🌦️ Weather Warrior Strategy',
        description: '${weatherImpact.worstCondition} days drop your mood by ${weatherImpact.impact.toStringAsFixed(1)} points, but we can prepare for this!',
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

  /// Generate seasonal intelligence insights
  static Future<List<SmartInsight>> _generateSeasonalIntelligence(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Detect seasonal patterns
    final seasonalPattern = _detectSeasonalPattern(data);
    if (seasonalPattern != null) {
      final currentSeason = _getCurrentSeason(now.month);

      if (seasonalPattern.challengingSeason == currentSeason) {
        insights.add(SmartInsight(
          id: 'seasonal_adjustment_${now.millisecondsSinceEpoch}',
          title: '🍂 Seasonal Adjustment Time',
          description: '$currentSeason tends to be challenging for you (avg ${seasonalPattern.challengingAvg.toStringAsFixed(1)}). Time for seasonal self-care!',
          type: InsightType.actionable,
          priority: AlertPriority.medium,
          createdAt: now,
          confidence: seasonalPattern.confidence,
          actionSteps: _getSeasonalActionSteps(currentSeason),
          data: seasonalPattern.data,
          actionText: 'Seasonal Care',
        ));
      }
    }

    return insights;
  }

  /// Generate cycle recognition insights
  static Future<List<SmartInsight>> _generateCycleRecognition(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Detect ultradian rhythms
    final ultradianRhythm = _detectUltradianRhythm(data);
    if (ultradianRhythm != null) {
      insights.add(SmartInsight(
        id: 'ultradian_rhythm_${now.millisecondsSinceEpoch}',
        title: '🔄 Your Natural Rhythms',
        description: 'Energy peaks at ${ultradianRhythm.peakTimes.join(", ")} and dips around ${ultradianRhythm.dipTimes.join(", ")}',
        type: InsightType.pattern,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: ultradianRhythm.confidence,
        actionSteps: [
          'Plan challenging tasks for your peak windows: ${ultradianRhythm.peakTimes.join(", ")}',
          'Schedule buffer time before your dip periods',
          'Consider meal timing adjustments for sustained energy',
          'Use dip times for restful activities',
        ],
        data: ultradianRhythm.data,
        actionText: 'Rhythm Sync',
      ));
    }

    return insights;
  }

  /// Generate goal integration insights
  static Future<List<SmartInsight>> _generateGoalIntegration(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Achievement path analysis
    final achievementPath = _analyzeAchievementPath(data);
    if (achievementPath != null) {
      insights.add(SmartInsight(
        id: 'achievement_path_${now.millisecondsSinceEpoch}',
        title: '🏆 Your Achievement Path',
        description: 'Current Goal: Raise average from ${achievementPath.currentAvg.toStringAsFixed(1)} to ${achievementPath.targetAvg.toStringAsFixed(1)}',
        type: InsightType.achievement,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: 0.9,
        actionSteps: achievementPath.strategy,
        data: achievementPath.data,
        actionText: 'View Progress',
        actionRoute: '/goals',
      ));
    }

    return insights;
  }

  /// Generate relationship mapping insights
  static Future<List<SmartInsight>> _generateRelationshipMapping(
      ComprehensiveAnalysisData data,
      ) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Social mood matrix
    final socialMatrix = _analyzeSocialMoodMatrix(data);
    if (socialMatrix != null) {
      insights.add(SmartInsight(
        id: 'social_mood_matrix_${now.millisecondsSinceEpoch}',
        title: '👥 Social Mood Matrix',
        description: '${socialMatrix.bestActivity} activities boost your mood by ${socialMatrix.boost.toStringAsFixed(1)} points vs ${socialMatrix.worstActivity}',
        type: InsightType.actionable,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: socialMatrix.confidence,
        actionSteps: [
          'Plan more ${socialMatrix.bestActivity.toLowerCase()} activities',
          'Optimal social: ${socialMatrix.optimalFrequency} positive interactions/day',
          'Limit ${socialMatrix.worstActivity.toLowerCase()} when mood is already low',
          'Schedule ${socialMatrix.bestActivity.toLowerCase()} activities before challenging days',
        ],
        data: socialMatrix.data,
        actionText: 'Social Plan',
      ));
    }

    return insights;
  }

  // Helper methods for pattern detection and analysis

  static MorningAdvantage? _detectMorningAdvantage(ComprehensiveAnalysisData data) {
    final morningMoods = <double>[];
    final eveningMoods = <double>[];

    for (final day in data.days) {
      if (day.moods.containsKey(0)) morningMoods.add(day.moods[0]!);
      if (day.moods.containsKey(2)) eveningMoods.add(day.moods[2]!);
    }

    if (morningMoods.length < 5 || eveningMoods.length < 5) return null;

    final morningAvg = morningMoods.reduce((a, b) => a + b) / morningMoods.length;
    final eveningAvg = eveningMoods.reduce((a, b) => a + b) / eveningMoods.length;
    final advantage = morningAvg - eveningAvg;

    if (advantage >= 1.5) {
      return MorningAdvantage(
        morningAvg: morningAvg,
        eveningAvg: eveningAvg,
        advantage: advantage,
        confidence: min((advantage / 3.0) * (morningMoods.length / 10.0), 1.0),
      );
    }

    return null;
  }

  static SleepSweetSpot? _detectSleepSweetSpot(ComprehensiveAnalysisData data) {
    final sleepMoodPairs = <double, List<double>>{};

    for (final day in data.days) {
      if (day.correlationData?.sleepQuality != null) {
        final nextDay = data.days
            .where((d) => d.date.isAfter(day.date) &&
            d.date.difference(day.date).inDays == 1)
            .firstOrNull;

        if (nextDay != null && nextDay.averageMood > 0) {
          final sleepQuality = day.correlationData!.sleepQuality!;
          sleepMoodPairs.putIfAbsent(sleepQuality, () => []).add(nextDay.averageMood);
        }
      }
    }

    if (sleepMoodPairs.length < 3) return null;

    // Find optimal sleep quality
    double bestQuality = 0;
    double bestMood = 0;
    for (final entry in sleepMoodPairs.entries) {
      if (entry.value.length >= 2) {
        final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avgMood > bestMood) {
          bestMood = avgMood;
          bestQuality = entry.key;
        }
      }
    }

    if (bestQuality > 0 && bestMood > 6.5) {
      return SleepSweetSpot(
        optimalQuality: bestQuality,
        resultingMood: bestMood,
        confidence: min(sleepMoodPairs[bestQuality]!.length / 5.0, 1.0),
        data: {
          'optimalSleepQuality': bestQuality,
          'resultingMood': bestMood,
          'sampleSize': sleepMoodPairs[bestQuality]!.length,
        },
      );
    }

    return null;
  }

  static TomorrowForecast? _predictTomorrowMood(ComprehensiveAnalysisData data) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowWeekday = tomorrow.weekday;

    // Get historical data for this weekday
    final weekdayMoods = <double>[];
    for (final day in data.days) {
      if (day.date.weekday == tomorrowWeekday && day.averageMood > 0) {
        weekdayMoods.add(day.averageMood);
      }
    }

    if (weekdayMoods.length < 3) return null;

    final predictedMood = weekdayMoods.reduce((a, b) => a + b) / weekdayMoods.length;
    final confidence = min(weekdayMoods.length / 8.0, 1.0);
    final dayName = _getDayName(tomorrowWeekday);

    String prediction;
    List<String> actionSteps;

    if (predictedMood >= 7.5) {
      prediction = '$dayName looks promising! Your average for ${dayName}s is ${predictedMood.toStringAsFixed(1)}/10. Perfect day to tackle bigger challenges.';
      actionSteps = [
        'Schedule that important task you\'ve been postponing',
        'Plan something special to celebrate your good day',
        'Set an ambitious but achievable goal for the day',
        'Use this energy for creative or challenging work',
      ];
    } else if (predictedMood <= 5.5) {
      prediction = '$dayName tends to be challenging for you (avg ${predictedMood.toStringAsFixed(1)}/10). Let\'s prepare your mood armor!';
      actionSteps = [
        'Set up your environment for success the night before',
        'Plan extra self-care activities',
        'Schedule easier tasks and build in breaks',
        'Have your comfort strategies ready',
        'Lower expectations and be extra kind to yourself',
      ];
    } else {
      prediction = '$dayName typically rates ${predictedMood.toStringAsFixed(1)}/10 for you. A steady day with room for improvement.';
      actionSteps = [
        'Add one small mood-boosting activity to your day',
        'Plan one thing to look forward to',
        'Set realistic expectations and celebrate small wins',
        'Practice your most effective stress management technique',
      ];
    }

    return TomorrowForecast(
      predictedMood: predictedMood,
      prediction: prediction,
      confidence: confidence,
      actionSteps: actionSteps,
      reasoning: 'Based on ${weekdayMoods.length} previous ${dayName}s',
    );
  }

  static List<EarlyWarning> _detectEarlyWarnings(ComprehensiveAnalysisData data) {
    final warnings = <EarlyWarning>[];

    // Detect declining mood trend
    final recentDays = data.days.where((day) =>
        day.date.isAfter(DateTime.now().subtract(const Duration(days: 14)))).toList();

    if (recentDays.length >= 10) {
      final recentMoods = recentDays.map((day) => day.averageMood).where((mood) => mood > 0).toList();

      if (recentMoods.length >= 8) {
        final firstHalf = recentMoods.take(recentMoods.length ~/ 2).toList();
        final secondHalf = recentMoods.skip(recentMoods.length ~/ 2).toList();

        final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
        final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

        if (firstAvg - secondAvg >= 1.2) {
          warnings.add(EarlyWarning(
            type: 'declining_trend',
            title: 'Mood Decline Detected',
            description: 'Your mood has dropped ${(firstAvg - secondAvg).toStringAsFixed(1)} points over the past two weeks.',
            confidence: min((firstAvg - secondAvg) / 2.0, 1.0),
            preventativeActions: [
              'Consider what has changed in your routine recently',
              'Prioritize sleep and self-care activities',
              'Reach out to supportive people in your life',
              'Schedule activities that usually lift your mood',
              'Consider professional support if this continues',
            ],
            data: {
              'firstHalfAvg': firstAvg,
              'secondHalfAvg': secondAvg,
              'decline': firstAvg - secondAvg,
            },
          ));
        }
      }
    }

    return warnings;
  }

  static List<CustomMoodHack> _generateCustomMoodHacks(ComprehensiveAnalysisData data) {
    final hacks = <CustomMoodHack>[];

    // Exercise magic analysis
    final exerciseHack = _analyzeExerciseMagic(data);
    if (exerciseHack != null) hacks.add(exerciseHack);

    // Social supercharger analysis
    final socialHack = _analyzeSocialSupercharger(data);
    if (socialHack != null) hacks.add(socialHack);

    // Sleep optimization hack
    final sleepHack = _analyzeSleepOptimization(data);
    if (sleepHack != null) hacks.add(sleepHack);

    return hacks;
  }

  static CustomMoodHack? _analyzeExerciseMagic(ComprehensiveAnalysisData data) {
    final exerciseMoodMap = <String, List<double>>{};

    for (final day in data.days) {
      if (day.correlationData?.exerciseLevel != null && day.averageMood > 0) {
        final exerciseLevel = day.correlationData!.exerciseLevel!.name;
        exerciseMoodMap.putIfAbsent(exerciseLevel, () => []).add(day.averageMood);
      }
    }

    if (exerciseMoodMap.length < 2) return null;

    // Find best exercise level
    String bestLevel = '';
    double bestMood = 0;
    double baselineMood = exerciseMoodMap['none']?.reduce((a, b) => a + b) ?? 0;
    baselineMood = baselineMood > 0 ? baselineMood / (exerciseMoodMap['none']?.length ?? 1) : 6.0;

    for (final entry in exerciseMoodMap.entries) {
      if (entry.key != 'none' && entry.value.length >= 3) {
        final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avgMood > bestMood) {
          bestMood = avgMood;
          bestLevel = entry.key;
        }
      }
    }

    final boost = bestMood - baselineMood;
    if (boost >= 0.8) {
      return CustomMoodHack(
        type: 'exercise',
        title: 'Exercise Magic',
        description: '${_getExerciseName(bestLevel)} gives you +${boost.toStringAsFixed(1)} boost vs baseline',
        confidence: min(exerciseMoodMap[bestLevel]!.length / 5.0, 1.0),
        actionSteps: _getExerciseActionSteps(bestLevel),
        data: {
          'bestLevel': bestLevel,
          'boost': boost,
          'bestMood': bestMood,
          'baselineMood': baselineMood,
        },
      );
    }

    return null;
  }

  static WeatherImpact? _analyzeWeatherImpact(ComprehensiveAnalysisData data) {
    final weatherMoodMap = <String, List<double>>{};

    for (final day in data.days) {
      if (day.correlationData?.weather != null && day.averageMood > 0) {
        final weather = day.correlationData!.weather!.name;
        weatherMoodMap.putIfAbsent(weather, () => []).add(day.averageMood);
      }
    }

    if (weatherMoodMap.length < 2) return null;

    // Find worst weather condition
    String worstCondition = '';
    double worstMood = 10.0;
    String bestCondition = '';
    double bestMood = 0.0;

    for (final entry in weatherMoodMap.entries) {
      if (entry.value.length >= 3) {
        final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avgMood < worstMood) {
          worstMood = avgMood;
          worstCondition = entry.key;
        }
        if (avgMood > bestMood) {
          bestMood = avgMood;
          bestCondition = entry.key;
        }
      }
    }

    final impact = bestMood - worstMood;
    if (impact >= 1.0) {
      return WeatherImpact(
        worstCondition: _getWeatherName(worstCondition),
        bestCondition: _getWeatherName(bestCondition),
        impact: impact,
        confidence: 0.8,
        actionSteps: _getWeatherActionSteps(worstCondition),
        data: {
          'worstCondition': worstCondition,
          'worstMood': worstMood,
          'bestCondition': bestCondition,
          'bestMood': bestMood,
          'impact': impact,
        },
      );
    }

    return null;
  }

  // Data gathering and helper methods

  static Future<ComprehensiveAnalysisData> _gatherComprehensiveData() async {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 90)); // 3 months of data
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

  // Utility methods

  static int _getPriorityScore(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.critical: return 4;
      case AlertPriority.high: return 3;
      case AlertPriority.medium: return 2;
      case AlertPriority.low: return 1;
    }
  }

  static String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  static String _getCurrentSeason(int month) {
    if (month >= 3 && month <= 5) return 'Spring';
    if (month >= 6 && month <= 8) return 'Summer';
    if (month >= 9 && month <= 11) return 'Fall';
    return 'Winter';
  }

  static String _getWeatherName(String condition) {
    switch (condition) {
      case 'sunny': return 'sunny';
      case 'cloudy': return 'cloudy';
      case 'rainy': return 'rainy';
      case 'stormy': return 'stormy';
      case 'snowy': return 'snowy';
      case 'foggy': return 'foggy';
      default: return condition;
    }
  }

  static String _getExerciseName(String level) {
    switch (level) {
      case 'light': return 'Light activity';
      case 'moderate': return 'Moderate exercise';
      case 'intense': return 'Intense workouts';
      default: return level;
    }
  }

  static List<String> _getExerciseActionSteps(String level) {
    switch (level) {
      case 'light':
        return [
          'Take a 15-minute walk during lunch',
          'Try gentle yoga or stretching',
          'Dance to your favorite songs',
          'Do light gardening or household activities',
        ];
      case 'moderate':
        return [
          'Schedule 30-45 minutes of cardio 3x this week',
          'Try a fitness class or online workout',
          'Go for a bike ride or swim',
          'Play an active sport you enjoy',
        ];
      case 'intense':
        return [
          'Book that high-intensity class',
          'Set a new personal fitness challenge',
          'Try interval training or weightlifting',
          'Join a competitive sports activity',
        ];
      default:
        return ['Find ways to move your body that feel good'];
    }
  }

  static List<String> _getWeatherActionSteps(String condition) {
    switch (condition) {
      case 'rainy':
        return [
          'Set up a cozy indoor space with warm lighting',
          'Plan engaging indoor activities (puzzles, books, crafts)',
          'Use a light therapy lamp for 20-30 minutes',
          'Schedule video calls with friends',
          'Prepare comfort foods and warm beverages',
        ];
      case 'cloudy':
        return [
          'Increase indoor lighting brightness',
          'Take vitamin D supplement',
          'Plan energizing indoor activities',
          'Practice gratitude journaling',
          'Get outside even for brief moments',
        ];
      default:
        return [
          'Prepare indoor mood-boosting activities',
          'Ensure good lighting environment',
          'Stay connected with others',
        ];
    }
  }

  static List<String> _getSeasonalActionSteps(String season) {
    switch (season) {
      case 'Winter':
        return [
          'Use light therapy lamp daily',
          'Plan warm, cozy activities',
          'Increase vitamin D intake',
          'Schedule more social connections',
          'Create warming routines',
        ];
      case 'Spring':
        return [
          'Embrace outdoor activities as weather improves',
          'Plan gradual activity increases',
          'Address any seasonal allergies',
          'Take advantage of increasing daylight',
        ];
      case 'Fall':
        return [
          'Prepare for shorter days with lighting',
          'Maintain outdoor activities while possible',
          'Plan cozy indoor alternatives',
          'Focus on immune system support',
        ];
      default:
        return [
          'Adapt activities to seasonal changes',
          'Maintain consistent routines',
          'Stay connected with supportive people',
        ];
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
      Logger.smartInsightService('Error loading enhanced insights: $e');
      return [];
    }
  }

  static Future<void> _updateLastAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAnalysisKey, DateTime.now().toIso8601String());
  }

  static Future<void> _updateUserPatterns(ComprehensiveAnalysisData data) async {
    // Store learned patterns for future predictions
    final patterns = {
      'lastUpdated': DateTime.now().toIso8601String(),
      'dataPoints': data.days.length,
      'averageMood': data.days.isNotEmpty
          ? data.days.map((d) => d.averageMood).where((m) => m > 0).fold(0.0, (a, b) => a + b) /
          data.days.where((d) => d.averageMood > 0).length
          : 0.0,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPatternsKey, jsonEncode(patterns));
  }

  // Placeholder methods for additional analysis (to be implemented)
  static CustomMoodHack? _analyzeSocialSupercharger(ComprehensiveAnalysisData data) => null;
  static CustomMoodHack? _analyzeSleepOptimization(ComprehensiveAnalysisData data) => null;
  static SeasonalPattern? _detectSeasonalPattern(ComprehensiveAnalysisData data) => null;
  static UltradianRhythm? _detectUltradianRhythm(ComprehensiveAnalysisData data) => null;
  static AchievementPath? _analyzeAchievementPath(ComprehensiveAnalysisData data) => null;
  static SocialMoodMatrix? _analyzeSocialMoodMatrix(ComprehensiveAnalysisData data) => null;
}

// Data classes for enhanced analysis

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

class MorningAdvantage {
  final double morningAvg;
  final double eveningAvg;
  final double advantage;
  final double confidence;

  MorningAdvantage({
    required this.morningAvg,
    required this.eveningAvg,
    required this.advantage,
    required this.confidence,
  });
}

class SleepSweetSpot {
  final double optimalQuality;
  final double resultingMood;
  final double confidence;
  final Map<String, dynamic> data;

  SleepSweetSpot({
    required this.optimalQuality,
    required this.resultingMood,
    required this.confidence,
    required this.data,
  });
}

class TomorrowForecast {
  final double predictedMood;
  final String prediction;
  final double confidence;
  final List<String> actionSteps;
  final String reasoning;

  TomorrowForecast({
    required this.predictedMood,
    required this.prediction,
    required this.confidence,
    required this.actionSteps,
    required this.reasoning,
  });
}

class EarlyWarning {
  final String type;
  final String title;
  final String description;
  final double confidence;
  final List<String> preventativeActions;
  final Map<String, dynamic> data;

  EarlyWarning({
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    required this.preventativeActions,
    required this.data,
  });
}

class CustomMoodHack {
  final String type;
  final String title;
  final String description;
  final double confidence;
  final List<String> actionSteps;
  final Map<String, dynamic> data;

  CustomMoodHack({
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    required this.actionSteps,
    required this.data,
  });
}

class WeatherImpact {
  final String worstCondition;
  final String bestCondition;
  final double impact;
  final double confidence;
  final List<String> actionSteps;
  final Map<String, dynamic> data;

  WeatherImpact({
    required this.worstCondition,
    required this.bestCondition,
    required this.impact,
    required this.confidence,
    required this.actionSteps,
    required this.data,
  });
}

// Placeholder classes for additional features
class SeasonalPattern {
  final String challengingSeason;
  final double challengingAvg;
  final double confidence;
  final Map<String, dynamic> data;

  SeasonalPattern({
    required this.challengingSeason,
    required this.challengingAvg,
    required this.confidence,
    required this.data,
  });
}

class UltradianRhythm {
  final List<String> peakTimes;
  final List<String> dipTimes;
  final double confidence;
  final Map<String, dynamic> data;

  UltradianRhythm({
    required this.peakTimes,
    required this.dipTimes,
    required this.confidence,
    required this.data,
  });
}

class AchievementPath {
  final double currentAvg;
  final double targetAvg;
  final List<String> strategy;
  final Map<String, dynamic> data;

  AchievementPath({
    required this.currentAvg,
    required this.targetAvg,
    required this.strategy,
    required this.data,
  });
}

class SocialMoodMatrix {
  final String bestActivity;
  final String worstActivity;
  final double boost;
  final String optimalFrequency;
  final double confidence;
  final Map<String, dynamic> data;

  SocialMoodMatrix({
    required this.bestActivity,
    required this.worstActivity,
    required this.boost,
    required this.optimalFrequency,
    required this.confidence,
    required this.data,
  });
}