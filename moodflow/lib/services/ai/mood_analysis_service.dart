import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../data/mood_data_service.dart';
import '../data/correlation_data_service.dart';
import '../insights/smart_insights_service.dart'  as smartinsights;
import '../utils/logger.dart';
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

  /// Perform deep dive analysis with conversational insights
  static Future<MoodAnalysisResult> performDeepDiveAnalysis({
    required DateTime startDate,
    required DateTime endDate,
    bool includeMoodData = true,
    bool includeWeatherData = false,
    bool includeSleepData = false,
    bool includeActivityData = false,
    bool includeWorkStressData = false,
  }) async {
    try {
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

      final analysisPrompt = _buildDeepDivePrompt(
        analysisData,
        startDate,
        endDate,
      );

      final aiResponse = await _sendToOpenAI(analysisPrompt);
      return _parseAIResponse(aiResponse);
    } catch (e) {
      return MoodAnalysisResult(
        success: false,
        error: 'Deep dive analysis failed: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }

  /// Perform comparative analysis between two time periods
  static Future<MoodAnalysisResult> performComparativeAnalysis({
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
    bool includeMoodData = true,
    bool includeWeatherData = false,
    bool includeSleepData = false,
    bool includeActivityData = false,
    bool includeWorkStressData = false,
  }) async {
    try {
      final period1Data = await _gatherSelectedData(
        period1Start,
        period1End,
        includeMoodData: includeMoodData,
        includeWeatherData: includeWeatherData,
        includeSleepData: includeSleepData,
        includeActivityData: includeActivityData,
        includeWorkStressData: includeWorkStressData,
      );

      final period2Data = await _gatherSelectedData(
        period2Start,
        period2End,
        includeMoodData: includeMoodData,
        includeWeatherData: includeWeatherData,
        includeSleepData: includeSleepData,
        includeActivityData: includeActivityData,
        includeWorkStressData: includeWorkStressData,
      );

      if (period1Data.isEmpty || period2Data.isEmpty) {
        return MoodAnalysisResult(
          success: false,
          error: 'Insufficient data in one or both time periods for comparison.',
          insights: [],
          recommendations: [],
        );
      }

      final analysisPrompt = _buildComparativePrompt(
        period1Data,
        period2Data,
        period1Start,
        period1End,
        period2Start,
        period2End,
      );

      final aiResponse = await _sendToOpenAI(analysisPrompt);
      return _parseAIResponse(aiResponse);
    } catch (e) {
      return MoodAnalysisResult(
        success: false,
        error: 'Comparative analysis failed: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }

  /// Perform predictive analysis (placeholder for future implementation)
  static Future<MoodAnalysisResult> performPredictiveAnalysis({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // For now, redirect to deep dive analysis
      return await performDeepDiveAnalysis(
        startDate: startDate,
        endDate: endDate,
        includeMoodData: true,
        includeWeatherData: true,
        includeSleepData: true,
        includeActivityData: true,
        includeWorkStressData: true,
      );
    } catch (e) {
      return MoodAnalysisResult(
        success: false,
        error: 'Predictive analysis failed: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }

  /// Perform behavioral analysis (placeholder for future implementation)
  static Future<MoodAnalysisResult> performBehavioralAnalysis({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return await performDeepDiveAnalysis(
        startDate: startDate,
        endDate: endDate,
        includeMoodData: true,
        includeWeatherData: false,
        includeSleepData: true,
        includeActivityData: true,
        includeWorkStressData: true,
      );
    } catch (e) {
      return MoodAnalysisResult(
        success: false,
        error: 'Behavioral analysis failed: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }

  /// Build deep dive analysis prompt
  static String _buildDeepDivePrompt(
      List<EnhancedDayAnalysis> analysisData,
      DateTime startDate,
      DateTime endDate,
      ) {
    final buffer = StringBuffer();

    buffer.writeln('Please provide a DEEP DIVE psychological analysis of this mood tracking data.');
    buffer.writeln('Go beyond surface patterns - analyze the underlying psychological themes.');
    buffer.writeln('');
    buffer.writeln('DATE RANGE: ${_formatDate(startDate)} to ${_formatDate(endDate)}');
    buffer.writeln('');

    // Add data summary
    buffer.writeln('DATA OVERVIEW:');
    buffer.writeln('- Total days analyzed: ${analysisData.length}');

    // Calculate summary stats
    final allMoods = <double>[];
    final userNotes = <String>[];
    final mentionedActivities = <String>[];
    final sleepIssues = <String>[];
    final stressFactors = <String>[];

    for (final day in analysisData) {
      for (final mood in day.segments.values) {
        allMoods.add(mood.rating);

        // Extract user notes for personalization
        if (mood.note.isNotEmpty) {
          userNotes.add(mood.note.toLowerCase());

          // Look for activity mentions
          if (mood.note.toLowerCase().contains('rock climbing') ||
              mood.note.toLowerCase().contains('climbing')) {
            mentionedActivities.add('rock climbing');
          }
          if (mood.note.toLowerCase().contains('running') ||
              mood.note.toLowerCase().contains('run')) {
            mentionedActivities.add('running');
          }
          if (mood.note.toLowerCase().contains('walk')) {
            mentionedActivities.add('walking/nature walks');
          }
          if (mood.note.toLowerCase().contains('nature')) {
            mentionedActivities.add('nature activities');
          }

          // Look for sleep issues
          if (mood.note.toLowerCase().contains('woke up late') ||
              mood.note.toLowerCase().contains('tired') ||
              mood.note.toLowerCase().contains('sleep')) {
            sleepIssues.add(mood.note);
          }

          // Look for stress factors
          if (mood.note.toLowerCase().contains('work') ||
              mood.note.toLowerCase().contains('stress') ||
              mood.note.toLowerCase().contains('customers') ||
              mood.note.toLowerCase().contains('employees')) {
            stressFactors.add(mood.note);
          }
        }
      }
    }

    if (allMoods.isNotEmpty) {
      final avgMood = allMoods.reduce((a, b) => a + b) / allMoods.length;
      final minMood = allMoods.reduce((a, b) => a < b ? a : b);
      final maxMood = allMoods.reduce((a, b) => a > b ? a : b);

      buffer.writeln('- Average mood: ${avgMood.toStringAsFixed(1)}/10');
      buffer.writeln('- Mood range: ${minMood.toStringAsFixed(1)} - ${maxMood.toStringAsFixed(1)}');
      buffer.writeln('- Volatility: ${(maxMood - minMood).toStringAsFixed(1)} points');
    }

    // Add personalization context
    if (mentionedActivities.isNotEmpty) {
      buffer.writeln('- USER\'S PREFERRED ACTIVITIES: ${mentionedActivities.toSet().join(', ')}');
    }
    if (sleepIssues.isNotEmpty) {
      buffer.writeln('- SLEEP CHALLENGES: User mentions sleep issues like waking up late, tiredness');
    }
    if (stressFactors.isNotEmpty) {
      buffer.writeln('- WORK STRESS FACTORS: Work-related stress from customers, staffing issues');
    }

    buffer.writeln('');
    buffer.writeln('DETAILED DAILY DATA WITH USER NOTES:');

    // Include detailed daily data with emphasis on notes
    for (final day in analysisData) {
      buffer.writeln('${_formatDate(day.date)}:');

      // Mood data with notes
      for (int segment = 0; segment < 3; segment++) {
        final segmentData = day.segments[segment];
        if (segmentData != null) {
          final segmentName = ['Morning', 'Midday', 'Evening'][segment];
          buffer.writeln('  $segmentName: ${segmentData.rating}/10');
          if (segmentData.note.isNotEmpty) {
            buffer.writeln('    USER NOTE: "${segmentData.note}"');
          }
        }
      }

      // Correlation data if available
      if (day.correlationData != null) {
        final corr = day.correlationData!;
        if (corr.sleepQuality != null) {
          buffer.writeln('  Sleep Quality: ${corr.sleepQuality}/10');
        }
        if (corr.exerciseLevel != null) {
          buffer.writeln('  Exercise: ${corr.exerciseLevel!.name}');
        }
        if (corr.workStress != null) {
          buffer.writeln('  Work Stress: ${corr.workStress}/10');
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('ANALYSIS REQUIREMENTS - PERSONALIZED APPROACH:');
    buffer.writeln('1. COMPREHENSIVE CORRELATIONS: Find ALL meaningful correlations');
    buffer.writeln('2. PERSONALIZED BEHAVIORAL TRIGGERS: Use the user\'s actual notes to identify specific triggers');
    buffer.writeln('3. TAILORED MOOD STABILIZATION: Base strategies on user\'s mentioned preferences and challenges');
    buffer.writeln('4. EVIDENCE-BASED BUT PERSONALIZED: Adapt general recommendations to this user\'s lifestyle');
    buffer.writeln('5. SPECIFIC ACTION PLANS: Reference user\'s mentioned activities, sleep patterns, work situation');
    buffer.writeln('');

    buffer.writeln('CRITICAL PERSONALIZATION INSTRUCTIONS:');
    buffer.writeln('- If user mentions rock climbing, suggest related activities like bouldering, outdoor climbing, climbing gyms');
    buffer.writeln('- If user mentions running/walking, suggest trail running, hiking, park walks, nature trails');
    buffer.writeln('- If user mentions sleep issues like "woke up late", suggest specific sleep hygiene tactics');
    buffer.writeln('- If user mentions work stress with customers/staffing, suggest workplace-specific coping strategies');
    buffer.writeln('- Use user\'s own language and references from their notes where appropriate');
    buffer.writeln('- Make action steps specific to their mentioned lifestyle, not generic advice');
    buffer.writeln('');

    buffer.writeln('Format as JSON with this structure:');
    buffer.writeln('{');
    buffer.writeln('  "insights": [');
    buffer.writeln('    {');
    buffer.writeln('      "title": "Personalized Insight Title",');
    buffer.writeln('      "description": "Analysis referencing user\'s specific notes and patterns",');
    buffer.writeln('      "type": "positive|negative|neutral",');
    buffer.writeln('      "actionSteps": ["Specific action referencing user preferences", "Another personalized step", "Third tailored action"]');
    buffer.writeln('    }');
    buffer.writeln('  ],');
    buffer.writeln('  "recommendations": [');
    buffer.writeln('    {');
    buffer.writeln('      "title": "Tailored Intervention Strategy",');
    buffer.writeln('      "description": "Recommendation adapted to user\'s mentioned lifestyle",');
    buffer.writeln('      "priority": "high|medium|low",');
    buffer.writeln('      "actionSteps": ["Step 1 using user\'s preferred activities", "Step 2 addressing their specific challenges", "Step 3 with timeline and user context"]');
    buffer.writeln('    }');
    buffer.writeln('  ]');
    buffer.writeln('}');

    buffer.writeln('');
    buffer.writeln('EXAMPLES OF PERSONALIZED ACTION STEPS:');
    buffer.writeln('Instead of: "Establish consistent sleep schedule"');
    buffer.writeln('Say: "Set phone alarm for 9 AM (earlier than your mentioned 11 AM wake-ups) and place alarm across room"');
    buffer.writeln('');
    buffer.writeln('Instead of: "Try physical activities"');
    buffer.writeln('Say: "Schedule rock climbing sessions 2x/week, try bouldering on rest days, explore new climbing routes"');
    buffer.writeln('');
    buffer.writeln('Instead of: "Manage work stress"');
    buffer.writeln('Say: "Practice 5-minute breathing exercises between difficult customers, suggest staffing solutions to management"');

    return buffer.toString();
  }

  /// Build comparative analysis prompt
  static String _buildComparativePrompt(
      List<EnhancedDayAnalysis> period1Data,
      List<EnhancedDayAnalysis> period2Data,
      DateTime period1Start,
      DateTime period1End,
      DateTime period2Start,
      DateTime period2End,
      ) {
    final buffer = StringBuffer();

    // Determine what these periods actually represent
    final period1Name = _getPeriodName(period1Start, period1End, period2Start, period2End, isEarlier: true);
    final period2Name = _getPeriodName(period1Start, period1End, period2Start, period2End, isEarlier: false);

    buffer.writeln('Compare these two time periods and provide insights on changes, improvements, or concerns.');
    buffer.writeln('IMPORTANT: Use the actual period names, not "Period 1" and "Period 2"');
    buffer.writeln('');
    buffer.writeln('EARLIER PERIOD ($period1Name): ${_formatDate(period1Start)} to ${_formatDate(period1End)}');
    buffer.writeln('RECENT PERIOD ($period2Name): ${_formatDate(period2Start)} to ${_formatDate(period2End)}');
    buffer.writeln('');

    // Calculate averages and collect detailed notes
    final period1Moods = <double>[];
    final period2Moods = <double>[];
    final period1Notes = <String>[];
    final period2Notes = <String>[];
    final period1Activities = <String>[];
    final period2Activities = <String>[];
    final period1Challenges = <String>[];
    final period2Challenges = <String>[];

    // Analyze Period 1 (earlier)
    for (final day in period1Data) {
      for (final mood in day.segments.values) {
        period1Moods.add(mood.rating);
        if (mood.note.isNotEmpty) {
          period1Notes.add(mood.note);

          // Categorize notes
          final note = mood.note.toLowerCase();
          if (note.contains('climbing') || note.contains('running') || note.contains('walk') ||
              note.contains('exercise') || note.contains('gym') || note.contains('nature')) {
            period1Activities.add(mood.note);
          }
          if (note.contains('stress') || note.contains('tired') || note.contains('late') ||
              note.contains('work') || note.contains('customers') || note.contains('difficult')) {
            period1Challenges.add(mood.note);
          }
        }
      }
    }

    // Analyze Period 2 (recent)
    for (final day in period2Data) {
      for (final mood in day.segments.values) {
        period2Moods.add(mood.rating);
        if (mood.note.isNotEmpty) {
          period2Notes.add(mood.note);

          // Categorize notes
          final note = mood.note.toLowerCase();
          if (note.contains('climbing') || note.contains('running') || note.contains('walk') ||
              note.contains('exercise') || note.contains('gym') || note.contains('nature')) {
            period2Activities.add(mood.note);
          }
          if (note.contains('stress') || note.contains('tired') || note.contains('late') ||
              note.contains('work') || note.contains('customers') || note.contains('difficult')) {
            period2Challenges.add(mood.note);
          }
        }
      }
    }

    if (period1Moods.isNotEmpty && period2Moods.isNotEmpty) {
      final period1Avg = period1Moods.reduce((a, b) => a + b) / period1Moods.length;
      final period2Avg = period2Moods.reduce((a, b) => a + b) / period2Moods.length;
      final change = period2Avg - period1Avg;
      final changeDirection = change >= 0 ? 'IMPROVEMENT' : 'DECLINE';

      buffer.writeln('SUMMARY COMPARISON:');
      buffer.writeln('- $period1Name average: ${period1Avg.toStringAsFixed(1)}/10');
      buffer.writeln('- $period2Name average: ${period2Avg.toStringAsFixed(1)}/10');
      buffer.writeln('- Overall change: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} points ($changeDirection)');
      buffer.writeln('- $period1Name days logged: ${period1Data.length}');
      buffer.writeln('- $period2Name days logged: ${period2Data.length}');
    }

    buffer.writeln('');
    buffer.writeln('DETAILED NOTE ANALYSIS FOR ROOT CAUSE IDENTIFICATION:');
    buffer.writeln('');
    buffer.writeln('$period1Name - ACTIVITIES MENTIONED:');
    if (period1Activities.isNotEmpty) {
      for (final activity in period1Activities.take(5)) {
        buffer.writeln('- "$activity"');
      }
    } else {
      buffer.writeln('- No specific activities mentioned');
    }

    buffer.writeln('');
    buffer.writeln('$period1Name - CHALLENGES/STRESSORS:');
    if (period1Challenges.isNotEmpty) {
      for (final challenge in period1Challenges.take(5)) {
        buffer.writeln('- "$challenge"');
      }
    } else {
      buffer.writeln('- No specific challenges mentioned');
    }

    buffer.writeln('');
    buffer.writeln('$period2Name - ACTIVITIES MENTIONED:');
    if (period2Activities.isNotEmpty) {
      for (final activity in period2Activities.take(5)) {
        buffer.writeln('- "$activity"');
      }
    } else {
      buffer.writeln('- No specific activities mentioned');
    }

    buffer.writeln('');
    buffer.writeln('$period2Name - CHALLENGES/STRESSORS:');
    if (period2Challenges.isNotEmpty) {
      for (final challenge in period2Challenges.take(5)) {
        buffer.writeln('- "$challenge"');
      }
    } else {
      buffer.writeln('- No specific challenges mentioned');
    }

    buffer.writeln('');
    buffer.writeln('CRITICAL ANALYSIS REQUIREMENTS:');
    buffer.writeln('1. ALWAYS use "$period1Name" and "$period2Name" - NEVER use "Period 1" or "Period 2"');
    buffer.writeln('2. IDENTIFY ROOT CAUSES: Based on the user notes, explain WHY mood changed');
    buffer.writeln('3. SPECIFIC EVIDENCE: Quote or reference specific user notes that show the cause');
    buffer.writeln('4. ACTIONABLE INSIGHTS: Don\'t ask user to identify factors - YOU identify them from their notes');
    buffer.writeln('5. CONCRETE RECOMMENDATIONS: Based on what worked or didn\'t work in their own words');
    buffer.writeln('');

    buffer.writeln('RESPONSE FORMAT - Use actual period names in titles and descriptions:');
    buffer.writeln('{');
    buffer.writeln('  "insights": [');
    buffer.writeln('    {');
    buffer.writeln('      "title": "Why Your Mood Improved in $period2Name" (or declined),');
    buffer.writeln('      "description": "Based on your notes, the improvement appears linked to [specific factors from notes]. In $period1Name you mentioned [specific challenges], while $period2Name shows [specific positive changes].",');
    buffer.writeln('      "type": "positive|negative|neutral",');
    buffer.writeln('      "actionSteps": ["Continue the specific activities you mentioned in $period2Name", "Avoid the patterns that caused issues in $period1Name", "Build on what clearly worked"]');
    buffer.writeln('    }');
    buffer.writeln('  ],');
    buffer.writeln('  "recommendations": [');
    buffer.writeln('    {');
    buffer.writeln('      "title": "Build on Your $period2Name Success Pattern",');
    buffer.writeln('      "description": "Your notes show that [specific successful strategies] led to better moods in $period2Name",');
    buffer.writeln('      "priority": "high|medium|low",');
    buffer.writeln('      "actionSteps": ["Specifically continue [activity they mentioned]", "Maintain the schedule that worked in $period2Name", "Apply $period2Name strategies to future challenges"]');
    buffer.writeln('    }');
    buffer.writeln('  ]');
    buffer.writeln('}');

    return buffer.toString();
  }

  static String _getPeriodName(DateTime period1Start, DateTime period1End,
      DateTime period2Start, DateTime period2End, {required bool isEarlier}) {
    final now = DateTime.now();
    final targetStart = isEarlier ? period1Start : period2Start;
    final targetEnd = isEarlier ? period1End : period2End;

    // Check if it's a monthly comparison
    final daysDiff = targetEnd.difference(targetStart).inDays;
    final daysFromNow = now.difference(targetEnd).inDays;

    if (daysDiff >= 25 && daysDiff <= 35) { // Monthly comparison
      if (daysFromNow <= 5) {
        return 'This Month';
      } else if (daysFromNow <= 35) {
        return 'Last Month';
      } else if (daysFromNow <= 65) {
        return 'Two Months Ago';
      } else {
        return DateFormat('MMMM yyyy').format(targetStart);
      }
    } else if (daysDiff >= 28 && daysDiff <= 32) { // 30-day comparison
      if (daysFromNow <= 2) {
        return 'Last 30 Days';
      } else if (daysFromNow <= 32) {
        return 'Previous 30 Days';
      } else {
        return '30 Days ending ${DateFormat('MMM d').format(targetEnd)}';
      }
    } else { // Custom range
      return '${DateFormat('MMM d').format(targetStart)} - ${DateFormat('MMM d').format(targetEnd)}';
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

    // CRITICAL: Make action steps mandatory
    buffer.writeln('**IMPORTANT: Each insight and recommendation MUST include specific actionSteps.**');
    buffer.writeln('');

    buffer.writeln('Format your response as JSON with this EXACT structure:');
    buffer.writeln('{');
    buffer.writeln('  "insights": [');
    buffer.writeln('    {');
    buffer.writeln('      "title": "Insight Title",');
    buffer.writeln('      "description": "Detailed explanation",');
    buffer.writeln('      "type": "positive|negative|neutral",');
    buffer.writeln('      "actionSteps": ["Step 1", "Step 2", "Step 3"]');
    buffer.writeln('    }');
    buffer.writeln('  ],');
    buffer.writeln('  "recommendations": [');
    buffer.writeln('    {');
    buffer.writeln('      "title": "Recommendation Title",');
    buffer.writeln('      "description": "Actionable advice",');
    buffer.writeln('      "priority": "high|medium|low",');
    buffer.writeln('      "actionSteps": ["Step 1", "Step 2", "Step 3"]');
    buffer.writeln('    }');
    buffer.writeln('  ]');
    buffer.writeln('}');

    buffer.writeln('');
    buffer.writeln('CRITICAL REQUIREMENTS FOR ACTION STEPS:');
    buffer.writeln('- Each insight MUST have 3-5 actionSteps');
    buffer.writeln('- Each recommendation MUST have 3-5 actionSteps');
    buffer.writeln('- Action steps should be specific and actionable');
    buffer.writeln('- Each step should be under 60 characters');
    buffer.writeln('- Steps should be practical and easy to implement');
    buffer.writeln('- NO empty actionSteps arrays allowed');
    buffer.writeln('');
    buffer.writeln('Example actionSteps for insights:');
    buffer.writeln('["Track when this pattern occurs", "Notice triggers", "Plan preventive actions"]');
    buffer.writeln('');
    buffer.writeln('Example actionSteps for recommendations:');
    buffer.writeln('["Start with 10 minutes daily", "Track progress weekly", "Adjust as needed"]');

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
      Logger.aiService('🔍 Raw AI Response Length: ${aiResponse.length} chars');
      Logger.aiService('🔍 Raw AI Response Preview: ${aiResponse.substring(0, math.min(200, aiResponse.length))}...');

      // Clean up the response to extract JSON
      String cleanedResponse = aiResponse.trim();

      // Find JSON boundaries
      int startIndex = cleanedResponse.indexOf('{');
      int endIndex = cleanedResponse.lastIndexOf('}');

      if (startIndex == -1 || endIndex == -1) {
        Logger.aiService('❌ No JSON found in AI response');
        return MoodAnalysisResult(
          success: false,
          error: 'AI response contained no valid JSON data',
          insights: [],
          recommendations: [],
        );
      }

      cleanedResponse = cleanedResponse.substring(startIndex, endIndex + 1);
      Logger.aiService('🔍 Cleaned JSON: ${cleanedResponse.substring(0, math.min(300, cleanedResponse.length))}...');

      // Fix malformed comparative analysis responses
      if (cleanedResponse.contains('"insights": {') && !cleanedResponse.contains('"insights": [')) {
        Logger.aiService('⚠️ Detected malformed comparative analysis response, attempting to fix...');

        // Try to convert the malformed object structure to the expected array structure
        try {
          final tempParsed = jsonDecode(cleanedResponse) as Map<String, dynamic>;

          if (tempParsed['insights'] is Map) {
            final insightsMap = tempParsed['insights'] as Map<String, dynamic>;
            final insightsArray = <Map<String, dynamic>>[];

            // Convert each key-value pair to a proper insight object
            insightsMap.forEach((key, value) {
              insightsArray.add({
                'title': _formatTitle(key),
                'description': value.toString(),
                'type': _determineInsightType(value.toString()),
                'actionSteps': _generateComparativeActionSteps(key, value.toString()),
              });
            });

            tempParsed['insights'] = insightsArray;

            // If recommendations is also malformed, fix it too
            if (tempParsed['recommendations'] is Map) {
              final recMap = tempParsed['recommendations'] as Map<String, dynamic>;
              final recArray = <Map<String, dynamic>>[];

              recMap.forEach((key, value) {
                recArray.add({
                  'title': _formatTitle(key),
                  'description': value.toString(),
                  'priority': 'medium',
                  'actionSteps': _generateComparativeActionSteps(key, value.toString()),
                });
              });

              tempParsed['recommendations'] = recArray;
            }

            cleanedResponse = jsonEncode(tempParsed);
            Logger.aiService('✅ Successfully converted malformed response to proper format');
          }
        } catch (e) {
          Logger.aiService('❌ Failed to fix malformed response: $e');
        }
      }

      final parsed = jsonDecode(cleanedResponse) as Map<String, dynamic>;

      final insights = <MoodInsight>[];
      final recommendations = <MoodRecommendation>[];

      // Parse insights with enhanced action steps validation
      if (parsed['insights'] is List) {
        for (int i = 0; i < (parsed['insights'] as List).length; i++) {
          final insight = parsed['insights'][i];

          List<String> actionSteps = [];
          if (insight['actionSteps'] is List && (insight['actionSteps'] as List).isNotEmpty) {
            actionSteps = List<String>.from(insight['actionSteps']);
          }

          // Enhanced validation and generation
          actionSteps = _validateAndEnhanceActionSteps(
              actionSteps,
              insight['title'] ?? '',
              insight['description'] ?? ''
          );

          insights.add(MoodInsight(
            title: insight['title'] ?? 'Insight',
            description: insight['description'] ?? '',
            type: _parseInsightType(insight['type']),
            actionSteps: actionSteps,
          ));
        }
      }

      // Parse recommendations with enhanced action steps validation
      if (parsed['recommendations'] is List) {
        for (int i = 0; i < (parsed['recommendations'] as List).length; i++) {
          final rec = parsed['recommendations'][i];

          List<String> actionSteps = [];
          if (rec['actionSteps'] is List && (rec['actionSteps'] as List).isNotEmpty) {
            actionSteps = List<String>.from(rec['actionSteps']);
          }

          // Enhanced validation and generation
          actionSteps = _validateAndEnhanceActionSteps(
              actionSteps,
              rec['title'] ?? '',
              rec['description'] ?? ''
          );

          recommendations.add(MoodRecommendation(
            title: rec['title'] ?? 'Recommendation',
            description: rec['description'] ?? '',
            priority: _parsePriority(rec['priority']),
            actionSteps: actionSteps,
          ));
        }
      }

      Logger.aiService('✅ Parsed ${insights.length} insights and ${recommendations.length} recommendations');
      Logger.aiService('📝 Total action steps: ${insights.fold(0, (sum, i) => sum + i.actionSteps.length) + recommendations.fold(0, (sum, r) => sum + r.actionSteps.length)}');

      return MoodAnalysisResult(
        success: true,
        insights: insights,
        recommendations: recommendations,
      );
    } catch (e) {
      Logger.aiService('❌ Failed to parse AI response: $e');
      return MoodAnalysisResult(
        success: false,
        error: 'Failed to parse AI response: ${e.toString()}',
        insights: [],
        recommendations: [],
      );
    }
  }

  static String _formatTitle(String key) {
    switch (key.toLowerCase()) {
      case 'changes':
        return 'Period-to-Period Changes';
      case 'improvements':
        return 'Positive Improvements';
      case 'concerns':
        return 'Areas of Concern';
      case 'patterns':
        return 'Emerging Patterns';
      default:
        return key.split('_').map((word) =>
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  static String _determineInsightType(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('improvement') || lower.contains('better') ||
        lower.contains('increased') || lower.contains('positive')) {
      return 'positive';
    } else if (lower.contains('decline') || lower.contains('worse') ||
        lower.contains('decreased') || lower.contains('concern')) {
      return 'negative';
    }
    return 'neutral';
  }

  static List<String> _generateComparativeActionSteps(String category, String description) {
    final lower = description.toLowerCase();

    if (lower.contains('improvement') || lower.contains('better') || lower.contains('increased')) {
      return [
        'Continue the specific activities and routines that led to this improvement',
        'Identify the exact timing and conditions when you felt best',
        'Document what was different about your better days for future reference',
        'Build on this positive momentum by expanding successful strategies'
      ];
    } else if (lower.contains('decline') || lower.contains('worse') || lower.contains('decreased')) {
      return [
        'Review what changed between periods that may have caused this decline',
        'Return to the successful strategies from your better period',
        'Address any new stressors or challenges that emerged',
        'Implement preventive measures to avoid similar future declines'
      ];
    } else if (lower.contains('climbing') || lower.contains('exercise') || lower.contains('activity')) {
      return [
        'Maintain the exercise routine that correlated with better moods',
        'Schedule regular climbing/activity sessions as mood stabilizers',
        'Use physical activity as a proactive mood management tool',
        'Track which types of activities have the strongest mood impact'
      ];
    } else if (lower.contains('sleep') || lower.contains('tired') || lower.contains('late')) {
      return [
        'Address the sleep patterns that improved/worsened between periods',
        'Set consistent wake times based on your better period',
        'Create evening routines that support the sleep schedule that worked',
        'Monitor how sleep timing affects next-day mood and energy'
      ];
    } else {
      return [
        'Monitor this pattern for consistency and identify contributing factors',
        'Note any external circumstances that influenced this change',
        'Test specific interventions to see what affects this trend',
        'Keep detailed records of what works best for your unique situation'
      ];
    }
  }

  /// Enhanced validation for action steps
  static List<String> _validateAndEnhanceActionSteps(List<String> actionSteps, String title, String description) {
    Logger.aiService('🔍 Validating action steps for "$title": ${actionSteps.length} steps provided');
    Logger.aiService('🔍 Action steps: $actionSteps');

    if (actionSteps.isEmpty) {
      Logger.aiService('⚠️ No action steps provided, generating personalized fallback');
      // Generate based on keywords in title and description
      final combined = '${title.toLowerCase()} ${description.toLowerCase()}';

      if (combined.contains('sleep') || combined.contains('tired') || combined.contains('woke up late')) {
        return [
          'Set a consistent alarm for 9 AM and place it across the room to avoid snoozing',
          'Create a wind-down routine 1 hour before desired bedtime (no screens, dim lights)',
          'Track which activities help you fall asleep faster vs. keep you awake',
          'Use the "can\'t sleep" time productively - read, journal, or plan tomorrow instead of frustration'
        ];
      } else if (combined.contains('rock climbing') || combined.contains('climbing')) {
        return [
          'Book 2 climbing sessions per week at your preferred gym or outdoor spots',
          'Try bouldering on easier days when you need movement but less intensity',
          'Explore new climbing routes or techniques to maintain motivation and challenge',
          'Connect with climbing community - find climbing partners or join climbing groups'
        ];
      } else if (combined.contains('running') || combined.contains('walk') || combined.contains('nature')) {
        return [
          'Plan specific running/walking routes in natural settings you enjoy',
          'Try trail running or hiking to combine cardio with nature time',
          'Schedule "nature walks" during lunch breaks or after work for stress relief',
          'Explore new parks, trails, or nature areas in your region monthly'
        ];
      } else if (combined.contains('work') || combined.contains('stress') || combined.contains('customers')) {
        return [
          'Practice the 4-7-8 breathing technique between difficult customer interactions',
          'Document staffing concerns and present solutions to management proactively',
          'Create micro-breaks: 30 seconds of deep breathing every hour during busy shifts',
          'Develop 2-3 go-to phrases for de-escalating customer tensions'
        ];
      } else if (combined.contains('morning') || combined.contains('woke up late')) {
        return [
          'Set out everything needed for morning routine the night before',
          'Create a motivating morning playlist or podcast to play immediately upon waking',
          'Schedule something enjoyable for mornings (like planning that rock climbing session)',
          'Use the "5-minute rule" - commit to just 5 minutes of morning activity to build momentum'
        ];
      } else {
        return [
          'Implement this insight gradually, starting with just one small change',
          'Track progress weekly using your mood logging to see what works',
          'Adjust the approach based on your personal results after 2-3 weeks',
          'Build on your existing strengths and interests rather than forcing new habits'
        ];
      }
    }

    // Validate existing action steps and ensure they're specific enough
    final validSteps = actionSteps
        .where((step) => step.trim().isNotEmpty && step.length > 15)
        .take(4)
        .toList();

    // If validated steps are too generic, enhance them
    final enhancedSteps = validSteps.map((step) {
      if (step.toLowerCase().contains('consistent sleep') && !step.contains('9 AM') && !step.contains('11 AM')) {
        return 'Set a consistent wake time of 9 AM (earlier than your mentioned 11 AM wake-ups) using an alarm across the room';
      } else if (step.toLowerCase().contains('explore') && step.toLowerCase().contains('activities') && !step.contains('climbing')) {
        return 'Try activities similar to rock climbing: bouldering, outdoor climbing routes, or climbing gym classes';
      }
      return step;
    }).toList();

    return enhancedSteps;
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
                    'actionSteps': i.actionSteps,
                  })
              .toList(),
          'recommendations': result.recommendations
              .map((r) => {
                    'title': r.title,
                    'description': r.description,
                    'priority': r.priority.name,
                    'actionSteps': r.actionSteps,
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
            type: InsightType.values.firstWhere((t) => t.name == i['type']),
            actionSteps: i['actionSteps'] != null
                ? List<String>.from(i['actionSteps'])
                : [],
          ))
              .toList(),
          recommendations: (json['result']['recommendations'] as List)
              .map((r) => MoodRecommendation(
            title: r['title'],
            description: r['description'],
            priority: RecommendationPriority.values.firstWhere((p) => p.name == r['priority']),
            actionSteps: r['actionSteps'] != null
                ? List<String>.from(r['actionSteps'])
                : [],
          ))
              .toList(),
        ),
      );
}

enum InsightType { positive, negative, neutral }

enum RecommendationPriority { high, medium, low }
