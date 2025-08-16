import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mood_data_service.dart';
import 'mood_analytics_service.dart';

class NotificationService {
  static const String _settingsKey = 'notification_settings';
  static const String _lastNotificationKey = 'last_notification_date';

  /// Save notification settings
  static Future<void> saveSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Load notification settings
  static Future<NotificationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    
    if (settingsJson == null) {
      return NotificationSettings.defaultSettings();
    }
    
    try {
      final Map<String, dynamic> json = jsonDecode(settingsJson);
      return NotificationSettings.fromJson(json);
    } catch (_) {
      return NotificationSettings.defaultSettings();
    }
  }

  /// Check if user should receive a notification
  static Future<NotificationContent?> shouldShowNotification() async {
    final settings = await loadSettings();
    if (!settings.enabled) return null;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lastNotificationDate = prefs.getString(_lastNotificationKey);
    
    // Don't show multiple notifications on the same day
    if (lastNotificationDate != null) {
      final lastDate = DateTime.parse(lastNotificationDate);
      if (lastDate.year == now.year && 
          lastDate.month == now.month && 
          lastDate.day == now.day) {
        return null;
      }
    }

    // Check if it's time for a notification
    final currentHour = now.hour;
    bool shouldNotify = false;
    String timeSegment = '';

    if (settings.morningReminder && 
        currentHour >= settings.morningTime.hour &&
        currentHour < settings.morningTime.hour + 2) {
      shouldNotify = true;
      timeSegment = 'morning';
    } else if (settings.middayReminder && 
               currentHour >= settings.middayTime.hour &&
               currentHour < settings.middayTime.hour + 2) {
      shouldNotify = true;
      timeSegment = 'midday';
    } else if (settings.eveningReminder && 
               currentHour >= settings.eveningTime.hour &&
               currentHour < settings.eveningTime.hour + 2) {
      shouldNotify = true;
      timeSegment = 'evening';
    }

    if (!shouldNotify) return null;

    // Check if user already logged mood for this segment today
    final segmentIndex = timeSegment == 'morning' ? 0 : 
                        timeSegment == 'midday' ? 1 : 2;
    final existingMood = await MoodDataService.loadMood(now, segmentIndex);
    
    if (existingMood != null && existingMood['rating'] != null) {
      return null; // Already logged
    }

    // Generate notification content
    final content = await _generateNotificationContent(timeSegment);
    
    // Mark notification as sent
    await prefs.setString(_lastNotificationKey, now.toIso8601String());
    
    return content;
  }

  /// Generate personalized notification content
  static Future<NotificationContent> _generateNotificationContent(String timeSegment) async {
    final predictions = await MoodAnalyticsService.generatePredictions();
    final goals = await MoodAnalyticsService.loadGoals();
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    
    String title;
    String body;
    String emoji;

    // Time-based messages
    switch (timeSegment) {
      case 'morning':
        title = "Good morning! ☀️";
        emoji = "☀️";
        break;
      case 'midday':
        title = "Midday check-in ⚡";
        emoji = "⚡";
        break;
      case 'evening':
        title = "Evening reflection 🌙";
        emoji = "🌙";
        break;
      default:
        title = "How are you feeling?";
        emoji = "😊";
    }

    // Personalized body messages
    final messages = <String>[];

    // Prediction-based messages
    if (predictions.bestTimeOfDay != null) {
      final segments = ['morning', 'midday', 'evening'];
      final bestTime = segments[predictions.bestTimeOfDay!];
      if (bestTime == timeSegment) {
        messages.add("This is usually your best time of day!");
      }
    }

    // Goal-based messages
    if (activeGoals.isNotEmpty) {
      final goal = activeGoals.first;
      messages.add("Keep working on your goal: ${goal.title}");
    }

    // Day of week predictions
    if (predictions.bestDayOfWeek != null) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final today = DateTime.now().weekday;
      if (today == predictions.bestDayOfWeek) {
        messages.add("${weekdays[today - 1]}s are usually great for you!");
      }
    }

    // Default messages
    final defaultMessages = [
      "How's your $timeSegment going?",
      "Take a moment to check in with yourself",
      "Your mood matters - let's log it!",
      "A quick mood check helps track your wellbeing",
      "How are you feeling right now?",
    ];

    body = messages.isNotEmpty 
        ? messages.first 
        : (defaultMessages..shuffle()).first;

    return NotificationContent(
      title: title,
      body: body,
      emoji: emoji,
      timeSegment: timeSegment,
    );
  }

  /// Get streak information for notifications
  static Future<int> getCurrentStreak() async {
    int streak = 0;
    final today = DateTime.now();
    
    for (int i = 0; i < 365; i++) { // Max 1 year
      final date = today.subtract(Duration(days: i));
      bool hasAnyMood = false;
      
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(date, segment);
        if (mood != null && mood['rating'] != null) {
          hasAnyMood = true;
          break;
        }
      }
      
      if (hasAnyMood) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }

  /// Generate motivational messages based on recent mood patterns
  static Future<List<String>> getMotivationalMessages() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 7));
    final report = await MoodAnalyticsService.generateReport(startDate, endDate);
    
    final messages = <String>[];
    
    if (report.overallAverage > 7) {
      messages.add("You've been feeling great lately! Keep up the positive energy! 🌟");
    } else if (report.overallAverage < 4) {
      messages.add("It's been a tough week. Remember, it's okay to have difficult times. 💙");
    }
    
    if (report.totalDaysLogged >= 7) {
      messages.add("Amazing! You've logged your mood every day this week! 🔥");
    }
    
    return messages;
  }
}

