import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../data/mood_data_service.dart';
import '../data/mood_trends_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodAnalysisService {
  // Store API key securely
  static String _openaiApiKey = '';
  
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Analyze moods for a date range and get AI insights
  static Future<MoodAnalysisResult> analyzeMoodTrends({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // 1. Gather mood data for the specified range
      final moodData = await _gatherMoodData(startDate, endDate);

      if (moodData.isEmpty) {
        return MoodAnalysisResult(
          success: false,
          error: 'No mood data found for the selected date range.',
          insights: [],
          recommendations: [],
        );
      }

      // 2. Prepare data for AI analysis
      final analysisPrompt = _buildAnalysisPrompt(moodData, startDate, endDate);

      // 3. Send to OpenAI API
      final aiResponse = await _sendToOpenAI(analysisPrompt);

      // 4. Parse AI response
      return _parseAIResponse(aiResponse);

    } catch (e) {
      return MoodAnalysisResult(
        success: false,
        error: 'Analysis failed: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }

  /// Gather mood data for analysis
  static Future<List<DayMoodAnalysis>> _gatherMoodData(DateTime startDate, DateTime endDate) async {
    final moodData = <DayMoodAnalysis>[];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final dayAnalysis = DayMoodAnalysis(date: currentDate);
      bool hasData = false;

      // Gather all segments for this day
      for (int segment = 0; segment < 3; segment++) {
        final mood = await MoodDataService.loadMood(currentDate, segment);
        if (mood != null && mood['rating'] != null) {
          dayAnalysis.segments[segment] = SegmentMoodAnalysis(
            segment: segment,
            rating: (mood['rating'] as num).toDouble(),
            note: mood['note'] as String? ?? '',
            timestamp: mood['timestamp'] as String?,
          );
          hasData = true;
        }
      }

      if (hasData) {
        moodData.add(dayAnalysis);
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return moodData;
  }

  /// Build prompt for AI analysis
  static String _buildAnalysisPrompt(List<DayMoodAnalysis> moodData, DateTime startDate, DateTime endDate) {
    final buffer = StringBuffer();

    buffer.writeln('Please analyze the following mood tracking data and provide insights and recommendations.');
    buffer.writeln('');
    buffer.writeln('DATE RANGE: ${_formatDate(startDate)} to ${_formatDate(endDate)}');
    buffer.writeln('MOOD SCALE: 1 (very poor) to 10 (excellent)');
    buffer.writeln('TIME SEGMENTS: Morning (0), Midday (1), Evening (2)');
    buffer.writeln('');
    buffer.writeln('MOOD DATA:');

    for (final day in moodData) {
      buffer.writeln('${_formatDate(day.date)}:');

      for (int segment = 0; segment < 3; segment++) {
        final segmentData = day.segments[segment];
        if (segmentData != null) {
          final segmentName = ['Morning', 'Midday', 'Evening'][segment];
          buffer.writeln('  $segmentName: ${segmentData.rating}/10');
          if (segmentData.note.isNotEmpty) {
            buffer.writeln('    Note: "${segmentData.note}"');
          }
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('Please provide:');
    buffer.writeln('1. KEY INSIGHTS: 3-5 specific patterns or trends you notice');
    buffer.writeln('2. RECOMMENDATIONS: 3-5 actionable suggestions for improving mood or maintaining good patterns');
    buffer.writeln('');
    buffer.writeln('Format your response as JSON with this structure:');
    buffer.writeln('{');
    buffer.writeln('  "insights": [');
    buffer.writeln('    {"title": "Insight Title", "description": "Detailed explanation", "type": "positive|negative|neutral"}');
    buffer.writeln('  ],');
    buffer.writeln('  "recommendations": [');
    buffer.writeln('    {"title": "Recommendation Title", "description": "Actionable advice", "priority": "high|medium|low"}');
    buffer.writeln('  ]');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Send analysis request to OpenAI
  static Future<String> _sendToOpenAI(String prompt) async {
    // Get API key from storage
    _openaiApiKey = await _getStoredApiKey();

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a helpful mood analysis assistant. Analyze mood tracking data and provide insights and recommendations. Always respond with valid JSON in the requested format.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'max_tokens': 1500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('OpenAI API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Parse AI response into structured result
  static MoodAnalysisResult _parseAIResponse(String aiResponse) {
    try {
      // Clean up the response to extract JSON
      String cleanedResponse = aiResponse.trim();

      // Find JSON boundaries
      int startIndex = cleanedResponse.indexOf('{');
      int endIndex = cleanedResponse.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1) {
        cleanedResponse = cleanedResponse.substring(startIndex, endIndex + 1);
      }

      final parsed = jsonDecode(cleanedResponse) as Map<String, dynamic>;

      final insights = <MoodInsight>[];
      final recommendations = <MoodRecommendation>[];

      // Parse insights
      if (parsed['insights'] is List) {
        for (final insight in parsed['insights']) {
          insights.add(MoodInsight(
            title: insight['title'] ?? 'Insight',
            description: insight['description'] ?? '',
            type: _parseInsightType(insight['type']),
          ));
        }
      }

      // Parse recommendations
      if (parsed['recommendations'] is List) {
        for (final rec in parsed['recommendations']) {
          recommendations.add(MoodRecommendation(
            title: rec['title'] ?? 'Recommendation',
            description: rec['description'] ?? '',
            priority: _parsePriority(rec['priority']),
          ));
        }
      }

      return MoodAnalysisResult(
        success: true,
        insights: insights,
        recommendations: recommendations,
      );

    } catch (e) {
      return MoodAnalysisResult(
        success: false,
        error: 'Failed to parse AI response: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }

  static InsightType _parseInsightType(String? type) {
    switch (type?.toLowerCase()) {
      case 'positive': return InsightType.positive;
      case 'negative': return InsightType.negative;
      default: return InsightType.neutral;
    }
  }

  static RecommendationPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high': return RecommendationPriority.high;
      case 'low': return RecommendationPriority.low;
      default: return RecommendationPriority.medium;
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if a valid API key exists
  static Future<bool> hasValidApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_api_key');
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Validate and save API key
  static Future<bool> validateAndSaveApiKey(String apiKey) async {
    try {
      // Test the API key with a simple request
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
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
        await prefs.setString('openai_api_key', apiKey);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Get stored API key
  static Future<String> _getStoredApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openai_api_key') ?? '';
  }
}

// Data classes
class DayMoodAnalysis {
  final DateTime date;
  final Map<int, SegmentMoodAnalysis> segments = {};

  DayMoodAnalysis({required this.date});
}

class SegmentMoodAnalysis {
  final int segment;
  final double rating;
  final String note;
  final String? timestamp;

  SegmentMoodAnalysis({
    required this.segment,
    required this.rating,
    required this.note,
    this.timestamp,
  });
}

class MoodAnalysisResult {
  final bool success;
  final String? error;
  final List<MoodInsight> insights;
  final List<MoodRecommendation> recommendations;

  MoodAnalysisResult({
    required this.success,
    this.error,
    required this.insights,
    required this.recommendations,
  });
}

class MoodInsight {
  final String title;
  final String description;
  final InsightType type;

  MoodInsight({
    required this.title,
    required this.description,
    required this.type,
  });
}

class MoodRecommendation {
  final String title;
  final String description;
  final RecommendationPriority priority;

  MoodRecommendation({
    required this.title,
    required this.description,
    required this.priority,
  });
}

enum InsightType { positive, negative, neutral }
enum RecommendationPriority { high, medium, low }