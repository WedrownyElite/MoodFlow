// lib/screens/insights_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/utils/logger.dart';
import '../services/insights/smart_insights_service.dart';
import '../services/ai/mood_analysis_service.dart' as ai_service;
import '../widgets/ai_coach_widget.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<SmartInsight> _insights = [];
  WeeklySummary? _weeklySummary;
  bool _isLoading = false;
  bool _isGenerating = false;

  bool _hasApiKey = false;
  bool _isGeneratingAI = false;
  bool _showAIOptions = false;

  // AI data selection options (same as AI analysis screen)
  bool _includeMoodData = true;
  bool _includeWeatherData = false;
  bool _includeSleepData = false;
  bool _includeActivityData = false;
  bool _includeWorkStressData = false;

  static const String _savedAIInsightsKey = 'saved_insights_ai_analyses';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInsights();
    _checkApiKey();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    try {
      // Use SmartInsightsService instead of the basic one
      final insights = await SmartInsightsService.generateInsights(forceRefresh: false);

      // Generate weekly summary
      final weeklySummary = await SmartInsightsService.generateWeeklySummary();

      setState(() {
        _insights = insights;
        _weeklySummary = weeklySummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading insights: $e')),
        );
      }
    }
  }

  Future<void> _checkApiKey() async {
    final hasKey = await ai_service.MoodAnalysisService.hasValidApiKey();
    setState(() {
      _hasApiKey = hasKey;
    });
  }

  Future<void> _generateNewInsights() async {
    setState(() => _isGenerating = true);

    try {
      final insights = await SmartInsightsService.generateInsights(forceRefresh: true);
      setState(() {
        _insights = insights;
        _isGenerating = false;
      });

      await _loadInsights();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${insights.length} new insights!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating insights: $e')),
        );
      }
    }
  }

  Future<void> _generateAIInsights() async {
    if (!_hasApiKey) {
      _showApiKeyDialog();
      return;
    }

    setState(() => _isGeneratingAI = true);

    try {
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now();

      final aiResult = await ai_service.MoodAnalysisService.analyzeMoodTrendsWithOptions(
        startDate: startDate,
        endDate: endDate,
        includeMoodData: _includeMoodData,
        includeWeatherData: _includeWeatherData,
        includeSleepData: _includeSleepData,
        includeActivityData: _includeActivityData,
        includeWorkStressData: _includeWorkStressData,
      );

      if (aiResult.success) {
        // Save the AI analysis result to insights history (separate from AI analysis screen)
        await _saveInsightsAIAnalysis(aiResult);

        // Convert AI insights to SmartInsights and merge
        final smartInsights = await SmartInsightsService.loadInsights();
        final enhancedInsights = _convertAIInsightsToSmart(aiResult);

        final allInsights = [...enhancedInsights, ...smartInsights];
        setState(() {
          _insights = allInsights;
          _isGeneratingAI = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated ${enhancedInsights.length} AI-powered insights!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(aiResult.error ?? 'AI analysis failed');
      }
    } catch (e) {
      setState(() => _isGeneratingAI = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Save AI analysis result to insights screen history (separate storage)
  Future<void> _saveInsightsAIAnalysis(ai_service.MoodAnalysisResult aiResult) async {
    if (!aiResult.success) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingAnalyses = await _getInsightsAIAnalyses();

      final savedAnalysis = InsightsAIAnalysis(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        result: aiResult,
      );

      existingAnalyses.insert(0, savedAnalysis); // Add to beginning

      // Keep only last 20 analyses
      final limitedAnalyses = existingAnalyses.take(20).toList();

      final jsonData = limitedAnalyses.map((analysis) => analysis.toJson()).toList();
      await prefs.setString(_savedAIInsightsKey, jsonEncode(jsonData));
    } catch (e) {
      Logger.smartInsightService('Error saving insights AI analysis: $e');
    }
  }

  /// Get saved AI analyses from insights screen
  Future<List<InsightsAIAnalysis>> _getInsightsAIAnalyses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_savedAIInsightsKey);

      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((json) => InsightsAIAnalysis.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete an insights AI analysis
  Future<void> _deleteInsightsAIAnalysis(String analysisId) async {
    try {
      final analyses = await _getInsightsAIAnalyses();
      analyses.removeWhere((analysis) => analysis.id == analysisId);

      final prefs = await SharedPreferences.getInstance();
      final jsonData = analyses.map((analysis) => analysis.toJson()).toList();
      await prefs.setString(_savedAIInsightsKey, jsonEncode(jsonData));
    } catch (e) {
      Logger.smartInsightService('Error deleting insights AI analysis: $e');
    }
  }

  List<SmartInsight> _convertAIInsightsToSmart(ai_service.MoodAnalysisResult aiResult) {
    final insights = <SmartInsight>[];
    final now = DateTime.now();

    // Convert AI insights
    for (int i = 0; i < aiResult.insights.length; i++) {
      final insight = aiResult.insights[i];
      insights.add(SmartInsight(
        id: 'ai_insight_${now.millisecondsSinceEpoch}_$i',
        title: '🤖 ${insight.title}',
        description: insight.description,
        type: insight.type == ai_service.InsightType.positive
            ? InsightType.achievement
            : insight.type == ai_service.InsightType.negative
            ? InsightType.concern
            : InsightType.pattern,
        priority: AlertPriority.medium,
        createdAt: now,
        confidence: 0.8,
        actionSteps: insight.actionSteps.isNotEmpty ? insight.actionSteps : null,
      ));
    }

    // Convert AI recommendations
    for (int i = 0; i < aiResult.recommendations.length; i++) {
      final rec = aiResult.recommendations[i];
      insights.add(SmartInsight(
        id: 'ai_rec_${now.millisecondsSinceEpoch}_$i',
        title: '💡 ${rec.title}',
        description: rec.description,
        type: InsightType.suggestion,
        priority: rec.priority == ai_service.RecommendationPriority.high
            ? AlertPriority.high
            : AlertPriority.medium,
        createdAt: now,
        confidence: 0.8,
        actionSteps: rec.actionSteps.isNotEmpty ? rec.actionSteps : null,
      ));
    }

    return insights;
  }
  
  Future<void> _showApiKeyDialog() async {
    final controller = TextEditingController();
    bool isValidating = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enter OpenAI API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('To use AI insights, you need an OpenAI API key:'),
              const SizedBox(height: 8),
              const Text(
                'https://platform.openai.com/api-keys',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !isValidating,
              ),
              if (isValidating) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Validating API key...'),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isValidating ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isValidating ? null : () async {
                if (controller.text.trim().isEmpty) return;
                setDialogState(() => isValidating = true);

                final isValid = await ai_service.MoodAnalysisService.validateAndSaveApiKey(
                    controller.text.trim()
                );

                if (!context.mounted) return;

                if (isValid) {
                  Navigator.of(context).pop(true);
                } else {
                  setDialogState(() => isValidating = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid API key. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _checkApiKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoodFlow Insights'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: _openAiCoach,
            tooltip: 'AI Coach',
          ),
          if (_hasApiKey)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'ai_insights') {
                  setState(() => _showAIOptions = !_showAIOptions);
                } else if (value == 'regular_insights') {
                  _generateNewInsights();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'ai_insights',
                  child: Row(
                    children: [
                      Icon(
                        _isGeneratingAI ? Icons.hourglass_bottom : Icons.psychology,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 8),
                      Text(_showAIOptions ? 'Hide AI Options' : 'AI Insights'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'regular_insights',
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      SizedBox(width: 8),
                      Text('Refresh Insights'),
                    ],
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: _isGenerating
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.psychology),
              onPressed: _isGenerating ? null : _generateNewInsights,
              tooltip: 'Generate insights',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.lightbulb, size: 20), text: 'Smart Insights'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'AI History'),
            Tab(icon: Icon(Icons.trending_up, size: 20), text: 'Predictive'),
            Tab(icon: Icon(Icons.analytics, size: 20), text: 'Patterns'),
            Tab(icon: Icon(Icons.assessment, size: 20), text: 'Summary'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_showAIOptions) _buildAIOptionsPanel(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSmartInsightsTab(),
                _buildHistoryTab(),
                _buildPredictiveTab(),
                _buildPatternsTab(),
                _buildSummaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<InsightsAIAnalysis>>(
      future: _getInsightsAIAnalyses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No AI analysis history yet',
            subtitle: 'Past AI analyses will appear here as you generate them',
            actionText: 'Generate AI Insights',
            onAction: () => _generateAIInsights(),
          );
        }

        final savedAnalyses = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Trigger rebuild
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: savedAnalyses.length,
            itemBuilder: (context, index) {
              final analysis = savedAnalyses[index];
              return _buildSavedAnalysisCard(analysis);
            },
          ),
        );
      },
    );
  }

  Widget _buildSavedAnalysisCard(InsightsAIAnalysis analysis) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          'Analysis from ${DateFormat('MMM d, y').format(analysis.createdAt)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${DateFormat('MMM d').format(analysis.startDate)} - ${DateFormat('MMM d, y').format(analysis.endDate)} • ${DateFormat('h:mm a').format(analysis.createdAt)}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Convert AI results back to Smart Insights and display them properly
                ...(_convertAIInsightsToSmart(analysis.result).map((insight) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildInsightCard(insight),
                    )
                )),

                // Delete button
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await _deleteInsightsAIAnalysis(analysis.id);
                        setState(() {}); // Refresh the list
                      },
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAIOptionsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  Icons.psychology,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Theme.of(context).primaryColor
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI-Powered Insights',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showAIOptions = false),
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Close',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataSelectionRow(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isGeneratingAI
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isGeneratingAI ? 'Analyzing...' : 'Generate AI Insights'),
              onPressed: _isGeneratingAI ? null : _generateAIInsights,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue.shade600
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSelectionRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Include in analysis:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildCompactCheckbox('Moods', Icons.sentiment_satisfied, _includeMoodData,
                    (value) => setState(() => _includeMoodData = value ?? true)),
            _buildCompactCheckbox('Weather', Icons.wb_sunny, _includeWeatherData,
                    (value) => setState(() => _includeWeatherData = value ?? false)),
            _buildCompactCheckbox('Sleep', Icons.bedtime, _includeSleepData,
                    (value) => setState(() => _includeSleepData = value ?? false)),
            _buildCompactCheckbox('Activity', Icons.fitness_center, _includeActivityData,
                    (value) => setState(() => _includeActivityData = value ?? false)),
            _buildCompactCheckbox('Work Stress', Icons.work, _includeWorkStressData,
                    (value) => setState(() => _includeWorkStressData = value ?? false)),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactCheckbox(String label, IconData icon, bool value, ValueChanged<bool?> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value
              ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.blue.shade800.withValues(alpha: 0.3)
              : Theme.of(context).primaryColor.withValues(alpha: 0.1))
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? (Theme.of(context).brightness == Brightness.dark
                ? Colors.blue.shade600
                : Theme.of(context).primaryColor)
                : (Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade600
                : Colors.grey.shade400),
          ),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                icon,
                size: 14,
                color: value
                    ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Theme.of(context).primaryColor)
                    : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600)
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: value
                    ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Theme.of(context).primaryColor)
                    : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade300
                    : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 12,
              color: value
                  ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).primaryColor)
                  : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade500
                  : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInsightsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final actionableInsights = _insights.where(
            (insight) => insight.type == InsightType.actionable ||
            insight.type == InsightType.suggestion
    ).toList();

    if (actionableInsights.isEmpty) {
      return _buildEmptyStateWithAIOptions();
    }

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: actionableInsights.length,
        itemBuilder: (context, index) {
          final insight = actionableInsights[index];
          return _buildInsightCard(insight);
        },
      ),
    );
  }
  
  Widget _buildEmptyStateWithAIOptions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Insights Loading...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep logging your moods to unlock personalized insights!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),

            // Show AI options if user has API key
            if (_hasApiKey) ...[
              _buildAIOptionsPanel(),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              icon: const Icon(Icons.psychology),
              label: const Text('Generate Insights'),
              onPressed: _generateNewInsights,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictiveTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final predictiveInsights = _insights.where(
            (insight) => insight.type == InsightType.prediction ||
            insight.type == InsightType.concern
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('🔮 Tomorrow\'s Forecast', 'Based on your patterns'),
          const SizedBox(height: 12),

          // Tomorrow's prediction card
          _buildTomorrowForecastCard(),

          const SizedBox(height: 24),

          // Predictive insights
          if (predictiveInsights.isNotEmpty) ...[
            _buildSectionHeader('🎯 Proactive Recommendations', 'Get ahead of challenges'),
            const SizedBox(height: 12),
            ...predictiveInsights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildInsightCard(insight),
            )),
          ],

          const SizedBox(height: 24),

          // Weekly pattern forecast
          _buildWeeklyForecastCard(),

          const SizedBox(height: 24),

          // Early warning system
          _buildEarlyWarningCard(),
        ],
      ),
    );
  }

  Widget _buildPatternsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final patternInsights = _insights.where(
            (insight) => insight.type == InsightType.pattern ||
            insight.type == InsightType.achievement
    ).toList();

    if (patternInsights.isEmpty) {
      return _buildEmptyState(
        icon: Icons.analytics_outlined,
        title: 'No patterns found yet',
        subtitle: 'Log daily factors like weather, sleep, and activities to discover what affects your mood!',
        actionText: 'Log Daily Factors',
        onAction: () => Navigator.pushNamed(context, '/correlation'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: patternInsights.length,
      itemBuilder: (context, index) {
        final insight = patternInsights[index];
        return _buildInsightCard(insight);
      },
    );
  }

  Widget _buildSummaryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_weeklySummary == null) {
      return const Center(
        child: Text('Unable to generate weekly summary'),
      );
    }

    return _buildWeeklySummaryContent(_weeklySummary!);
  }

  Widget _buildInsightCard(SmartInsight insight) {
    Color primaryColor;
    IconData primaryIcon;

    switch (insight.type) {
      case InsightType.actionable:
        primaryColor = Colors.blue;
        primaryIcon = Icons.rocket_launch;
        break;
      case InsightType.prediction:
        primaryColor = Colors.purple;
        primaryIcon = Icons.auto_awesome;
        break;
      case InsightType.achievement:
        primaryColor = Colors.green;
        primaryIcon = Icons.emoji_events;
        break;
      case InsightType.celebration:
        primaryColor = Colors.amber;
        primaryIcon = Icons.celebration;
        break;
      case InsightType.concern:
        primaryColor = Colors.red;
        primaryIcon = Icons.warning;
        break;
      case InsightType.pattern:
        primaryColor = Colors.indigo;
        primaryIcon = Icons.insights;
        break;
      case InsightType.suggestion:
        primaryColor = Colors.orange;
        primaryIcon = Icons.lightbulb;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _handleInsightTap(insight),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and priority
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      primaryIcon,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        if (insight.confidence != null) ...[
                          const SizedBox(height: 4),
                          _buildConfidenceIndicator(insight.confidence!),
                        ],
                      ],
                    ),
                  ),
                  _buildPriorityBadge(insight.priority),
                ],
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                insight.description,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey.shade700,
                ),
              ),

              // Action steps if available
              if (insight.actionSteps != null && insight.actionSteps!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.checklist,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Action Plan',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...insight.actionSteps!.take(3).map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 6, right: 12),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                step,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )),
                      if (insight.actionSteps!.length > 3) ...[
                        Text(
                          '+ ${insight.actionSteps!.length - 3} more steps',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Footer with time and action
              Row(
                children: [
                  Text(
                    _formatInsightTime(insight.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  if (insight.actionText != null)
                    ElevatedButton(
                      onPressed: () => _handleInsightAction(insight),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        insight.actionText!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTomorrowForecastCard() {
    final tomorrowInsights = _insights.where(
            (insight) => insight.type == InsightType.prediction &&
            insight.title.contains('Tomorrow')
    ).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        // Remove decoration entirely - let Card handle the background
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.wb_twilight,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tomorrow\'s Mood Forecast',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AI Powered',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Forecast content
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade600
                      : Colors.purple.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now().add(const Duration(days: 1))),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (tomorrowInsights.isNotEmpty && tomorrowInsights.first.data.containsKey('predictedMood'))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getMoodColor(tomorrowInsights.first.data['predictedMood'] ?? 7.0).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(tomorrowInsights.first.data['predictedMood'] ?? 7.0).toStringAsFixed(1)}/10 Expected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getMoodColor(tomorrowInsights.first.data['predictedMood'] ?? 7.0),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tomorrowInsights.isNotEmpty
                        ? tomorrowInsights.first.description
                        : 'Based on your patterns, tomorrow looks like a good day to focus on your wellbeing!',
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyForecastCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_view_week, color: Colors.indigo, size: 20),
                SizedBox(width: 8),
                Text(
                  'This Week\'s Pattern Forecast',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Week overview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Based on your patterns: Plan challenging tasks for mornings and save relaxing activities for evenings.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarlyWarningCard() {
    final warningInsights = _insights.where(
            (insight) => insight.type == InsightType.concern
    ).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Early Warning System',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              warningInsights.isNotEmpty
                  ? warningInsights.first.description
                  : 'We\'ll monitor your patterns and alert you before potential mood dips. Stay one step ahead!',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(double confidence) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.grey.shade300,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: confidence,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: confidence > 0.7
                    ? Colors.green
                    : confidence > 0.4
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(confidence * 100).round()}% confidence',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklySummaryContent(WeeklySummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Weekly Summary',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('MMM d').format(summary.weekStart)} - ${DateFormat('MMM d, y').format(summary.weekEnd)}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 24),

          // Overview stats
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Average Mood',
                  value: summary.averageMood > 0
                      ? summary.averageMood.toStringAsFixed(1)
                      : '-',
                  color: _getMoodColor(summary.averageMood),
                  icon: Icons.sentiment_satisfied,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Days Logged',
                  value: '${summary.daysLogged}/${summary.totalDays}',
                  color: Colors.blue,
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Best Day',
                  value: summary.bestDay > 0
                      ? summary.bestDay.toStringAsFixed(1)
                      : '-',
                  color: Colors.green,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStatCard(
                  title: 'Trend',
                  value: summary.trend.substring(0, 1).toUpperCase() +
                      summary.trend.substring(1),
                  color: _getTrendColor(summary.trend),
                  icon: _getTrendIcon(summary.trend),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Highlights
          if (summary.highlights.isNotEmpty) ...[
            _buildSectionHeader('⭐ Highlights', 'What went well'),
            const SizedBox(height: 12),
            ...summary.highlights.map((highlight) => _buildSummaryItem(
              highlight,
              Icons.star,
              Colors.green,
            )),
            const SizedBox(height: 16),
          ],

          // Concerns
          if (summary.concerns.isNotEmpty) ...[
            _buildSectionHeader('⚠️ Areas to Watch', 'Things to be mindful of'),
            const SizedBox(height: 12),
            ...summary.concerns.map((concern) => _buildSummaryItem(
              concern,
              Icons.warning,
              Colors.orange,
            )),
            const SizedBox(height: 16),
          ],

          // Recommendations
          if (summary.recommendations.isNotEmpty) ...[
            _buildSectionHeader('💡 Suggestions', 'Ways to improve'),
            const SizedBox(height: 12),
            ...summary.recommendations
                .map((recommendation) => _buildSummaryItem(
              recommendation,
              Icons.lightbulb,
              Colors.blue,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.psychology),
                label: Text(actionText),
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods for UI components
  Widget _buildPriorityBadge(AlertPriority priority) {
    Color color;
    String text;

    switch (priority) {
      case AlertPriority.critical:
        color = Colors.red;
        text = 'URGENT';
        break;
      case AlertPriority.high:
        color = Colors.orange;
        text = 'HIGH';
        break;
      case AlertPriority.medium:
        color = Colors.blue;
        text = 'MED';
        break;
      case AlertPriority.low:
        color = Colors.grey;
        text = 'LOW';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSummaryStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColor(double mood) {
    if (mood == 0) return Colors.grey;
    final intensity = (mood - 1) / 9;

    if (intensity < 0.3) {
      return Colors.red.shade600;
    } else if (intensity < 0.7) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'improving':
        return Colors.green;
      case 'declining':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'improving':
        return Icons.trending_up;
      case 'declining':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  String _formatInsightTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleInsightTap(SmartInsight insight) {
    // Show detailed view with expanded action steps
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildInsightDetailSheet(insight),
    );
  }

  void _handleInsightAction(SmartInsight insight) {
    if (insight.actionRoute != null) {
      Navigator.pushNamed(context, insight.actionRoute!);
    } else {
      // Show action steps or detailed view
      _handleInsightTap(insight);
    }
  }

  Widget _buildInsightDetailSheet(SmartInsight insight) {
    Color primaryColor;
    IconData primaryIcon;

    switch (insight.type) {
      case InsightType.actionable:
        primaryColor = Colors.blue;
        primaryIcon = Icons.rocket_launch;
        break;
      case InsightType.prediction:
        primaryColor = Colors.purple;
        primaryIcon = Icons.auto_awesome;
        break;
      case InsightType.achievement:
        primaryColor = Colors.green;
        primaryIcon = Icons.emoji_events;
        break;
      case InsightType.celebration:
        primaryColor = Colors.amber;
        primaryIcon = Icons.celebration;
        break;
      case InsightType.concern:
        primaryColor = Colors.red;
        primaryIcon = Icons.warning;
        break;
      case InsightType.pattern:
        primaryColor = Colors.indigo;
        primaryIcon = Icons.insights;
        break;
      case InsightType.suggestion:
        primaryColor = Colors.orange;
        primaryIcon = Icons.lightbulb;
        break;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          primaryIcon,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPriorityBadge(insight.priority),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (insight.confidence != null) ...[
                    const SizedBox(height: 16),
                    _buildConfidenceIndicator(insight.confidence!),
                  ],

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    insight.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),

                  // Full action steps if available
                  if (insight.actionSteps != null && insight.actionSteps!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Complete Action Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...insight.actionSteps!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade600
                                : primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 32),

                  // Data or additional info
                  if (insight.data.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade600
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Insights',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...insight.data.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key}: ',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Expanded(
                                  child: Text(entry.value.toString()),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                      if (insight.actionRoute != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.pushNamed(context, insight.actionRoute!);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(insight.actionText ?? 'Take Action'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAiCoach() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Expanded(child: AiCoachWidget()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class for AI analyses generated from insights screen
class InsightsAIAnalysis {
  final String id;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final ai_service.MoodAnalysisResult result;

  InsightsAIAnalysis({
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
        'actionSteps': r.actionSteps,
      })
          .toList(),
    },
  };

  factory InsightsAIAnalysis.fromJson(Map<String, dynamic> json) => InsightsAIAnalysis(
    id: json['id'],
    createdAt: DateTime.parse(json['createdAt']),
    startDate: DateTime.parse(json['startDate']),
    endDate: DateTime.parse(json['endDate']),
    result: ai_service.MoodAnalysisResult(
      success: json['result']['success'],
      insights: (json['result']['insights'] as List)
          .map((i) => ai_service.MoodInsight(
        title: i['title'],
        description: i['description'],
        type: ai_service.InsightType.values
            .firstWhere((t) => t.name == i['type']),
      ))
          .toList(),
      recommendations: (json['result']['recommendations'] as List)
          .map((r) => ai_service.MoodRecommendation(
        title: r['title'],
        description: r['description'],
        priority: ai_service.RecommendationPriority.values
            .firstWhere((p) => p.name == r['priority']),
        actionSteps: r['actionSteps'] != null
            ? List<String>.from(r['actionSteps'])
            : [],
      ))
          .toList(),
    ),
  );
}