class NotificationSettings {
  final bool enabled;
  final bool morningReminder;
  final bool middayReminder;
  final bool eveningReminder;
  final TimeOfDay morningTime;
  final TimeOfDay middayTime;
  final TimeOfDay eveningTime;
  final bool streakReminders;
  final bool goalReminders;
  final bool motivationalQuotes;

  NotificationSettings({
    required this.enabled,
    required this.morningReminder,
    required this.middayReminder,
    required this.eveningReminder,
    required this.morningTime,
    required this.middayTime,
    required this.eveningTime,
    required this.streakReminders,
    required this.goalReminders,
    required this.motivationalQuotes,
  });

  static NotificationSettings defaultSettings() {
    return NotificationSettings(
      enabled: true,
      morningReminder: true,
      middayReminder: true,
      eveningReminder: true,
      morningTime: const TimeOfDay(hour: 9, minute: 0),
      middayTime: const TimeOfDay(hour: 13, minute: 0),
      eveningTime: const TimeOfDay(hour: 19, minute: 0),
      streakReminders: true,
      goalReminders: true,
      motivationalQuotes: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'morningReminder': morningReminder,
      'middayReminder': middayReminder,
      'eveningReminder': eveningReminder,
      'morningTime': '${morningTime.hour}:${morningTime.minute}',
      'middayTime': '${middayTime.hour}:${middayTime.minute}',
      'eveningTime': '${eveningTime.hour}:${eveningTime.minute}',
      'streakReminders': streakReminders,
      'goalReminders': goalReminders,
      'motivationalQuotes': motivationalQuotes,
    };
  }

  static NotificationSettings fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      morningReminder: json['morningReminder'] ?? true,
      middayReminder: json['middayReminder'] ?? true,
      eveningReminder: json['eveningReminder'] ?? true,
      morningTime: parseTime(json['morningTime'] ?? '9:0'),
      middayTime: parseTime(json['middayTime'] ?? '13:0'),
      eveningTime: parseTime(json['eveningTime'] ?? '19:0'),
      streakReminders: json['streakReminders'] ?? true,
      goalReminders: json['goalReminders'] ?? true,
      motivationalQuotes: json['motivationalQuotes'] ?? true,
    );
  }
}

class NotificationContent {
  final String title;
  final String body;
  final String emoji;
  final String timeSegment;

  NotificationContent({
    required this.title,
    required this.body,
    required this.emoji,
    required this.timeSegment,
  });
}

class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}