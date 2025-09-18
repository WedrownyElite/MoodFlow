// lib/services/insights/pattern_detection_helper.dart
import 'dart:math';
import 'package:mood_flow/services/data/correlation_data_service.dart';

import 'smart_insights_service.dart';

// Data classes for pattern insights
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

class PatternInsight {
  final String description;
  final double confidence;
  final List<String> actionSteps;
  final Map<String, dynamic> data;

  PatternInsight({
    required this.description,
    required this.confidence,
    required this.actionSteps,
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

/// Helper methods for pattern detection in smart insights
class PatternDetectionHelper {

  /// Detect morning advantage patterns
  static MorningAdvantage? detectMorningAdvantage(ComprehensiveAnalysisData data) {
    final morningMoods = <double>[];
    final eveningMoods = <double>[];

    for (final day in data.days) {
      if (day.moods.containsKey(0) && day.moods[0] != null) {
        morningMoods.add(day.moods[0]!);
      }
      if (day.moods.containsKey(2) && day.moods[2] != null) {
        eveningMoods.add(day.moods[2]!);
      }
    }

    if (morningMoods.length < 3 || eveningMoods.length < 3) return null;

    final morningAvg = morningMoods.reduce((a, b) => a + b) / morningMoods.length;
    final eveningAvg = eveningMoods.reduce((a, b) => a + b) / eveningMoods.length;
    final advantage = morningAvg - eveningAvg;

    if (advantage >= 1.0) {
      return MorningAdvantage(
        morningAvg: morningAvg,
        eveningAvg: eveningAvg,
        advantage: advantage,
        confidence: min((advantage / 2.5), 1.0),
      );
    }

    return null;
  }

  /// Analyze sleep patterns
  static PatternInsight? analyzeSleepPattern(ComprehensiveAnalysisData data) {
    final sleepMoodPairs = <double, List<double>>{};

    for (final day in data.days) {
      if (day.correlationData?.sleepQuality != null && day.averageMood > 0) {
        final sleepQuality = day.correlationData!.sleepQuality!;
        sleepMoodPairs.putIfAbsent(sleepQuality, () => []).add(day.averageMood);
      }
    }

    if (sleepMoodPairs.length < 3) return null;

    // Find correlation between sleep and mood
    final entries = sleepMoodPairs.entries.where((e) => e.value.length >= 2).toList();
    if (entries.length < 3) return null;

    entries.sort((a, b) => a.key.compareTo(b.key));

    final lowSleep = entries.first;
    final highSleep = entries.last;

    final lowAvg = lowSleep.value.reduce((a, b) => a + b) / lowSleep.value.length;
    final highAvg = highSleep.value.reduce((a, b) => a + b) / highSleep.value.length;

    final difference = highAvg - lowAvg;

    if (difference >= 0.8) {
      return PatternInsight(
        description: 'Better sleep quality boosts your mood by ${difference.toStringAsFixed(1)} points on average',
        confidence: min(difference / 2.0, 1.0),
        actionSteps: [
          'Target ${highSleep.key.toStringAsFixed(1)}/10 sleep quality consistently',
          'Track what helps you achieve better sleep',
          'Consider optimizing your sleep environment',
          'Maintain a consistent bedtime routine',
        ],
        data: {
          'lowSleepQuality': lowSleep.key,
          'highSleepQuality': highSleep.key,
          'moodDifference': difference,
        },
      );
    }

    return null;
  }

  /// Analyze exercise patterns
  static PatternInsight? analyzeExercisePattern(ComprehensiveAnalysisData data) {
    final exerciseMoodMap = <String, List<double>>{};

    for (final day in data.days) {
      if (day.correlationData?.exerciseLevel != null && day.averageMood > 0) {
        final exerciseLevel = day.correlationData!.exerciseLevel!.name;
        exerciseMoodMap.putIfAbsent(exerciseLevel, () => []).add(day.averageMood);
      }
    }

    if (exerciseMoodMap.length < 2) return null;

    // Find best and worst exercise levels
    String bestLevel = '';
    String worstLevel = '';
    double bestMood = 0;
    double worstMood = 10;

    for (final entry in exerciseMoodMap.entries) {
      if (entry.value.length >= 2) {
        final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avgMood > bestMood) {
          bestMood = avgMood;
          bestLevel = entry.key;
        }
        if (avgMood < worstMood) {
          worstMood = avgMood;
          worstLevel = entry.key;
        }
      }
    }

    final difference = bestMood - worstMood;
    if (difference >= 0.8) {
      return PatternInsight(
        description: '${_getExerciseName(bestLevel)} activities boost your mood by ${difference.toStringAsFixed(1)} points vs ${_getExerciseName(worstLevel)}',
        confidence: min(difference / 2.0, 1.0),
        actionSteps: _getExerciseActionSteps(bestLevel),
        data: {
          'bestLevel': bestLevel,
          'worstLevel': worstLevel,
          'moodDifference': difference,
          'bestMood': bestMood,
          'worstMood': worstMood,
        },
      );
    }

    return null;
  }

  /// Analyze weekly patterns
  static PatternInsight? analyzeWeeklyPattern(ComprehensiveAnalysisData data) {
    final weekdayMoods = <int, List<double>>{};

    for (final day in data.days) {
      if (day.averageMood > 0) {
        final weekday = day.date.weekday;
        weekdayMoods.putIfAbsent(weekday, () => []).add(day.averageMood);
      }
    }

    if (weekdayMoods.length < 5) return null;

    // Calculate averages for each weekday
    final weekdayAverages = <int, double>{};
    for (final entry in weekdayMoods.entries) {
      if (entry.value.length >= 2) {
        weekdayAverages[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }

    if (weekdayAverages.length < 3) return null;

    // Find best and worst days
    final sortedDays = weekdayAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bestDay = sortedDays.first;
    final worstDay = sortedDays.last;
    final difference = bestDay.value - worstDay.value;

    if (difference >= 1.0) {
      final bestDayName = _getDayName(bestDay.key);
      final worstDayName = _getDayName(worstDay.key);

      return PatternInsight(
        description: 'Your mood varies by day: ${bestDayName}s average ${bestDay.value.toStringAsFixed(1)}, while ${worstDayName}s average ${worstDay.value.toStringAsFixed(1)}',
        confidence: min(difference / 2.5, 1.0),
        actionSteps: [
          'Plan important activities on ${bestDayName}s when you feel strongest',
          'Schedule self-care and lighter tasks on ${worstDayName}s',
          'Prepare mood-boosting activities for challenging days',
          'Notice what makes ${bestDayName}s great and replicate it',
        ],
        data: {
          'bestDay': bestDay.key,
          'worstDay': worstDay.key,
          'bestDayName': bestDayName,
          'worstDayName': worstDayName,
          'difference': difference,
        },
      );
    }

    return null;
  }

  /// Predict tomorrow's mood
  static TomorrowForecast? predictTomorrowMood(ComprehensiveAnalysisData data) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowWeekday = tomorrow.weekday;

    // Get historical data for this weekday
    final weekdayMoods = <double>[];
    for (final day in data.days) {
      if (day.date.weekday == tomorrowWeekday && day.averageMood > 0) {
        weekdayMoods.add(day.averageMood);
      }
    }

    if (weekdayMoods.length < 2) return null;

    final predictedMood = weekdayMoods.reduce((a, b) => a + b) / weekdayMoods.length;
    final confidence = min(weekdayMoods.length / 5.0, 1.0);
    final dayName = _getDayName(tomorrowWeekday);

    String prediction;
    List<String> actionSteps;

    if (predictedMood >= 7.5) {
      prediction = '$dayName looks great! Your average for ${dayName}s is ${predictedMood.toStringAsFixed(1)}/10.';
      actionSteps = [
        'Plan something special to make the most of your good day',
        'Tackle that challenging task you\'ve been postponing',
        'Share your positive energy with others',
      ];
    } else if (predictedMood <= 5.5) {
      prediction = '$dayName tends to be challenging (avg ${predictedMood.toStringAsFixed(1)}/10). Let\'s prepare!';
      actionSteps = [
        'Plan extra self-care activities',
        'Schedule easier tasks and build in breaks',
        'Prepare your favorite comfort strategies',
        'Be extra kind to yourself',
      ];
    } else {
      prediction = '$dayName typically rates ${predictedMood.toStringAsFixed(1)}/10 for you.';
      actionSteps = [
        'Add one mood-boosting activity to your day',
        'Plan something to look forward to',
        'Practice your favorite stress management technique',
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

  /// Detect early warning signs
  static PatternInsight? detectEarlyWarnings(ComprehensiveAnalysisData data) {
    if (data.days.length < 14) return null;

    // Get recent 14 days with mood data
    final recentDays = data.days
        .where((day) => day.averageMood > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (recentDays.length < 10) return null;

    final recent14 = recentDays.take(14).toList();

    // Split into two weeks
    final thisWeek = recent14.take(7).toList();
    final lastWeek = recent14.skip(7).take(7).toList();

    if (thisWeek.length < 4 || lastWeek.length < 4) return null;

    final thisWeekAvg = thisWeek.map((d) => d.averageMood).reduce((a, b) => a + b) / thisWeek.length;
    final lastWeekAvg = lastWeek.map((d) => d.averageMood).reduce((a, b) => a + b) / lastWeek.length;

    final decline = lastWeekAvg - thisWeekAvg;

    if (decline >= 1.2) {
      return PatternInsight(
        description: 'Your mood has declined by ${decline.toStringAsFixed(1)} points over the past two weeks. This might be a good time to focus on self-care.',
        confidence: min(decline / 2.0, 1.0),
        actionSteps: [
          'Reflect on what has changed in your routine recently',
          'Prioritize sleep and stress management',
          'Reach out to supportive friends or family',
          'Consider scheduling activities that usually boost your mood',
          'Be extra kind to yourself during this time',
        ],
        data: {
          'decline': decline,
          'thisWeekAverage': thisWeekAvg,
          'lastWeekAverage': lastWeekAvg,
        },
      );
    }

    return null;
  }

  /// Analyze weather impact patterns
  static PatternInsight? analyzeWeatherImpact(ComprehensiveAnalysisData data) {
    final weatherMoodMap = <String, List<double>>{};

    for (final day in data.days) {
      if (day.correlationData?.weather != null && day.averageMood > 0) {
        final weather = day.correlationData!.weather!.name;
        weatherMoodMap.putIfAbsent(weather, () => []).add(day.averageMood);
      }
    }

    if (weatherMoodMap.length < 2) return null;

    // Find weather with most impact
    String bestWeather = '';
    String worstWeather = '';
    double bestMood = 0;
    double worstMood = 10;

    for (final entry in weatherMoodMap.entries) {
      if (entry.value.length >= 2) {
        final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avgMood > bestMood) {
          bestMood = avgMood;
          bestWeather = entry.key;
        }
        if (avgMood < worstMood) {
          worstMood = avgMood;
          worstWeather = entry.key;
        }
      }
    }

    final impact = bestMood - worstMood;
    if (impact >= 1.0) {
      return PatternInsight(
        description: '${_getWeatherName(worstWeather)} weather affects your mood negatively (${worstMood.toStringAsFixed(1)}) vs ${_getWeatherName(bestWeather)} days (${bestMood.toStringAsFixed(1)})',
        confidence: min(impact / 2.5, 1.0),
        actionSteps: _getWeatherActionSteps(worstWeather),
        data: {
          'bestWeather': bestWeather,
          'worstWeather': worstWeather,
          'impact': impact,
          'bestMood': bestMood,
          'worstMood': worstMood,
        },
      );
    }

    return null;
  }

  /// Analyze progress patterns
  static PatternInsight? analyzeProgress(ComprehensiveAnalysisData data) {
    if (data.days.length < 21) return null;

    // Split data into 3 periods
    final sortedDays = data.days.where((d) => d.averageMood > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sortedDays.length < 15) return null;

    final third = sortedDays.length ~/ 3;
    final early = sortedDays.take(third).toList();
    final middle = sortedDays.skip(third).take(third).toList();
    final recent = sortedDays.skip(third * 2).toList();

    final earlyAvg = early.map((d) => d.averageMood).reduce((a, b) => a + b) / early.length;
    final middleAvg = middle.map((d) => d.averageMood).reduce((a, b) => a + b) / middle.length;
    final recentAvg = recent.map((d) => d.averageMood).reduce((a, b) => a + b) / recent.length;

    final totalImprovement = recentAvg - earlyAvg;
    final recentTrend = recentAvg - middleAvg;

    if (totalImprovement >= 0.8) {
      return PatternInsight(
        description: 'Great progress! Your mood has improved by ${totalImprovement.toStringAsFixed(1)} points over time (from ${earlyAvg.toStringAsFixed(1)} to ${recentAvg.toStringAsFixed(1)})',
        confidence: min(totalImprovement / 2.0, 1.0),
        actionSteps: [
          'Celebrate this amazing progress - you\'re doing great!',
          'Reflect on what changes have helped the most',
          'Keep doing what\'s working for you',
          'Consider sharing your success with someone supportive',
        ],
        data: {
          'totalImprovement': totalImprovement,
          'earlyAverage': earlyAvg,
          'recentAverage': recentAvg,
          'recentTrend': recentTrend,
        },
      );
    } else if (totalImprovement <= -0.8) {
      return PatternInsight(
        description: 'Your mood trend has declined by ${(-totalImprovement).toStringAsFixed(1)} points recently. This might be a good time to revisit what was working before.',
        confidence: min((-totalImprovement) / 2.0, 1.0),
        actionSteps: [
          'Review what was different during your better periods',
          'Consider if any life changes might be affecting your mood',
          'Focus on basic self-care: sleep, nutrition, movement',
          'Reach out for support if you need it',
        ],
        data: {
          'totalDecline': -totalImprovement,
          'earlyAverage': earlyAvg,
          'recentAverage': recentAvg,
        },
      );
    }

    return null;
  }

  /// Generate custom mood hacks
  static List<CustomMoodHack> generateCustomMoodHacks(ComprehensiveAnalysisData data) {
    final hacks = <CustomMoodHack>[];

    // Social activity hack
    final socialHack = _analyzeSocialPattern(data);
    if (socialHack != null) hacks.add(socialHack);

    // Time of day hack
    final timeHack = _analyzeTimeOfDayPattern(data);
    if (timeHack != null) hacks.add(timeHack);

    return hacks;
  }

  /// Calculate current streak
  static Future<int> calculateCurrentStreak(ComprehensiveAnalysisData data) async {
    final sortedDays = data.days.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    final today = DateTime.now();
    DateTime currentDate = DateTime(today.year, today.month, today.day);

    for (int i = 0; i < 100; i++) { // Check up to 100 days back
      final dayData = sortedDays.where((d) =>
      d.date.year == currentDate.year &&
          d.date.month == currentDate.month &&
          d.date.day == currentDate.day).firstOrNull;

      if (dayData != null && dayData.moods.isNotEmpty) {
        streak++;
      } else {
        break;
      }

      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  // Helper methods for social patterns
  static CustomMoodHack? _analyzeSocialPattern(ComprehensiveAnalysisData data) {
    final socialMoodMap = <String, List<double>>{};

    for (final day in data.days) {
      // FIXED: Handle socialActivities as a list
      if (day.correlationData?.socialActivities != null &&
          day.correlationData!.socialActivities.isNotEmpty &&
          day.averageMood > 0) {
        // Get the primary social activity (first non-none activity, or first if all are none)
        final primaryActivity = day.correlationData!.socialActivities
            .firstWhere((activity) => activity != SocialActivity.none,
            orElse: () => day.correlationData!.socialActivities.first);
        final social = primaryActivity.name;
        socialMoodMap.putIfAbsent(social, () => []).add(day.averageMood);
      }
    }

    if (socialMoodMap.length < 2) return null;

    // Find best social activity
    String bestActivity = '';
    double bestMood = 0;

    for (final entry in socialMoodMap.entries) {
      if (entry.value.length >= 2) {
        final avgMood = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avgMood > bestMood) {
          bestMood = avgMood;
          bestActivity = entry.key;
        }
      }
    }

    final baseline = socialMoodMap['none']?.reduce((a, b) => a + b) ?? 0;
    final baselineAvg = baseline > 0 ? baseline / (socialMoodMap['none']?.length ?? 1) : 6.0;
    final boost = bestMood - baselineAvg;

    if (boost >= 0.8) {
      return CustomMoodHack(
        type: 'social',
        title: 'Social Supercharger',
        description: '${_getSocialActivityName(bestActivity)} activities give you a +${boost.toStringAsFixed(1)} mood boost',
        confidence: min(boost / 2.0, 1.0),
        actionSteps: [
          'Plan more ${_getSocialActivityName(bestActivity).toLowerCase()} activities this week',
          'Schedule regular social time to maintain this boost',
          'Reach out to people who make you feel good',
          'Balance social time with alone time as needed',
        ],
        data: {
          'bestActivity': bestActivity,
          'boost': boost,
          'bestMood': bestMood,
          'baseline': baselineAvg,
        },
      );
    }

    return null;
  }

  static CustomMoodHack? _analyzeTimeOfDayPattern(ComprehensiveAnalysisData data) {
    final timeSegmentMoods = <int, List<double>>{0: [], 1: [], 2: []};

    for (final day in data.days) {
      for (final entry in day.moods.entries) {
        timeSegmentMoods[entry.key]!.add(entry.value);
      }
    }

    // Find best time segment
    int bestSegment = 0;
    double bestAvg = 0;

    for (final entry in timeSegmentMoods.entries) {
      if (entry.value.length >= 5) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        if (avg > bestAvg) {
          bestAvg = avg;
          bestSegment = entry.key;
        }
      }
    }

    final worstSegment = timeSegmentMoods.entries
        .where((e) => e.value.length >= 3 && e.key != bestSegment)
        .map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b) / e.value.length))
        .fold(MapEntry(0, 10.0), (prev, curr) => curr.value < prev.value ? curr : prev);

    final advantage = bestAvg - worstSegment.value;

    if (advantage >= 0.8) {
      final timeNames = ['Morning', 'Midday', 'Evening'];

      return CustomMoodHack(
        type: 'timeofday',
        title: '${timeNames[bestSegment]} Magic',
        description: 'You feel ${advantage.toStringAsFixed(1)} points better in the ${timeNames[bestSegment].toLowerCase()} vs ${timeNames[worstSegment.key].toLowerCase()}',
        confidence: min(advantage / 2.0, 1.0),
        actionSteps: [
          'Schedule important tasks during your ${timeNames[bestSegment].toLowerCase()} peak',
          'Save easier activities for your ${timeNames[worstSegment.key].toLowerCase()} low periods',
          'Plan mood-boosting activities for challenging times',
          'Use your energy wisely by matching tasks to your natural rhythms',
        ],
        data: {
          'bestSegment': bestSegment,
          'worstSegment': worstSegment.key,
          'advantage': advantage,
          'bestTime': timeNames[bestSegment],
        },
      );
    }

    return null;
  }

  // Utility helper methods
  static String _getExerciseName(String level) {
    switch (level) {
      case 'none': return 'Rest days';
      case 'light': return 'Light activity';
      case 'moderate': return 'Moderate exercise';
      case 'intense': return 'Intense workouts';
      default: return level;
    }
  }

  static String _getSocialActivityName(String activity) {
    switch (activity) {
      case 'none': return 'Solo time';
      case 'friends': return 'Friends';
      case 'family': return 'Family time';
      case 'work': return 'Work social';
      case 'party': return 'Parties/events';
      case 'date': return 'Dating';
      default: return activity;
    }
  }

  static String _getWeatherName(String condition) {
    switch (condition) {
      case 'sunny': return 'Sunny';
      case 'cloudy': return 'Cloudy';
      case 'rainy': return 'Rainy';
      case 'stormy': return 'Stormy';
      case 'snowy': return 'Snowy';
      case 'foggy': return 'Foggy';
      default: return condition;
    }
  }

  static String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  static List<String> _getExerciseActionSteps(String level) {
    switch (level) {
      case 'light':
        return [
          'Take a 15-20 minute walk during lunch breaks',
          'Try gentle yoga or stretching routines',
          'Dance to your favorite music for 10 minutes',
          'Do light household activities or gardening',
        ];
      case 'moderate':
        return [
          'Schedule 30-45 minutes of cardio 3-4 times this week',
          'Try a fitness class or follow online workout videos',
          'Go for bike rides or swimming sessions',
          'Play active sports you enjoy with friends',
        ];
      case 'intense':
        return [
          'Book that high-intensity fitness class you\'ve been considering',
          'Set a new personal fitness challenge or goal',
          'Try interval training or weightlifting sessions',
          'Join a competitive sports league or activity',
        ];
      default:
        return [
          'Find ways to move your body that feel enjoyable',
          'Start with small, manageable activities',
          'Listen to your body and adjust as needed',
        ];
    }
  }

  static List<String> _getWeatherActionSteps(String condition) {
    switch (condition) {
      case 'rainy':
        return [
          'Create a cozy indoor environment with warm lighting',
          'Plan engaging indoor activities (books, puzzles, crafts)',
          'Use a light therapy lamp for 20-30 minutes',
          'Schedule video calls with friends and family',
          'Prepare comfort foods and warm beverages',
        ];
      case 'cloudy':
        return [
          'Increase indoor lighting to combat gloominess',
          'Consider a vitamin D supplement',
          'Plan energizing indoor activities',
          'Practice gratitude journaling',
          'Get outside for brief moments when possible',
        ];
      case 'snowy':
        return [
          'Embrace winter activities if you enjoy them',
          'Focus on creating warmth and coziness indoors',
          'Use bright lighting to combat seasonal effects',
          'Plan warming activities like hot baths or tea',
          'Connect with others to combat isolation',
        ];
      case 'stormy':
        return [
          'Create a calm, secure indoor environment',
          'Practice relaxation techniques like deep breathing',
          'Engage in soothing activities like reading or music',
          'Avoid overstimulating activities during storms',
          'Focus on grounding exercises if you feel anxious',
        ];
      default:
        return [
          'Prepare indoor mood-boosting activities as backup',
          'Ensure you have good lighting in your environment',
          'Stay connected with supportive people',
          'Have comfort strategies ready for challenging weather',
        ];
    }
  }
}