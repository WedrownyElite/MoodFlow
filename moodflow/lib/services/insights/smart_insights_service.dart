// lib/services/insights/smart_insights_service.dart
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
  };

  factory SmartInsight.fromJson(Map<String, dynamic> json) => SmartInsight(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: InsightType.values.firstWhere((e) => e.name == json['type']),
    priority: AlertPriority.values.firstWhere((e) => e.name == json['priority']),
    createdAt: DateTime.parse(json['createdAt']),
    data: json['data'] ?? {},
    isRead: json['isRead'] ?? false,
    actionText: json['actionText'],
    actionRoute: json['actionRoute'],
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
  final String trend; // 'improving', 'declining', 'stable'
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

  /// Generate all types of insights
  static Future<List<SmartInsight>> generateInsights({bool forceRefresh = false}) async {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Check if we need to run analysis (once per day)
    if (!forceRefresh && !await _shouldRunAnalysis()) {
      return await loadInsights();
    }

    Logger.analyticsService('🧠 Generating smart insights...');

    // Pattern analysis
    insights.addAll(await _analyzePatterns());

    // Achievement detection
    insights.addAll(await _detectAchievements());

    // Concern monitoring
    insights.addAll(await _detectConcerns());

    // Celebration moments
    insights.addAll(await _detectCelebrations());

    // Suggestions based on user data
    insights.addAll(await _generateSuggestions());

    // Save insights
    await _saveInsights(insights);
    await _updateLastAnalysis();

    Logger.analyticsService('✅ Generated ${insights.length} insights');
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

  static Future<List<SmartInsight>> _analyzeTimeOfDayPatterns(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final insights = <SmartInsight>[];
    final timeSegmentTotals = <int, List<double>>{0: [], 1: [], 2: []};

    // Collect all mood ratings by time segment
    moodData.values.forEach((dayMoods) {
      dayMoods.forEach((segment, mood) {
        timeSegmentTotals[segment]!.add(mood);
      });
    });

    // Calculate averages
    final averages = <int, double>{};
    timeSegmentTotals.forEach((segment, moods) {
      if (moods.isNotEmpty) {
        averages[segment] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (averages.length >= 2) {
      // Find best and worst times
      final sortedTimes = averages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final best = sortedTimes.first;
      final worst = sortedTimes.last;
      final difference = best.value - worst.value;

      if (difference >= 1.5) { // Significant difference
        final timeNames = ['morning', 'midday', 'evening'];

        insights.add(SmartInsight(
          id: 'time_pattern_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Your ${timeNames[best.key]} energy is strongest',
          description: 'You consistently feel ${difference.toStringAsFixed(1)} points better in the ${timeNames[best.key]} (${best.value.toStringAsFixed(1)}/10) vs ${timeNames[worst.key]} (${worst.value.toStringAsFixed(1)}/10)',
          type: InsightType.pattern,
          priority: AlertPriority.medium,
          createdAt: DateTime.now(),
          data: {
            'bestTime': best.key,
            'worstTime': worst.key,
            'difference': difference,
          },
          actionText: 'Plan important tasks',
          actionRoute: '/trends',
        ));
      }
    }

    return insights;
  }

  static Future<List<SmartInsight>> _analyzeWeeklyPatterns(
      Map<DateTime, Map<int, double>> moodData,
      ) async {
    final insights = <SmartInsight>[];
    final weekdayMoods = <int, List<double>>{};

    // Group by weekday (1=Monday, 7=Sunday)
    moodData.forEach((date, dayMoods) {
      final weekday = date.weekday;
      final dayAverage = dayMoods.values.reduce((a, b) => a + b) / dayMoods.length;
      weekdayMoods.putIfAbsent(weekday, () => []).add(dayAverage);
    });

    // Calculate weekday averages
    final weekdayAverages = <int, double>{};
    weekdayMoods.forEach((weekday, moods) {
      if (moods.length >= 2) {
        weekdayAverages[weekday] = moods.reduce((a, b) => a + b) / moods.length;
      }
    });

    if (weekdayAverages.length >= 5) { // Need most days of week
      final sortedDays = weekdayAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestDay = sortedDays.first;
      final worstDay = sortedDays.last;
      final difference = bestDay.value - worstDay.value;

      if (difference >= 1.2) {
        final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

        insights.add(SmartInsight(
          id: 'weekday_pattern_${DateTime.now().millisecondsSinceEpoch}',
          title: '${dayNames[bestDay.key]}s are your best days',
          description: 'Your mood averages ${bestDay.value.toStringAsFixed(1)} on ${dayNames[bestDay.key]}s vs ${worstDay.value.toStringAsFixed(1)} on ${dayNames[worstDay.key]}s',
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
      dailyAverages[date] = dayMoods.values.reduce((a, b) => a + b) / dayMoods.length;
    });

    final sortedDates = dailyAverages.keys.toList()..sort();
    final recentWeek = sortedDates.reversed.take(7).toList();
    final previousWeek = sortedDates.reversed.skip(7).take(7).toList();

    if (recentWeek.length >= 5 && previousWeek.length >= 5) {
      final recentAvg = recentWeek
          .map((date) => dailyAverages[date]!)
          .reduce((a, b) => a + b) / recentWeek.length;

      final previousAvg = previousWeek
          .map((date) => dailyAverages[date]!)
          .reduce((a, b) => a + b) / previousWeek.length;

      final change = recentAvg - previousAvg;

      if (change.abs() >= 1.0) {
        if (change > 0) {
          insights.add(SmartInsight(
            id: 'trend_improving_${DateTime.now().millisecondsSinceEpoch}',
            title: '📈 Your mood is improving!',
            description: 'This week you\'re averaging ${recentAvg.toStringAsFixed(1)}, up ${change.toStringAsFixed(1)} points from last week (${previousAvg.toStringAsFixed(1)})',
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
            description: 'This week you\'re averaging ${recentAvg.toStringAsFixed(1)}, down ${change.abs().toStringAsFixed(1)} points from last week. Consider some self-care activities.',
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
          description: '${percentage.round()}% of your recent days had mood ratings of 7+. You\'re doing amazing!',
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
        description: 'You\'ve had $lowMoodDays days recently with consistently low mood ratings. Remember that it\'s okay to ask for help.',
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
      final correlation = await CorrelationDataService.loadCorrelationData(date);
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
        final avgSleep = recentSleep.reduce((a, b) => a + b) / recentSleep.length;

        if (avgSleep <= 4.0) {
          insights.add(SmartInsight(
            id: 'poor_sleep_concern_${now.millisecondsSinceEpoch}',
            title: 'Your sleep quality needs attention',
            description: 'Your recent sleep quality averages ${avgSleep.toStringAsFixed(1)}/10. Poor sleep can significantly impact your mood.',
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
    if (todayMoods.length == 3 && todayMoods.values.every((mood) => mood >= 8.0)) {
      insights.add(SmartInsight(
        id: 'perfect_day_${now.millisecondsSinceEpoch}',
        title: '🎉 Perfect day!',
        description: 'All your mood ratings today are 8+ (${todayMoods.values.map((m) => m.toStringAsFixed(1)).join(", ")}). Celebrate this amazing day!',
        type: InsightType.celebration,
        priority: AlertPriority.high,
        createdAt: now,
        data: {'moods': todayMoods},
      ));
    }

    // Personal best celebration
    final last90Days = await _getLast90DaysMoodData();
    if (last90Days.isNotEmpty && todayMoods.isNotEmpty) {
      final todayAvg = todayMoods.values.reduce((a, b) => a + b) / todayMoods.length;
      final historicalAverages = last90Days.values
          .map((dayMoods) => dayMoods.values.reduce((a, b) => a + b) / dayMoods.length)
          .toList()..sort();

      if (historicalAverages.length >= 30 && todayAvg >= historicalAverages.last) {
        insights.add(SmartInsight(
          id: 'personal_best_${now.millisecondsSinceEpoch}',
          title: '🏆 Personal best!',
          description: 'Today\'s average mood (${todayAvg.toStringAsFixed(1)}) ties your highest in the last 90 days!',
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
            description = 'Based on your data, ${correlation.description.toLowerCase()}. Plan outdoor activities on sunny days!';
            break;
          case 'sleep':
            title = '😴 Sleep matters';
            description = correlation.description + '. Consider a consistent bedtime routine.';
            break;
          case 'exercise':
            title = '🏃‍♀️ Move your body';
            description = correlation.description + '. Even light activity can help!';
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
          title: '🔥 Don\'t break your ${currentStreak}-day streak!',
          body: 'You\'ve been doing great with consistent tracking. Log your mood before bed.',
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
        body: 'This is typically your best ${timeNames[bestTime]} time. How are you feeling?',
        time: NotificationTime(reminderTimes[bestTime], 0),
        payload: jsonEncode({
          'type': 'optimal_time_reminder',
          'segment': bestTime,
        }),
      );
    }
  }

  /// Generate weekly summary
  static Future<WeeklySummary> generateWeeklySummary([DateTime? weekStart]) async {
    weekStart ??= DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
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
    weekMoodData.values.forEach((dayMoods) {
      dailyAverages.add(dayMoods.values.reduce((a, b) => a + b) / dayMoods.length);
    });

    final averageMood = dailyAverages.reduce((a, b) => a + b) / dailyAverages.length;
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
      highlights.add('Great week! Your average mood was ${averageMood.toStringAsFixed(1)}');
    }

    if (weekMoodData.length >= 6) {
      highlights.add('Excellent consistency - logged ${weekMoodData.length}/7 days');
    }

    if (bestDay >= 9.0) {
      highlights.add('You had an amazing day with ${bestDay.toStringAsFixed(1)} average mood!');
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
  static Future<Map<DateTime, Map<int, double>>> _getLast30DaysMoodData() async {
    return await _getMoodDataForPeriod(30);
  }

  static Future<Map<DateTime, Map<int, double>>> _getLast14DaysMoodData() async {
    return await _getMoodDataForPeriod(14);
  }

  static Future<Map<DateTime, Map<int, double>>> _getLast90DaysMoodData() async {
    return await _getMoodDataForPeriod(90);
  }

  static Future<Map<DateTime, Map<int, double>>> _getMoodDataForPeriod(int days) async {
    final moodData = <DateTime, Map<int, double>>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
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
    // This would use the same logic as in your existing streak calculation
    // For now, returning 0 as a placeholder
    return 0;
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