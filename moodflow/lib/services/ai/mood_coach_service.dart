import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../data/mood_data_service.dart';
import '../data/correlation_data_service.dart';
import '../data/mood_trends_service.dart';
import '../utils/logger.dart';

class MoodCoachService {
  static const String _enabledKey = 'ai_coach_enabled';
  static const String _conversationHistoryKey = 'coach_conversation_history';
  static const String _disclaimerAcceptedKey = 'coach_disclaimer_accepted';
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const int _maxHistoryLength = 20; // Keep last 20 messages

  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Check if coach is enabled and properly configured
  static Future<bool> isCoachEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_enabledKey) ?? false;
      final disclaimerAccepted = prefs.getBool(_disclaimerAcceptedKey) ?? false;
      final hasApiKey = await _hasValidApiKey();
      return isEnabled && disclaimerAccepted && hasApiKey;
    } catch (e) {
      Logger.aiService('❌ Error checking coach status: $e');
      return false;
    }
  }

  /// Check if we have a valid API key stored
  static Future<bool> hasValidApiKey() async {
    return await _hasValidApiKey();
  }

  /// Validate and save API key (reuse from MoodAnalysisService)
  static Future<bool> validateAndSaveApiKey(String apiKey) async {
    try {
      // Test the API key with a simple request using available models
      final models = ['gpt-4o-mini', 'gpt-3.5-turbo'];

      for (final model in models) {
        try {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'user',
                  'content': 'Test',
                },
              ],
              'max_tokens': 5,
            }),
          );

          if (response.statusCode == 200) {
            // Valid key, save it
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_openaiApiKeyKey, apiKey);
            Logger.aiService('✅ OpenAI API key validated and saved (using model: $model)');
            return true;
          } else if (response.statusCode == 401) {
            // Invalid API key
            Logger.aiService('❌ API key validation failed: Invalid key');
            return false;
          } else if (response.statusCode == 403 && model == models.first) {
            // Model not available, try next one
            Logger.aiService('⚠️ Model $model not available during validation, trying fallback...');
            continue;
          } else {
            Logger.aiService('❌ API key validation failed: ${response.statusCode}');
            return false;
          }
        } catch (e) {
          if (model == models.last) {
            // Last model failed
            Logger.aiService('❌ API key validation error: $e');
            return false;
          }
          // Try next model
          continue;
        }
      }

      return false;
    } catch (e) {
      Logger.aiService('❌ API key validation error: $e');
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

  /// Check if we have a valid OpenAI API key
  static Future<bool> _hasValidApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString(_openaiApiKeyKey);
      return apiKey != null && apiKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get stored API key
  static Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openaiApiKeyKey);
  }

  /// Get welcome message with disclaimer
  static Future<CoachMessage?> getWelcomeMessage() async {
    if (!await isCoachEnabled()) return null;

    return CoachMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: '''Hello! I'm your AI Mood Coach, powered by ChatGPT. 

⚠️ **IMPORTANT**: I'm an AI assistant that analyzes your mood data. I am NOT a licensed therapist or medical professional. My insights are for informational purposes only.

**For mental health crises, contact:**
• Emergency: 911
• Crisis Text Line: Text HOME to 741741
• National Suicide Prevention Lifeline: 988

I can help you understand your mood patterns, provide wellness suggestions, and have meaningful conversations about your wellbeing journey. What would you like to explore about your mood data?''',
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

  /// Process user message with authentic ChatGPT integration
  static Future<CoachMessage> processUserMessage(
      String message, {
        int maxWordCount = 150,
        bool includeMoodData = true,
        bool includeWeatherData = false,
        bool includeSleepData = false,
        bool includeActivityData = false,
        bool includeWorkStressData = false,
      }) async {
    try {
      Logger.aiService('🤖 Processing user message: ${message.substring(0, math.min(50, message.length))}...');

      // Save user message to history first
      final userMessage = CoachMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      );
      await _saveMessageToHistory(userMessage);

      // Get user's mood data for context
      final moodContext = await _buildMoodDataContext(
        includeMoodData: includeMoodData,
        includeWeatherData: includeWeatherData,
        includeSleepData: includeSleepData,
        includeActivityData: includeActivityData,
        includeWorkStressData: includeWorkStressData,
      );

      // Get conversation history for context
      final conversationHistory = await _getRecentConversationHistory();

      // Build the ChatGPT prompt with context
      final systemPrompt = _buildSystemPrompt(moodContext, maxWordCount);
      final messages = _buildChatMessages(systemPrompt, conversationHistory, message);

      // Call OpenAI API for main response
      final aiResponse = await _callOpenAI(messages, maxWordCount: maxWordCount);

      // Generate follow-up suggestions using AI
      final suggestions = await _generateAISuggestions(message, aiResponse, moodContext);

      // Add safety disclaimer to response
      final responseWithDisclaimer = _addSafetyDisclaimer(aiResponse);

      // Create response message
      final responseMessage = CoachMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        text: responseWithDisclaimer,
        isUser: false,
        timestamp: DateTime.now(),
        suggestions: suggestions,
      );

      // Save AI response to history
      await _saveMessageToHistory(responseMessage);

      Logger.aiService('✅ Generated authentic AI coach response');
      return responseMessage;

    } catch (e) {
      Logger.aiService('❌ Error processing message: $e');
      return CoachMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: 'I apologize, but I\'m having trouble processing your message right now. This could be due to an API issue or network problem. Please try again in a moment.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
    }
  }

  /// Build comprehensive mood data context for ChatGPT
  static Future<String> _buildMoodDataContext({
    bool includeMoodData = true,
    bool includeWeatherData = false,
    bool includeSleepData = false,
    bool includeActivityData = false,
    bool includeWorkStressData = false,
  }) async {
    final context = StringBuffer();
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    context.writeln('USER MOOD DATA CONTEXT:');
    context.writeln('Date range: ${_formatDate(thirtyDaysAgo)} to ${_formatDate(now)}');
    context.writeln('Mood scale: 1 (very poor) to 10 (excellent)');
    context.writeln('Time segments: Morning (0), Midday (1), Evening (2)');
    context.writeln('');

    // Get mood statistics
    if (includeMoodData) {
      try {
        final trends = await MoodTrendsService.getMoodTrends(
          startDate: thirtyDaysAgo,
          endDate: now,
        );

        final statistics = await MoodTrendsService.calculateStatisticsForDateRange(
            trends, thirtyDaysAgo, now
        );

        context.writeln('MOOD STATISTICS:');
        context.writeln('- Overall average: ${statistics.overallAverage.toStringAsFixed(1)}/10');
        context.writeln('- Current logging streak: ${statistics.currentStreak} days');
        context.writeln('- Total days logged: ${statistics.daysLogged}');

        if (statistics.timeSegmentAverages.isNotEmpty) {
          context.writeln('- Time segment averages:');
          final segments = ['Morning', 'Midday', 'Evening'];
          for (final entry in statistics.timeSegmentAverages.entries) {
            context.writeln('  • ${segments[entry.key]}: ${entry.value.toStringAsFixed(1)}/10');
          }
        }

        context.writeln('');

        // Add recent mood entries for detailed context
        context.writeln('RECENT MOOD ENTRIES (last 7 days):');
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          final dayData = <String>[];

          for (int segment = 0; segment < 3; segment++) {
            final mood = await MoodDataService.loadMood(date, segment);
            if (mood != null && mood['rating'] != null) {
              final rating = (mood['rating'] as num).toDouble();
              final note = mood['note'] as String? ?? '';
              final segmentName = ['Morning', 'Midday', 'Evening'][segment];

              if (note.isNotEmpty) {
                dayData.add('$segmentName: $rating/10 ("$note")');
              } else {
                dayData.add('$segmentName: $rating/10');
              }
            }
          }

          if (dayData.isNotEmpty) {
            context.writeln('${_formatDate(date)}: ${dayData.join(', ')}');
          }
        }
        context.writeln('');
      } catch (e) {
        Logger.aiService('❌ Error building mood context: $e');
        context.writeln('MOOD DATA: Error loading mood statistics');
      }
    }

    // Add correlation data context
    if (includeWeatherData || includeSleepData || includeActivityData || includeWorkStressData) {
      context.writeln('LIFESTYLE FACTORS (last 7 days):');

      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final correlation = await CorrelationDataService.loadCorrelationData(date);

        if (correlation != null) {
          final factors = <String>[];

          if (includeWeatherData && correlation.weather != null) {
            final temp = correlation.temperature != null
                ? ', ${correlation.temperature!.toStringAsFixed(1)}°C'
                : '';
            factors.add('Weather: ${correlation.weather!.name}$temp');
          }

          if (includeSleepData && correlation.sleepQuality != null) {
            factors.add('Sleep: ${correlation.sleepQuality}/10');
            if (correlation.bedtime != null && correlation.wakeTime != null) {
              factors.add('Sleep schedule: ${_formatTime(correlation.bedtime!)} - ${_formatTime(correlation.wakeTime!)}');
            }
          }

          if (includeActivityData) {
            if (correlation.exerciseLevel != null) {
              factors.add('Exercise: ${correlation.exerciseLevel!.name}');
            }
            if (correlation.socialActivity != null) {
              factors.add('Social: ${correlation.socialActivity!.name}');
            }
          }

          if (includeWorkStressData && correlation.workStress != null) {
            factors.add('Work stress: ${correlation.workStress}/10');
          }

          if (factors.isNotEmpty) {
            context.writeln('${_formatDate(date)}: ${factors.join(', ')}');
          }
        }
      }
      context.writeln('');
    }

    return context.toString();
  }

  /// Build system prompt for ChatGPT
  static String _buildSystemPrompt(String moodContext, int maxWordCount) {
    return '''You are an AI Mood Coach in a mood tracking app called MoodFlow. You help users understand their mood patterns and provide supportive, insightful conversations about their mental wellbeing.

CRITICAL WORD LIMIT: Your response must be EXACTLY $maxWordCount words or fewer. Count your words carefully and stop when you reach this limit.

IMPORTANT DISCLAIMERS TO REMEMBER:
- You are NOT a licensed therapist, psychologist, or medical professional
- Your insights are for informational and self-reflection purposes only
- Always remind users to seek professional help for serious mental health concerns
- For crisis situations, direct users to emergency services

YOUR ROLE:
- Analyze mood patterns and provide insights based on the user's data
- Offer supportive, empathetic conversation about their mood journey
- Provide evidence-based wellness suggestions and coping strategies
- Help users reflect on their mood tracking data and identify patterns
- Be conversational, warm, and supportive while maintaining professionalism

RESPONSE GUIDELINES:
- MUST stay within $maxWordCount words - this is critical
- Be conversational and empathetic, not clinical or robotic
- Reference specific data points from their mood tracking when relevant
- Provide actionable, practical suggestions
- Be encouraging and supportive while being honest about patterns
- Focus on one main insight or suggestion per response
- Use simple, clear language

USER'S MOOD DATA:
$moodContext

Remember: Keep your response to $maxWordCount words maximum. Be helpful but concise.''';
  }

  /// Build chat messages for OpenAI API
  static List<Map<String, String>> _buildChatMessages(
      String systemPrompt,
      List<CoachMessage> conversationHistory,
      String newMessage) {
    final messages = <Map<String, String>>[];

    // Add system prompt
    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    // Add recent conversation history for context (last 6 messages)
    final recentHistory = conversationHistory.takeLast(6).toList();
    for (final historyMessage in recentHistory) {
      messages.add({
        'role': historyMessage.isUser ? 'user' : 'assistant',
        'content': historyMessage.text,
      });
    }

    // Add current user message
    messages.add({
      'role': 'user',
      'content': newMessage,
    });

    return messages;
  }

  /// Call OpenAI API for authentic ChatGPT response
  static Future<String> _callOpenAI(List<Map<String, String>> messages, {int? maxWordCount}) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    // Calculate appropriate max_tokens based on word count (roughly 1.3 tokens per word)
    final maxTokens = maxWordCount != null ? (maxWordCount * 1.5).round() : 600;

    // Try with gpt-3.5-turbo first (more widely available), then gpt-4o-mini
    final models = ['gpt-3.5-turbo', 'gpt-4o-mini'];

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'max_tokens': maxTokens,
            'temperature': 0.7, // Balanced creativity and consistency
            'presence_penalty': 0.2, // Encourage varied responses
            'frequency_penalty': 0.1, // Reduce repetition
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          Logger.aiService('✅ Successfully used model: $model');
          return data['choices'][0]['message']['content'] as String;
        } else if (response.statusCode == 401) {
          throw Exception('Invalid API key. Please check your OpenAI API key in settings.');
        } else if (response.statusCode == 429) {
          throw Exception('API rate limit exceeded. Please try again in a moment.');
        } else if (response.statusCode == 403 && model == models.first) {
          // Model not available, try next one
          Logger.aiService('⚠️ Model $model not available, trying fallback...');
          continue;
        } else {
          throw Exception('API error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        if (model == models.last) {
          // Last model failed, rethrow error
          rethrow;
        }
        // Try next model
        Logger.aiService('⚠️ Model $model failed: $e, trying fallback...');
        continue;
      }
    }

    throw Exception('All AI models failed to respond');
  }

  /// Generate AI-powered contextual suggestions
  static Future<List<String>> _generateAISuggestions(
      String userMessage, String aiResponse, String moodContext) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) return [];

      final suggestionPrompt = '''Based on this mood coaching conversation, suggest 3 helpful follow-up questions the user could ask.

USER ASKED: "$userMessage"
AI COACH RESPONDED: "$aiResponse"

MOOD DATA CONTEXT: 
$moodContext

Requirements for follow-up questions:
- Must be directly relevant to the user's mood data and this conversation
- Maximum 7 words each
- Should help the user get deeper insights about their specific mood patterns
- Focus on actionable next steps or clarifying questions
- Must make sense given their actual data (don't suggest topics they have no data for)
- Should feel like natural conversation continuations

Examples of GOOD prompts:
- "What boosts my morning mood most?"
- "How can I improve my sleep?"
- "What patterns should I watch?"

Examples of BAD prompts:
- "What physical activities bring you joy?" (too generic, assumes data not shown)
- "Tell me about your relationships" (not related to mood tracking data)
- "How do you handle stress at work?" (too long, generic)

Return ONLY a JSON array of exactly 3 strings: ["prompt1", "prompt2", "prompt3"]''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': suggestionPrompt},
          ],
          'max_tokens': 150,
          'temperature': 0.9, // Higher creativity for diverse suggestions
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Extract JSON from response (sometimes AI adds extra text)
        final jsonMatch = RegExp(r'\[(.*?)\]', dotAll: true).firstMatch(content);
        if (jsonMatch != null) {
          final jsonString = '[${jsonMatch.group(1)}]';
          final suggestions = jsonDecode(jsonString) as List<dynamic>;

          // Validate suggestions are 7 words or less
          final validSuggestions = suggestions
              .map((s) => s.toString().trim())
              .where((s) => s.split(' ').length <= 7 && s.length > 10)
              .take(3)
              .toList();

          if (validSuggestions.length >= 2) {
            Logger.aiService('✅ Generated ${validSuggestions.length} AI suggestions');
            return validSuggestions;
          }
        }
      }
    } catch (e) {
      Logger.aiService('⚠️ Could not generate AI suggestions: $e');
    }

    // Fallback to contextual suggestions if AI fails
    return _generateFallbackSuggestions(userMessage, aiResponse);
  }

  /// Generate fallback suggestions if AI suggestion generation fails
  static List<String> _generateFallbackSuggestions(String userMessage, String aiResponse) {
    final suggestions = <String>[];
    final lowercaseMessage = userMessage.toLowerCase();
    final lowercaseResponse = aiResponse.toLowerCase();

    // Generate contextual suggestions based on content
    if (lowercaseResponse.contains('sleep') || lowercaseMessage.contains('sleep')) {
      suggestions.add('How does sleep affect my mood?');
    }

    if (lowercaseResponse.contains('exercise') || lowercaseMessage.contains('exercise')) {
      suggestions.add('Best exercise for my mood?');
    }

    if (lowercaseResponse.contains('weather') || lowercaseMessage.contains('weather')) {
      suggestions.add('Weather and mood correlation?');
    }

    if (lowercaseResponse.contains('pattern') || lowercaseMessage.contains('pattern')) {
      suggestions.add('What patterns should I watch?');
    }

    // Fill with general helpful suggestions
    final fallbackSuggestions = [
      'What should I focus on today?',
      'Give me a personalized tip',
      'How can I improve this week?',
      'What time am I happiest?',
      'What are my biggest mood boosters?',
      'Help me plan tomorrow better',
    ];

    while (suggestions.length < 3) {
      final available = fallbackSuggestions
          .where((s) => !suggestions.contains(s))
          .toList();
      if (available.isEmpty) break;

      final randomIndex = math.Random().nextInt(available.length);
      suggestions.add(available[randomIndex]);
    }

    return suggestions.take(3).toList();
  }

  /// Add safety disclaimer to AI response
  static String _addSafetyDisclaimer(String aiResponse) {
    final disclaimer = '''

---
*This is AI-generated guidance, not professional medical advice. If you're in crisis or danger to yourself/others, please contact:*
• **Emergency**: 911 (US), 112 (EU), 000 (AU)
• **Crisis Text Line**: Text HOME to 741741 (US)
• **Suicide Prevention**: 988 (US), 13 11 14 (AU), 116 123 (UK)
• **Crisis Support**: Your local emergency services''';

    return aiResponse + disclaimer;
  }

  /// Get recent conversation history for context
  static Future<List<CoachMessage>> _getRecentConversationHistory() async {
    try {
      final history = await getConversationHistory();
      // Return last 10 messages for context (excluding current)
      return history.takeLast(10).toList();
    } catch (e) {
      Logger.aiService('❌ Error getting conversation history: $e');
      return [];
    }
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

  // Helper methods
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// Extension to get last N elements from a list
extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return skip(length - count).toList();
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