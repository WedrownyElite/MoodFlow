// lib/services/ai/mood_coach_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mood_data_service.dart';
import '../data/correlation_data_service.dart';
import '../data/mood_trends_service.dart';
import '../utils/logger.dart';

class MoodCoachService {
  static const String _enabledKey = 'ai_coach_enabled';
  static const String _conversationHistoryKey = 'coach_conversation_history';
  static const String _disclaimerAcceptedKey = 'coach_disclaimer_accepted';
  static const String _apiKeyKey = 'openai_api_key';
  static const int _maxHistoryLength = 20; // Keep last 20 messages

  /// Check if coach is enabled and properly configured
  static Future<bool> isCoachEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_enabledKey) ?? false;
      final disclaimerAccepted = prefs.getBool(_disclaimerAcceptedKey) ?? false;
      return isEnabled && disclaimerAccepted;
    } catch (e) {
      Logger.aiService('❌ Error checking coach status: $e');
      return false;
    }
  }

  /// Enable the AI coach after disclaimer acceptance
  static Future<bool> enableCoach() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      await prefs.setBool(_disclaimerAcceptedKey, true);
      Logger.aiService('✅ AI Coach enabled');
      return true;
    } catch (e) {
      Logger.aiService('❌ Error enabling coach: $e');
      return false;
    }
  }

  /// Disable the AI coach
  static Future<void> disableCoach() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, false);
      await prefs.remove(_conversationHistoryKey);
      Logger.aiService('🚫 AI Coach disabled');
    } catch (e) {
      Logger.aiService('❌ Error disabling coach: $e');
    }
  }

  /// Get welcome message with disclaimer
  static Future<CoachMessage?> getWelcomeMessage() async {
    if (!await isCoachEnabled()) return null;

    return CoachMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: '''Hello! I'm your AI Mood Coach. 

⚠️ IMPORTANT DISCLAIMER: I'm an AI assistant created to help analyze your mood patterns. I am NOT a licensed therapist, psychologist, or medical professional. My insights are for informational purposes only and should never replace professional mental health care.

If you're experiencing a mental health crisis, please contact:
• Emergency services: 911
• Crisis Text Line: Text HOME to 741741
• National Suicide Prevention Lifeline: 988

Now, I'm here to help you understand your mood patterns. What would you like to explore?''',
      isUser: false,
      timestamp: DateTime.now(),
      suggestions: [
        'What patterns do you see in my mood data?',
        'How can I improve my mood today?',
        'What factors affect my mood the most?',
        'Help me understand my recent trends',
      ],
    );
  }

  /// Process user message and generate AI response
  static Future<CoachMessage> processUserMessage(String message) async {
    try {
      Logger.aiService('🤖 Processing user message: ${message.substring(0, math.min(50, message.length))}...');

      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 1, milliseconds: 500));

      // Save user message to history
      await _saveMessageToHistory(CoachMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));

      // Analyze user's mood data
      final moodAnalysis = await _analyzeMoodData();

      // Generate contextual response based on message and data
      final response = await _generateResponse(message, moodAnalysis);

      // Save AI response to history
      await _saveMessageToHistory(response);

      Logger.aiService('✅ Generated coach response');
      return response;

    } catch (e) {
      Logger.aiService('❌ Error processing message: $e');
      return CoachMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: 'I apologize, but I\'m having trouble processing your message right now. Please try again in a moment.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
    }
  }

  /// Analyze user's mood data for context
  static Future<MoodAnalysisContext> _analyzeMoodData() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      // Get mood trends
      final trends = await MoodTrendsService.getMoodTrends(
        startDate: startDate,
        endDate: endDate,
      );

      final statistics = await MoodTrendsService.calculateStatisticsForDateRange(
          trends, startDate, endDate
      );

      // Get recent mood entries
      final recentMoods = <double>[];
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        for (int segment = 0; segment < 3; segment++) {
          final mood = await MoodDataService.loadMood(date, segment);
          if (mood != null && mood['rating'] != null) {
            recentMoods.add((mood['rating'] as num).toDouble());
          }
        }
      }

      // Get correlation data
      final recentCorrelationData = <CorrelationData>[];
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final correlation = await CorrelationDataService.loadCorrelationData(date);
        if (correlation != null) {
          recentCorrelationData.add(correlation);
        }
      }

      return MoodAnalysisContext(
        overallAverage: statistics.overallAverage,
        currentStreak: statistics.currentStreak,
        daysLogged: statistics.daysLogged,
        recentMoods: recentMoods,
        recentCorrelationData: recentCorrelationData,
        bestTimeSegment: statistics.bestTimeSegment,
        timeSegmentAverages: statistics.timeSegmentAverages,
      );

    } catch (e) {
      Logger.aiService('❌ Error analyzing mood data: $e');
      return MoodAnalysisContext.empty();
    }
  }

  /// Generate contextual response based on user message and mood data
  static Future<CoachMessage> _generateResponse(
      String userMessage, MoodAnalysisContext context) async {

    final lowercaseMessage = userMessage.toLowerCase();
    final now = DateTime.now();

    // Pattern recognition responses
    if (lowercaseMessage.contains('pattern') || lowercaseMessage.contains('trends')) {
      return _generatePatternResponse(context, now);
    }

    if (lowercaseMessage.contains('improve') || lowercaseMessage.contains('better') ||
        lowercaseMessage.contains('help')) {
      return _generateImprovementResponse(context, now);
    }

    if (lowercaseMessage.contains('today') || lowercaseMessage.contains('right now') ||
        lowercaseMessage.contains('feeling')) {
      return _generateTodayResponse(context, now);
    }

    if (lowercaseMessage.contains('sleep') || lowercaseMessage.contains('tired')) {
      return _generateSleepResponse(context, now);
    }

    if (lowercaseMessage.contains('stress') || lowercaseMessage.contains('work') ||
        lowercaseMessage.contains('anxious')) {
      return _generateStressResponse(context, now);
    }

    if (lowercaseMessage.contains('exercise') || lowercaseMessage.contains('activity')) {
      return _generateExerciseResponse(context, now);
    }

    // Default contextual response
    return _generateDefaultResponse(context, now);
  }

  static CoachMessage _generatePatternResponse(MoodAnalysisContext context, DateTime now) {
    final suggestions = <String>[];
    final insights = <String>[];

    if (context.timeSegmentAverages.isNotEmpty) {
      final bestSegment = context.bestTimeSegment;
      final segmentNames = ['morning', 'midday', 'evening'];
      insights.add('You tend to feel best in the ${segmentNames[bestSegment]} (average ${context.timeSegmentAverages[bestSegment]?.toStringAsFixed(1) ?? "N/A"}/10).');
      suggestions.add('Schedule important tasks in the ${segmentNames[bestSegment]}');
    }

    if (context.currentStreak > 0) {
      insights.add('You\'ve been consistently logging for ${context.currentStreak} days - that\'s excellent self-awareness!');
      suggestions.add('Keep up your consistent logging streak');
    }

    if (context.recentMoods.isNotEmpty) {
      final recentAvg = context.recentMoods.reduce((a, b) => a + b) / context.recentMoods.length;
      if (recentAvg > context.overallAverage + 0.5) {
        insights.add('Your recent mood (${recentAvg.toStringAsFixed(1)}) has been higher than your overall average (${context.overallAverage.toStringAsFixed(1)}) - great progress!');
      } else if (recentAvg < context.overallAverage - 0.5) {
        insights.add('Your recent mood has been lower than usual. This might be a good time for extra self-care.');
        suggestions.add('Try one mood-boosting activity today');
      }
    }

    // Weather patterns from correlation data
    final weatherInsights = _analyzeWeatherPatterns(context.recentCorrelationData);
    if (weatherInsights.isNotEmpty) {
      insights.add(weatherInsights);
    }

    final insightText = insights.isNotEmpty
        ? insights.join('\n\n')
        : 'I\'m analyzing your patterns. Keep logging regularly for better insights!';

    suggestions.addAll([
      'What should I focus on this week?',
      'Tell me about my sleep patterns',
      'How does weather affect my mood?',
    ]);

    return CoachMessage(
      id: 'pattern_response_${now.millisecondsSinceEpoch}',
      text: '📊 **Pattern Analysis**\n\n$insightText\n\n*Remember: These are AI-generated observations, not professional medical advice.*',
      isUser: false,
      timestamp: now,
      suggestions: suggestions.take(3).toList(),
    );
  }

  static CoachMessage _generateImprovementResponse(MoodAnalysisContext context, DateTime now) {
    final recommendations = <String>[];
    final suggestions = <String>[];

    // Time-based recommendations
    if (context.timeSegmentAverages.isNotEmpty) {
      final worstSegment = context.timeSegmentAverages.entries
          .reduce((a, b) => a.value < b.value ? a : b);
      final segmentNames = ['morning', 'midday', 'evening'];

      recommendations.add('Your ${segmentNames[worstSegment.key]} tends to be challenging. Try scheduling lighter activities then.');
    }

    // Streak-based recommendations
    if (context.currentStreak < 7) {
      recommendations.add('Building a consistent logging habit (currently ${context.currentStreak} days) will help me give you better insights.');
      suggestions.add('Set a daily reminder to log your mood');
    }

    // Activity recommendations based on correlation data
    final activityRecommendations = _generateActivityRecommendations(context.recentCorrelationData);
    recommendations.addAll(activityRecommendations);

    // General mood-boosting strategies
    recommendations.addAll([
      'Try 10 minutes of sunlight exposure in the morning',
      'Practice deep breathing when you notice stress building',
      'Maintain a consistent sleep schedule',
      'Connect with supportive friends or family',
    ]);

    suggestions.addAll([
      'What activities make me feel best?',
      'Help me plan a better week',
      'What should I do when I feel down?',
    ]);

    final recommendationText = recommendations.take(4).join('\n• ');

    return CoachMessage(
      id: 'improvement_response_${now.millisecondsSinceEpoch}',
      text: '💡 **Personalized Recommendations**\n\nBased on your data, here are some strategies that might help:\n\n• $recommendationText\n\n*These are suggestions based on general wellness principles and your patterns. For persistent concerns, please consult a healthcare professional.*',
      isUser: false,
      timestamp: now,
      suggestions: suggestions.take(3).toList(),
    );
  }

  static CoachMessage _generateTodayResponse(MoodAnalysisContext context, DateTime now) {
    final todayAdvice = <String>[];
    final suggestions = <String>[];

    // Time of day specific advice
    final currentHour = now.hour;
    if (currentHour < 12) {
      todayAdvice.add('Good morning! Starting your day with intention can set a positive tone.');
      if (context.timeSegmentAverages[0] != null && context.timeSegmentAverages[0]! > 6.5) {
        todayAdvice.add('Your mornings tend to be your strongest time - take advantage of this energy!');
      }
    } else if (currentHour < 17) {
      todayAdvice.add('How\'s your day going so far? Midday is a great time to check in with yourself.');
    } else {
      todayAdvice.add('Evening is here - time to wind down and reflect on your day.');
    }

    // Recent mood trend advice
    if (context.recentMoods.isNotEmpty && context.recentMoods.length >= 3) {
      final recentTrend = context.recentMoods.take(3).toList();
      final isImproving = recentTrend[0] > recentTrend[2];

      if (isImproving) {
        todayAdvice.add('I notice your mood has been trending upward recently - keep doing what\'s working!');
      } else {
        todayAdvice.add('If you\'re having a tough day, remember that it\'s temporary. Be extra kind to yourself.');
        suggestions.add('What can I do to feel better right now?');
      }
    }

    suggestions.addAll([
      'Give me a quick mood boost tip',
      'What should I focus on today?',
      'Help me plan my evening',
    ]);

    final adviceText = todayAdvice.join('\n\n');

    return CoachMessage(
      id: 'today_response_${now.millisecondsSinceEpoch}',
      text: '🌟 **Today\'s Guidance**\n\n$adviceText\n\n*Remember: I\'m here to support your self-reflection, but please reach out to friends, family, or professionals if you need more support.*',
      isUser: false,
      timestamp: now,
      suggestions: suggestions.take(3).toList(),
    );
  }

  static CoachMessage _generateSleepResponse(MoodAnalysisContext context, DateTime now) {
    final sleepInsights = <String>[];
    final suggestions = <String>[];

    // Analyze sleep patterns from correlation data
    final sleepData = context.recentCorrelationData
        .where((data) => data.sleepQuality != null)
        .toList();

    if (sleepData.isNotEmpty) {
      final avgSleepQuality = sleepData
          .map((data) => data.sleepQuality!)
          .reduce((a, b) => a + b) / sleepData.length;

      sleepInsights.add('Your recent sleep quality averages ${avgSleepQuality.toStringAsFixed(1)}/10.');

      if (avgSleepQuality < 6.0) {
        sleepInsights.add('Poor sleep can significantly impact mood. Consider improving your sleep hygiene.');
        suggestions.add('Tell me about sleep hygiene tips');
      } else if (avgSleepQuality > 7.5) {
        sleepInsights.add('Your sleep quality looks good - this likely supports your overall wellbeing!');
      }
    } else {
      sleepInsights.add('I don\'t have recent sleep data from you. Tracking sleep alongside mood can reveal important patterns.');
      suggestions.add('Start tracking my sleep quality');
    }

    // General sleep advice
    sleepInsights.addAll([
      'Good sleep is crucial for emotional regulation and mental health.',
      'Try to maintain consistent sleep and wake times, even on weekends.',
    ]);

    suggestions.addAll([
      'What affects my sleep quality?',
      'Help me improve my sleep routine',
      'How does sleep affect my mood?',
    ]);

    return CoachMessage(
      id: 'sleep_response_${now.millisecondsSinceEpoch}',
      text: '😴 **Sleep & Mood Connection**\n\n${sleepInsights.join('\n\n')}\n\n*For persistent sleep issues, consider consulting a healthcare provider or sleep specialist.*',
      isUser: false,
      timestamp: now,
      suggestions: suggestions.take(3).toList(),
    );
  }

  static CoachMessage _generateStressResponse(MoodAnalysisContext context, DateTime now) {
    final stressInsights = <String>[];
    final suggestions = <String>[];

    // Analyze work stress from correlation data
    final stressData = context.recentCorrelationData
        .where((data) => data.workStress != null)
        .toList();

    if (stressData.isNotEmpty) {
      final avgStress = stressData
          .map((data) => data.workStress!)
          .reduce((a, b) => a + b) / stressData.length;

      stressInsights.add('Your recent work stress levels average ${avgStress.toStringAsFixed(1)}/10.');

      if (avgStress > 7.0) {
        stressInsights.add('High stress levels can really impact your mood and wellbeing. It\'s important to find healthy coping strategies.');
      }
    }

    // General stress management advice
    stressInsights.addAll([
      'Here are some quick stress management techniques:',
      '• Deep breathing: 4 counts in, hold for 4, out for 4',
      '• Progressive muscle relaxation',
      '• Take short breaks throughout your day',
      '• Practice mindfulness or meditation',
    ]);

    suggestions.addAll([
      'Quick stress relief techniques',
      'How can I manage work stress better?',
      'What helps when I feel overwhelmed?',
    ]);

    return CoachMessage(
      id: 'stress_response_${now.millisecondsSinceEpoch}',
      text: '🧘 **Stress Management Support**\n\n${stressInsights.join('\n\n')}\n\n*If stress is severely impacting your life, please consider speaking with a mental health professional for additional support.*',
      isUser: false,
      timestamp: now,
      suggestions: suggestions.take(3).toList(),
    );
  }

  static CoachMessage _generateExerciseResponse(MoodAnalysisContext context, DateTime now) {
    final exerciseInsights = <String>[];
    final suggestions = <String>[];

    // Analyze exercise patterns from correlation data
    final exerciseData = context.recentCorrelationData
        .where((data) => data.exerciseLevel != null)
        .toList();

    if (exerciseData.isNotEmpty) {
      final exerciseLevels = <String, int>{};
      for (final data in exerciseData) {
        final level = data.exerciseLevel!.name;
        exerciseLevels[level] = (exerciseLevels[level] ?? 0) + 1;
      }

      final mostCommon = exerciseLevels.entries.reduce((a, b) => a.value > b.value ? a : b);
      exerciseInsights.add('You\'ve mostly been doing ${mostCommon.key} activity recently.');
    }

    exerciseInsights.addAll([
      'Physical activity is one of the most effective mood boosters available!',
      'Even light movement like a 10-minute walk can improve mood.',
      'Find activities you enjoy - consistency matters more than intensity.',
    ]);

    suggestions.addAll([
      'What exercise is best for my mood?',
      'Quick activities I can do now',
      'How to build an exercise routine',
    ]);

    return CoachMessage(
      id: 'exercise_response_${now.millisecondsSinceEpoch}',
      text: '💪 **Movement & Mood**\n\n${exerciseInsights.join('\n\n')}\n\n*Start slowly and listen to your body. Consult healthcare providers before starting new exercise routines if you have health concerns.*',
      isUser: false,
      timestamp: now,
      suggestions: suggestions.take(3).toList(),
    );
  }

  static CoachMessage _generateDefaultResponse(MoodAnalysisContext context, DateTime now) {
    final responses = [
      'That\'s a thoughtful question! Based on your mood tracking data, I can see some interesting patterns.',
      'I appreciate you sharing that with me. Let me look at your recent mood data to provide some context.',
      'Thanks for that insight! Your ${context.daysLogged} days of mood tracking give us good data to work with.',
    ];

    final insights = <String>[];

    if (context.overallAverage > 0) {
      insights.add('Your overall mood average is ${context.overallAverage.toStringAsFixed(1)}/10.');
    }

    if (context.currentStreak > 1) {
      insights.add('You\'ve been consistently tracking for ${context.currentStreak} days.');
    }

    final responseText = responses[math.Random().nextInt(responses.length)];
    final insightText = insights.isNotEmpty ? '\n\n${insights.join(' ')}' : '';

    return CoachMessage(
      id: 'default_response_${now.millisecondsSinceEpoch}',
      text: '$responseText$insightText\n\n*I\'m here to help you understand patterns, but remember I\'m an AI assistant, not a licensed mental health professional.*',
      isUser: false,
      timestamp: now,
      suggestions: [
        'What patterns do you see in my data?',
        'How can I improve my mood?',
        'What should I focus on this week?',
      ],
    );
  }

  /// Helper methods for generating insights
  static String _analyzeWeatherPatterns(List<CorrelationData> correlationData) {
    final weatherMoods = <String, List<double>>{};

    // This would need mood data paired with weather data
    // For now, return general weather insight
    if (correlationData.any((data) => data.weather != null)) {
      return 'I notice you\'ve been tracking weather. Weather can significantly impact mood for many people.';
    }
    return '';
  }

  static List<String> _generateActivityRecommendations(List<CorrelationData> correlationData) {
    final recommendations = <String>[];

    // Analyze exercise patterns
    if (correlationData.any((data) => data.exerciseLevel == ActivityLevel.none)) {
      recommendations.add('Light physical activity could help boost your mood');
    }

    // Analyze social patterns
    if (correlationData.any((data) => data.socialActivity == SocialActivity.none)) {
      recommendations.add('Consider connecting with friends or family');
    }

    return recommendations;
  }

  /// Save message to conversation history
  static Future<void> _saveMessageToHistory(CoachMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_conversationHistoryKey);

      List<CoachMessage> history = [];
      if (historyJson != null) {
        final historyData = jsonDecode(historyJson) as List<dynamic>;
        history = historyData.map((json) => CoachMessage.fromJson(json)).toList();
      }

      history.add(message);

      // Keep only recent messages
      if (history.length > _maxHistoryLength) {
        history = history.skip(history.length - _maxHistoryLength).toList();
      }

      final updatedJson = jsonEncode(history.map((msg) => msg.toJson()).toList());
      await prefs.setString(_conversationHistoryKey, updatedJson);

    } catch (e) {
      Logger.aiService('❌ Error saving message to history: $e');
    }
  }

  /// Get conversation history
  static Future<List<CoachMessage>> getConversationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_conversationHistoryKey);

      if (historyJson == null) return [];

      final historyData = jsonDecode(historyJson) as List<dynamic>;
      return historyData.map((json) => CoachMessage.fromJson(json)).toList();

    } catch (e) {
      Logger.aiService('❌ Error loading conversation history: $e');
      return [];
    }
  }

  /// Clear conversation history
  static Future<void> clearConversationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_conversationHistoryKey);
      Logger.aiService('🗑️ Cleared conversation history');
    } catch (e) {
      Logger.aiService('❌ Error clearing conversation history: $e');
    }
  }

  /// Check if disclaimer was accepted
  static Future<bool> isDisclaimerAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_disclaimerAcceptedKey) ?? false;
    } catch (e) {
      return false;
    }
  }
}

/// Data class for mood analysis context
class MoodAnalysisContext {
  final double overallAverage;
  final int currentStreak;
  final int daysLogged;
  final List<double> recentMoods;
  final List<CorrelationData> recentCorrelationData;
  final int bestTimeSegment;
  final Map<int, double> timeSegmentAverages;

  MoodAnalysisContext({
    required this.overallAverage,
    required this.currentStreak,
    required this.daysLogged,
    required this.recentMoods,
    required this.recentCorrelationData,
    required this.bestTimeSegment,
    required this.timeSegmentAverages,
  });

  factory MoodAnalysisContext.empty() => MoodAnalysisContext(
    overallAverage: 0.0,
    currentStreak: 0,
    daysLogged: 0,
    recentMoods: [],
    recentCorrelationData: [],
    bestTimeSegment: 0,
    timeSegmentAverages: {},
  );
}

/// Coach message data class
class CoachMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? suggestions;
  final bool isError;

  CoachMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions,
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'suggestions': suggestions,
    'isError': isError,
  };

  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
    id: json['id'],
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
    suggestions: json['suggestions'] != null
        ? List<String>.from(json['suggestions'])
        : null,
    isError: json['isError'] ?? false,
  );
}