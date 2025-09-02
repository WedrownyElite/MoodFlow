import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../data/mood_data_service.dart';
import '../data/correlation_data_service.dart';
import '../insights/smart_insights_service.dart'  as smartinsights;
import 'package:shared_preferences/shared_preferences.dart';

class MoodAnalysisService {
  // Store API key securely
  static String _openaiApiKey = '';

  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static const String _savedAnalysesKey = 'saved_ai_analyses';

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

  /// Analyze moods with specific data type options
  static Future<MoodAnalysisResult> analyzeMoodTrendsWithOptions({
    required DateTime startDate,
    required DateTime endDate,
    bool includeMoodData = true,
    bool includeWeatherData = false,
    bool includeSleepData = false,
    bool includeActivityData = false,
    bool includeWorkStressData = false,
  }) async {
    try {
      // 1. Gather selected data types
      final analysisData = await _gatherSelectedData(
        startDate,
        endDate,
        includeMoodData: includeMoodData,
        includeWeatherData: includeWeatherData,
        includeSleepData: includeSleepData,
        includeActivityData: includeActivityData,
        includeWorkStressData: includeWorkStressData,
      );

      if (analysisData.isEmpty) {
        return MoodAnalysisResult(
          success: false,
          error: 'No data found for the selected types and date range.',
          insights: [],
          recommendations: [],
        );
      }

      // 2. Prepare data for AI analysis
      final analysisPrompt = _buildEnhancedAnalysisPrompt(
        analysisData,
        startDate,
        endDate,
        includeMoodData: includeMoodData,
        includeWeatherData: includeWeatherData,
        includeSleepData: includeSleepData,
        includeActivityData: includeActivityData,
        includeWorkStressData: includeWorkStressData,
      );

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
  static Future<List<DayMoodAnalysis>> _gatherMoodData(
      DateTime startDate, DateTime endDate) async {
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

  /// Gather selected data types for analysis
  static Future<List<EnhancedDayAnalysis>> _gatherSelectedData(
    DateTime startDate,
    DateTime endDate, {
    bool includeMoodData = true,
    bool includeWeatherData = false,
    bool includeSleepData = false,
    bool includeActivityData = false,
    bool includeWorkStressData = false,
  }) async {
    final analysisData = <EnhancedDayAnalysis>[];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final dayAnalysis = EnhancedDayAnalysis(date: currentDate);
      bool hasData = false;

      // Gather mood data if selected
      if (includeMoodData) {
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
      }

      // Gather correlation data if any correlation types selected
      if (includeWeatherData ||
          includeSleepData ||
          includeActivityData ||
          includeWorkStressData) {
        final correlationData =
            await CorrelationDataService.loadCorrelationData(currentDate);
        if (correlationData != null) {
          dayAnalysis.correlationData = correlationData;
          hasData = true;
        }
      }

      if (hasData) {
        analysisData.add(dayAnalysis);
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return analysisData;
  }

  /// Build prompt for AI analysis
  static String _buildAnalysisPrompt(
      List<DayMoodAnalysis> moodData, DateTime startDate, DateTime endDate) {
    final buffer = StringBuffer();

    buffer.writeln(
        'Please analyze the following mood tracking data and provide insights and recommendations.');
    buffer.writeln('');
    buffer.writeln(
        'DATE RANGE: ${_formatDate(startDate)} to ${_formatDate(endDate)}');
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
    buffer
        .writeln('1. KEY INSIGHTS: 3-5 specific patterns or trends you notice');
    buffer.writeln(
        '2. RECOMMENDATIONS: 3-5 actionable suggestions for improving mood or maintaining good patterns');
    buffer.writeln('');
    buffer.writeln('Format your response as JSON with this structure:');
    buffer.writeln('{');
    buffer.writeln('  "insights": [');
    buffer.writeln('    {"title": "Insight Title", "description": "Detailed explanation", "type": "positive|negative|neutral", "actionSteps": ["Step 1", "Step 2", "Step 3"]}');
    buffer.writeln('  ],');
    buffer.writeln('  "recommendations": [');
    buffer.writeln('    {"title": "Recommendation Title", "description": "Actionable advice", "priority": "high|medium|low", "actionSteps": ["Step 1", "Step 2", "Step 3"]}');
    buffer.writeln('  ]');
    buffer.writeln('}');

    buffer.writeln('');
    buffer.writeln('IMPORTANT: For each recommendation, include 3-5 specific, actionable steps in the actionSteps array. Each step should be:');
    buffer.writeln('- Short and clear (under 60 characters)');
    buffer.writeln('- Specific and actionable');
    buffer.writeln('- Easy to implement');
    buffer.writeln('- Directly related to the recommendation');

    return buffer.toString();
  }

  /// Build enhanced analysis prompt with correlation data
  static String _buildEnhancedAnalysisPrompt(
    List<EnhancedDayAnalysis> analysisData,
    DateTime startDate,
    DateTime endDate, {
    bool includeMoodData = true,
    bool includeWeatherData = false,
    bool includeSleepData = false,
    bool includeActivityData = false,
    bool includeWorkStressData = false,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
        'Please analyze the following mood and lifestyle data and provide insights and recommendations.');
    buffer.writeln('');
    buffer.writeln(
        'DATE RANGE: ${_formatDate(startDate)} to ${_formatDate(endDate)}');
    buffer.writeln('');
    buffer.writeln('DATA TYPES INCLUDED:');
    if (includeMoodData) {
      buffer.writeln('- Mood ratings (1-10 scale) and notes');
    }
    if (includeWeatherData) {
      buffer.writeln('- Weather conditions and temperature');
    }
    if (includeSleepData) {
      buffer.writeln('- Sleep quality (1-10 scale), duration, and schedule');
    }
    if (includeActivityData) {
      buffer.writeln('- Exercise levels and social activities');
    }
    if (includeWorkStressData) {
      buffer.writeln('- Work stress levels (1-10 scale)');
    }
    buffer.writeln('');

    if (includeMoodData) {
      buffer.writeln('MOOD SCALE: 1 (very poor) to 10 (excellent)');
      buffer.writeln('TIME SEGMENTS: Morning (0), Midday (1), Evening (2)');
      buffer.writeln('');
    }

    buffer.writeln('DAILY DATA:');

    for (final day in analysisData) {
      buffer.writeln('${_formatDate(day.date)}:');

      // Include mood data if selected
      if (includeMoodData) {
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
      }

      // Include correlation data if selected
      if (day.correlationData != null) {
        final corr = day.correlationData!;

        if (includeWeatherData &&
            (corr.weather != null || corr.temperature != null)) {
          buffer.write('  Weather: ');
          if (corr.weather != null) buffer.write(corr.weather!.name);
          if (corr.temperature != null) {
            buffer.write(
                ', ${corr.temperature!.toStringAsFixed(1)}°${corr.temperatureUnit == 'fahrenheit' ? 'F' : 'C'}');
          }
          buffer.writeln();
        }

        if (includeSleepData) {
          if (corr.sleepQuality != null) {
            buffer.writeln('  Sleep Quality: ${corr.sleepQuality}/10');
          }
          if (corr.bedtime != null && corr.wakeTime != null) {
            buffer.writeln(
                '  Sleep: ${DateFormat('HH:mm').format(corr.bedtime!)} - ${DateFormat('HH:mm').format(corr.wakeTime!)}');
          }
        }

        if (includeActivityData) {
          if (corr.exerciseLevel != null) {
            buffer.writeln('  Exercise: ${corr.exerciseLevel!.name}');
          }
          if (corr.socialActivity != null) {
            buffer.writeln('  Social: ${corr.socialActivity!.name}');
          }
        }

        if (includeWorkStressData && corr.workStress != null) {
          buffer.writeln('  Work Stress: ${corr.workStress}/10');
        }
      }

      buffer.writeln('');
    }

    buffer.writeln('Please provide:');
    buffer.writeln(
        '1. KEY INSIGHTS: 3-5 specific patterns or trends you notice in the selected data types');
    buffer.writeln(
        '2. RECOMMENDATIONS: 3-5 actionable suggestions based on the correlations and patterns found');
    buffer.writeln('');
    buffer.writeln(
        'Focus your analysis on the relationships between the selected data types.');
    buffer.writeln('');
    buffer.writeln('Format your response as JSON with this structure:');
    buffer.writeln('{');
    buffer.writeln('  "insights": [');
    buffer.writeln(
        '    {"title": "Insight Title", "description": "Detailed explanation", "type": "positive|negative|neutral"}');
    buffer.writeln('  ],');
    buffer.writeln('  "recommendations": [');
    buffer.writeln(
        '    {"title": "Recommendation Title", "description": "Actionable advice", "priority": "high|medium|low"}');
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
            'content':
                'You are a helpful mood analysis assistant. Analyze mood tracking data and provide insights and recommendations. Always respond with valid JSON in the requested format.',
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
      throw Exception(
          'OpenAI API error: ${response.statusCode} - ${response.body}');
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
            actionSteps: insight['actionSteps'] != null
                ? List<String>.from(insight['actionSteps'])
                : [],
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
            actionSteps: rec['actionSteps'] != null
                ? List<String>.from(rec['actionSteps'])
                : [],
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

  /// Enhanced analysis that combines AI with local pattern detection
  static Future<MoodAnalysisResult> generateEnhancedAnalysis({
    required DateTime startDate,
    required DateTime endDate,
    bool includeMoodData = true,
    bool includeWeatherData = false,
    bool includeSleepData = false,
    bool includeActivityData = false,
    bool includeWorkStressData = false,
  }) async {
    try {
      // Get standard AI analysis
      final aiResult = await analyzeMoodTrendsWithOptions(
        startDate: startDate,
        endDate: endDate,
        includeMoodData: includeMoodData,
        includeWeatherData: includeWeatherData,
        includeSleepData: includeSleepData,
        includeActivityData: includeActivityData,
        includeWorkStressData: includeWorkStressData,
      );

      if (!aiResult.success) return aiResult;

      // Enhance with local pattern detection
      final smartInsights = await smartinsights.SmartInsightsService.generateInsights(forceRefresh: true);

      // Convert SmartInsights to MoodInsights and MoodRecommendations
      final enhancedInsights = <MoodInsight>[];
      final enhancedRecommendations = <MoodRecommendation>[];

      for (final insight in smartInsights.take(3)) {
        enhancedInsights.add(MoodInsight(
          title: insight.title,
          description: insight.description,
          type: insight.type == smartinsights.InsightType.pattern ? InsightType.positive : InsightType.neutral,
        ));

        if (insight.actionSteps != null && insight.actionSteps!.isNotEmpty) {
          enhancedRecommendations.add(MoodRecommendation(
            title: 'Action Plan: ${insight.title}',
            description: insight.actionSteps!.join(' • '),
            priority: insight.priority == smartinsights.AlertPriority.high
                ? RecommendationPriority.high
                : RecommendationPriority.medium,
          ));
        }
      }

      // Combine with AI results
      final combinedInsights = [...aiResult.insights, ...enhancedInsights];
      final combinedRecommendations = [...aiResult.recommendations, ...enhancedRecommendations];

      return MoodAnalysisResult(
        success: true,
        insights: combinedInsights,
        recommendations: combinedRecommendations,
      );

    } catch (e) {
      return MoodAnalysisResult(
        success: false,
        error: 'Enhanced analysis failed: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }
  
  static InsightType _parseInsightType(String? type) {
    switch (type?.toLowerCase()) {
      case 'positive':
        return InsightType.positive;
      case 'negative':
        return InsightType.negative;
      default:
        return InsightType.neutral;
    }
  }

  static RecommendationPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return RecommendationPriority.high;
      case 'low':
        return RecommendationPriority.low;
      default:
        return RecommendationPriority.medium;
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

  /// Save analysis result with timestamp
  static Future<void> saveAnalysisResult(
      MoodAnalysisResult result, DateTime startDate, DateTime endDate) async {
    if (!result.success) return;

    final prefs = await SharedPreferences.getInstance();
    final existingAnalyses = await getSavedAnalyses();

    final savedAnalysis = SavedAnalysis(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
      result: result,
    );

    existingAnalyses.insert(0, savedAnalysis); // Add to beginning

    // Keep only last 20 analyses
    final limitedAnalyses = existingAnalyses.take(20).toList();

    final jsonData =
        limitedAnalyses.map((analysis) => analysis.toJson()).toList();
    await prefs.setString(_savedAnalysesKey, jsonEncode(jsonData));
  }

  /// Get all saved analyses
  static Future<List<SavedAnalysis>> getSavedAnalyses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_savedAnalysesKey);

      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((json) => SavedAnalysis.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete a saved analysis
  static Future<void> deleteSavedAnalysis(String analysisId) async {
    final prefs = await SharedPreferences.getInstance();
    final analyses = await getSavedAnalyses();

    analyses.removeWhere((analysis) => analysis.id == analysisId);

    final jsonData = analyses.map((analysis) => analysis.toJson()).toList();
    await prefs.setString(_savedAnalysesKey, jsonEncode(jsonData));
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

class EnhancedDayAnalysis {
  final DateTime date;
  final Map<int, SegmentMoodAnalysis> segments = {};
  CorrelationData? correlationData;

  EnhancedDayAnalysis({required this.date});
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
  final List<String> actionSteps;

  MoodInsight({
    required this.title,
    required this.description,
    required this.type,
    this.actionSteps = const [],
  });
}

class MoodRecommendation {
  final String title;
  final String description;
  final RecommendationPriority priority;
  final List<String> actionSteps;

  MoodRecommendation({
    required this.title,
    required this.description,
    required this.priority,
    this.actionSteps = const [],
  });
}

class SavedAnalysis {
  final String id;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final MoodAnalysisResult result;

  SavedAnalysis({
    required this.id,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.result,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'result': {
          'success': result.success,
          'insights': result.insights
              .map((i) => {
                    'title': i.title,
                    'description': i.description,
                    'type': i.type.name,
                  })
              .toList(),
          'recommendations': result.recommendations
              .map((r) => {
                    'title': r.title,
                    'description': r.description,
                    'priority': r.priority.name,
                  })
              .toList(),
        },
      };

  factory SavedAnalysis.fromJson(Map<String, dynamic> json) => SavedAnalysis(
        id: json['id'],
        createdAt: DateTime.parse(json['createdAt']),
        startDate: DateTime.parse(json['startDate']),
        endDate: DateTime.parse(json['endDate']),
        result: MoodAnalysisResult(
          success: json['result']['success'],
          insights: (json['result']['insights'] as List)
              .map((i) => MoodInsight(
                    title: i['title'],
                    description: i['description'],
                    type: InsightType.values
                        .firstWhere((t) => t.name == i['type']),
                  ))
              .toList(),
          recommendations: (json['result']['recommendations'] as List)
              .map((r) => MoodRecommendation(
                    title: r['title'],
                    description: r['description'],
                    priority: RecommendationPriority.values
                        .firstWhere((p) => p.name == r['priority']),
                  ))
              .toList(),
        ),
      );
}

enum InsightType { positive, negative, neutral }

enum RecommendationPriority { high, medium, low }
