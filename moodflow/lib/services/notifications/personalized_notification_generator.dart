import '../data/mood_data_service.dart';
import '../data/mood_trends_service.dart';

class PersonalizedNotificationGenerator {
  /// Generate personalized morning notification based on recent mood history
  static Future<NotificationMessage> generateMorningMessage() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));

    // Check yesterday's mood
    final yesterdayMoods = await _getDayAverageMood(yesterday);

    // Check last week's trend
    final weekTrend = await _getWeekTrend(lastWeek, DateTime.now());

    // Check streak
    final streak = await _getCurrentStreak();

    // Check if user logged yesterday
    final loggedYesterday = yesterdayMoods != null;

    if (!loggedYesterday && streak >= 3) {
      return NotificationMessage(
        title: '🔥 Don\'t break your $streak-day streak!',
        body: 'You missed yesterday - but it\'s a new day! Log your morning mood to get back on track.',
      );
    }

    if (yesterdayMoods != null && yesterdayMoods < 5.0) {
      return NotificationMessage(
        title: '🌅 Fresh start today',
        body: 'Yesterday was tough (${yesterdayMoods.toStringAsFixed(1)}/10). Take it slow, be kind to yourself, and check in this morning.',
      );
    }

    if (weekTrend == TrendType.declining && weekTrend != TrendType.stable) {
      return NotificationMessage(
        title: '💙 Gentle morning check-in',
        body: 'This week has been challenging. How are you feeling this morning? Your wellbeing matters.',
      );
    }

    if (yesterdayMoods != null && yesterdayMoods >= 8.0) {
      return NotificationMessage(
        title: '☀️ Great momentum!',
        body: 'Yesterday was wonderful (${yesterdayMoods.toStringAsFixed(1)}/10)! Let\'s keep that positive energy going.',
      );
    }

    if (streak >= 7) {
      return NotificationMessage(
        title: '🔥 $streak-day streak! Morning check-in',
        body: 'You\'re doing amazing! How\'s your morning going?',
      );
    }

    // Default message
    return NotificationMessage(
      title: '☀️ Good morning!',
      body: 'How are you feeling this morning?',
    );
  }

  /// Generate personalized midday notification
  static Future<NotificationMessage> generateMiddayMessage() async {
    final today = DateTime.now();
    final morning = await MoodDataService.loadMood(today, 0);
    final streak = await _getCurrentStreak();

    if (morning == null) {
      return NotificationMessage(
        title: '⚡ Midday catch-up',
        body: 'You haven\'t logged today yet. Take a quick moment to check in with yourself.',
      );
    }

    final morningRating = (morning['rating'] as num).toDouble();

    if (morningRating < 5.0) {
      return NotificationMessage(
        title: '💚 Midday check-in',
        body: 'Your morning was rough. How are you feeling now? Things can change.',
      );
    }

    if (morningRating >= 8.0) {
      return NotificationMessage(
        title: '⚡ Riding high!',
        body: 'Your morning was great! How\'s your momentum at midday?',
      );
    }

    if (streak >= 14) {
      return NotificationMessage(
        title: '🌟 $streak-day champion!',
        body: 'Your consistency is inspiring. Midday check-in time!',
      );
    }

    return NotificationMessage(
      title: '⚡ Midday moment',
      body: 'How\'s your day going? Take a moment to check in.',
    );
  }

  /// Generate personalized evening notification
  static Future<NotificationMessage> generateEveningMessage() async {
    final today = DateTime.now();
    final morning = await MoodDataService.loadMood(today, 0);
    final midday = await MoodDataService.loadMood(today, 1);

    final hasLogged = morning != null || midday != null;

    if (!hasLogged) {
      return NotificationMessage(
        title: '🌙 Evening reflection',
        body: 'You haven\'t logged today. Take a moment to reflect on your day before bed.',
      );
    }

    final dayMoods = <double>[];
    if (morning != null) dayMoods.add((morning['rating'] as num).toDouble());
    if (midday != null) dayMoods.add((midday['rating'] as num).toDouble());

    if (dayMoods.isNotEmpty) {
      final avg = dayMoods.reduce((a, b) => a + b) / dayMoods.length;

      if (avg < 5.0) {
        return NotificationMessage(
          title: '🌙 Gentle evening check-in',
          body: 'Today was difficult. How are you feeling now? Remember to be kind to yourself.',
        );
      }

      if (avg >= 8.0) {
        return NotificationMessage(
          title: '✨ Beautiful day!',
          body: 'Today was wonderful! Complete your evening reflection to celebrate.',
        );
      }
    }

    return NotificationMessage(
      title: '🌙 Evening reflection',
      body: 'How was your evening? Time to wind down and reflect.',
    );
  }

  /// Generate streak continuation notification with escalating messages
  static Future<NotificationMessage> generateStreakMessage(int streak) async {
    if (streak >= 100) {
      return NotificationMessage(
        title: '🏆 LEGENDARY: $streak days!',
        body: 'You\'re a mood tracking legend! Your dedication is absolutely incredible. Keep this remarkable streak alive!',
      );
    } else if (streak >= 90) {
      return NotificationMessage(
        title: '👑 Royal streak: $streak days!',
        body: 'You\'re approaching legendary status! Just 10 more days to 100. Don\'t stop now!',
      );
    } else if (streak >= 75) {
      return NotificationMessage(
        title: '💎 Diamond streak: $streak days!',
        body: 'Absolutely phenomenal! Your consistency is diamond-level. Keep shining!',
      );
    } else if (streak >= 60) {
      return NotificationMessage(
        title: '🌟 Platinum streak: $streak days!',
        body: 'Two months of dedication! You\'re building an amazing habit. Keep going strong!',
      );
    } else if (streak >= 50) {
      return NotificationMessage(
        title: '🥇 Gold streak: $streak days!',
        body: 'Fifty days of consistency! You\'re unstoppable. Your commitment is inspiring!',
      );
    } else if (streak >= 40) {
      return NotificationMessage(
        title: '🔥 On fire: $streak days!',
        body: 'Over a month of amazing consistency! You\'re building something special here.',
      );
    } else if (streak >= 30) {
      return NotificationMessage(
        title: '🎯 One month strong: $streak days!',
        body: 'A full month of dedication! Your habit is solidifying. Keep the momentum!',
      );
    } else if (streak >= 25) {
      return NotificationMessage(
        title: '⚡ Power streak: $streak days!',
        body: 'You\'re in the zone! 25 days of consistency. Five more to 30!',
      );
    } else if (streak >= 20) {
      return NotificationMessage(
        title: '🌠 Incredible: $streak days!',
        body: 'Twenty days of commitment! You\'re building an unbreakable habit.',
      );
    } else if (streak >= 15) {
      return NotificationMessage(
        title: '💪 Two weeks+: $streak days!',
        body: 'Your consistency is outstanding! Keep this fantastic streak going!',
      );
    } else if (streak >= 10) {
      return NotificationMessage(
        title: '🎉 Double digits: $streak days!',
        body: 'Ten days strong! You\'re proving your commitment. Don\'t break it now!',
      );
    } else if (streak >= 7) {
      return NotificationMessage(
        title: '🔥 One week: $streak days!',
        body: 'A full week of mood tracking! You\'re building a great habit!',
      );
    } else if (streak >= 5) {
      return NotificationMessage(
        title: '⭐ $streak-day streak!',
        body: 'You\'re doing great! Keep your streak alive with today\'s check-in.',
      );
    } else if (streak >= 3) {
      return NotificationMessage(
        title: '🔥 $streak days in a row!',
        body: 'You\'re building momentum! Don\'t break your streak now.',
      );
    }

    return NotificationMessage(
      title: '📝 Daily check-in',
      body: 'Keep building your habit! Log your mood today.',
    );
  }

  /// Generate notification for users who haven't logged in a while
  static Future<NotificationMessage> generateReturnMessage(int daysSinceLastLog) async {
    final lastStreak = await _getLastStreakBeforeGap();

    if (daysSinceLastLog >= 30) {
      return NotificationMessage(
        title: '💙 We miss you!',
        body: 'It\'s been a month since your last check-in. Your mental wellness journey is waiting. Come back anytime.',
      );
    } else if (daysSinceLastLog >= 14) {
      return NotificationMessage(
        title: '🌱 Ready for a fresh start?',
        body: 'It\'s been $daysSinceLastLog days. No judgment - just a gentle reminder that you can restart anytime.',
      );
    } else if (daysSinceLastLog >= 7) {
      if (lastStreak >= 7) {
        return NotificationMessage(
          title: '💔 Your $lastStreak-day streak misses you',
          body: 'It\'s been a week. That amazing streak you built? You can start a new one today.',
        );
      }
      return NotificationMessage(
        title: '🌅 New week, fresh start',
        body: 'It\'s been $daysSinceLastLog days. How about checking in with yourself today?',
      );
    } else if (daysSinceLastLog >= 3) {
      return NotificationMessage(
        title: '👋 Come back!',
        body: 'It\'s been $daysSinceLastLog days since your last mood log. Your wellbeing matters - check in today?',
      );
    }

    return NotificationMessage(
      title: '📝 Quick check-in?',
      body: 'You haven\'t logged in $daysSinceLastLog days. Take a moment for yourself.',
    );
  }

  // Helper methods

  static Future<double?> _getDayAverageMood(DateTime date) async {
    final moods = <double>[];
    for (int segment = 0; segment < 3; segment++) {
      final mood = await MoodDataService.loadMood(date, segment);
      if (mood != null && mood['rating'] != null) {
        moods.add((mood['rating'] as num).toDouble());
      }
    }
    return moods.isEmpty ? null : moods.reduce((a, b) => a + b) / moods.length;
  }

  static Future<TrendType> _getWeekTrend(DateTime start, DateTime end) async {
    final trends = await MoodTrendsService.getMoodTrends(
      startDate: start,
      endDate: end,
    );

    if (trends.length < 3) return TrendType.stable;

    final firstHalf = trends.take(trends.length ~/ 2).toList();
    final secondHalf = trends.skip(trends.length ~/ 2).toList();

    double firstAvg = 0;
    int firstCount = 0;
    for (final day in firstHalf) {
      final moods = day.moods.values.where((m) => m != null).cast<double>();
      if (moods.isNotEmpty) {
        firstAvg += moods.reduce((a, b) => a + b) / moods.length;
        firstCount++;
      }
    }

    double secondAvg = 0;
    int secondCount = 0;
    for (final day in secondHalf) {
      final moods = day.moods.values.where((m) => m != null).cast<double>();
      if (moods.isNotEmpty) {
        secondAvg += moods.reduce((a, b) => a + b) / moods.length;
        secondCount++;
      }
    }

    if (firstCount == 0 || secondCount == 0) return TrendType.stable;

    firstAvg /= firstCount;
    secondAvg /= secondCount;

    final difference = secondAvg - firstAvg;

    if (difference <= -1.0) return TrendType.declining;
    if (difference >= 1.0) return TrendType.improving;
    return TrendType.stable;
  }

  static Future<int> _getCurrentStreak() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 365));
    final trends = await MoodTrendsService.getMoodTrends(
      startDate: startDate,
      endDate: endDate,
    );
    final stats = await MoodTrendsService.calculateStatisticsForDateRange(
      trends,
      startDate,
      endDate,
    );
    return stats.currentStreak;
  }

  static Future<int> _getLastStreakBeforeGap() async {
    // This would require tracking streak history
    // For now, return 0
    return 0;
  }
}

class NotificationMessage {
  final String title;
  final String body;

  NotificationMessage({required this.title, required this.body});
}

enum TrendType {
  declining,
  stable,
  improving,
}