import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ai/mood_analysis_service.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../services/utils/ai_coach_helper.dart';
import '../services/ai/ai_provider_service.dart';
import '../widgets/ai_provider_settings.dart';

enum AnalysisType {
  deepDive,
  comparative,
  predictive,
  behavioral
}

class AIAnalysisScreen extends StatefulWidget {
  const AIAnalysisScreen({super.key});

  @override
  State<AIAnalysisScreen> createState() => _AIAnalysisScreenState();
}

class _AIAnalysisScreenState extends State<AIAnalysisScreen>
    with TickerProviderStateMixin {
  MoodAnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  bool _hasValidKey = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  late TabController _tabController;
  List<SavedAnalysis> _savedAnalyses = [];

  // Data selection options
  bool _includeMoodData = true;
  bool _includeWeatherData = false;
  bool _includeSleepData = false;
  bool _includeActivityData = false;
  bool _includeWorkStressData = false;

  AIProvider _selectedProvider = AIProvider.openai;
  String _selectedModel = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkApiKey();
    _loadAISettings();
    _loadSavedAnalyses();
  }

  Future<void> _loadAISettings() async {
    final provider = await MoodAnalysisService.getSelectedProvider();
    final model = await MoodAnalysisService.getSelectedModel();
    setState(() {
      _selectedProvider = provider;
      _selectedModel = model;
    });
  }

  void _onProviderChanged(AIProvider provider, String model) async {
    await MoodAnalysisService.setSelectedProvider(provider);
    await MoodAnalysisService.setSelectedModel(model);
    setState(() {
      _selectedProvider = provider;
      _selectedModel = model;
      _analysisResult = null; // Clear previous results
    });
  }

  Future<void> _checkApiKey() async {
    final provider = await MoodAnalysisService.getSelectedProvider();
    final hasKey = await AIProviderService.hasValidApiKey(provider);
    setState(() {
      _hasValidKey = hasKey;
    });
  }

  Future<void> _selectDateRange() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => CustomDateRangePickerDialog(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result['startDate']!;
        _endDate = result['endDate']!;
        _analysisResult = null; // Clear previous results when date changes
      });
    }
  }

  Future<void> _performAnalysis(AnalysisType analysisType) async {
    // Check if at least mood data is selected
    if (!_includeMoodData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least mood data for analysis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    MoodAnalysisResult result;

    switch (analysisType) {
      case AnalysisType.deepDive:
        result = await MoodAnalysisService.performDeepDiveAnalysis(
          startDate: _startDate,
          endDate: _endDate,
          includeMoodData: _includeMoodData,
          includeWeatherData: _includeWeatherData,
          includeSleepData: _includeSleepData,
          includeActivityData: _includeActivityData,
          includeWorkStressData: _includeWorkStressData,
        );
        break;
      case AnalysisType.comparative:
        result = await _performComparativeAnalysis();
        break;
      case AnalysisType.predictive:
        result = await MoodAnalysisService.performPredictiveAnalysis(
          startDate: _startDate,
          endDate: _endDate,
        );
        break;
      case AnalysisType.behavioral:
        result = await MoodAnalysisService.performBehavioralAnalysis(
          startDate: _startDate,
          endDate: _endDate,
        );
        break;
    }

    setState(() {
      _analysisResult = result;
      _isAnalyzing = false;
    });

    // Save successful analysis
    if (result.success) {
      await MoodAnalysisService.saveAnalysisResult(result, _startDate, _endDate);
      await _loadSavedAnalyses();
    }
  }

  Future<void> _showComparativeAnalysisDialog() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compare Time Periods'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select two time periods to compare your mood patterns:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('This Month vs Last Month'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                final now = DateTime.now();
                final thisMonth = DateTime(now.year, now.month, 1);
                final lastMonth = DateTime(now.year, now.month - 1, 1);
                Navigator.of(context).pop({
                  'period1Start': lastMonth,
                  'period1End': thisMonth.subtract(const Duration(days: 1)),
                  'period2Start': thisMonth,
                  'period2End': now,
                });
              },
            ),
            ListTile(
              title: const Text('Last 30 Days vs Previous 30 Days'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                final now = DateTime.now();
                final period2Start = now.subtract(const Duration(days: 30));
                final period1Start = now.subtract(const Duration(days: 60));
                Navigator.of(context).pop({
                  'period1Start': period1Start,
                  'period1End': period2Start.subtract(const Duration(days: 1)),
                  'period2Start': period2Start,
                  'period2End': now,
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _performComparativeAnalysisWithPeriods(result);
    }
  }

  Future<void> _performComparativeAnalysisWithPeriods(Map<String, DateTime> periods) async {
    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    final result = await MoodAnalysisService.performComparativeAnalysis(
      period1Start: periods['period1Start']!,
      period1End: periods['period1End']!,
      period2Start: periods['period2Start']!,
      period2End: periods['period2End']!,
      includeMoodData: _includeMoodData,
      includeWeatherData: _includeWeatherData,
      includeSleepData: _includeSleepData,
      includeActivityData: _includeActivityData,
      includeWorkStressData: _includeWorkStressData,
    );

    setState(() {
      _analysisResult = result;
      _isAnalyzing = false;
    });

    if (result.success) {
      await MoodAnalysisService.saveAnalysisResult(result, _startDate, _endDate);
      await _loadSavedAnalyses();
    }
  }

  Future<MoodAnalysisResult> _performComparativeAnalysis() async {
    await _showComparativeAnalysisDialog();
    return MoodAnalysisResult(
      success: true,
      insights: [],
      recommendations: [],
    );
  }

  Future<void> _loadSavedAnalyses() async {
    final analyses = await MoodAnalysisService.getSavedAnalyses();
    setState(() {
      _savedAnalyses = analyses;
    });
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Important Disclaimer'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Analysis Disclaimer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                '• This analysis is generated by artificial intelligence (OpenAI\'s GPT) and is for informational purposes only.',
              ),
              SizedBox(height: 8),
              Text(
                '• The recommendations provided are NOT professional medical, psychological, or behavioral health advice.',
              ),
              SizedBox(height: 8),
              Text(
                '• OddologyInc and this app are not responsible for any actions taken based on AI-generated content.',
              ),
              SizedBox(height: 8),
              Text(
                '• If you are experiencing mental health concerns, please consult with a qualified healthcare professional or counselor.',
              ),
              SizedBox(height: 8),
              Text(
                '• This tool is designed to help you reflect on patterns in your mood tracking data, not to diagnose or treat any condition.',
              ),
              SizedBox(height: 12),
              Text(
                'By using this feature, you acknowledge and accept these limitations.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSelectionCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Analysis provides deep psychological insights and behavioral recommendations beyond basic pattern detection.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data to Include in Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Select which types of data to include:',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 8),

            // Make checkboxes more compact
            _buildCompactCheckbox(
              'Mood Data',
              'Daily mood ratings and notes',
              Icons.sentiment_satisfied,
              _includeMoodData,
              (value) => setState(() => _includeMoodData = value ?? true),
            ),

            _buildCompactCheckbox(
              'Weather Data',
              'Weather conditions and temperature',
              Icons.wb_sunny,
              _includeWeatherData,
              (value) => setState(() => _includeWeatherData = value ?? false),
            ),

            _buildCompactCheckbox(
              'Sleep Data',
              'Sleep quality, duration, and schedule',
              Icons.bedtime,
              _includeSleepData,
              (value) => setState(() => _includeSleepData = value ?? false),
            ),

            _buildCompactCheckbox(
              'Activity Data',
              'Exercise levels and social activities',
              Icons.fitness_center,
              _includeActivityData,
              (value) => setState(() => _includeActivityData = value ?? false),
            ),

            _buildCompactCheckbox(
              'Work Stress Data',
              'Work stress levels and patterns',
              Icons.work,
              _includeWorkStressData,
              (value) =>
                  setState(() => _includeWorkStressData = value ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCheckbox(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade300
                            : Colors.blueGrey.shade600
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mood Analysis'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: () => AiCoachHelper.openAiCoach(context),
            tooltip: 'AI Coach',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDisclaimer,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Current Analysis'),
            Tab(text: 'Analysis History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentAnalysisTab(),
          _buildAnalysisHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildAnalysisHistoryTab() {
    if (_savedAnalyses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No previous analyses',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Run an analysis to see your history here',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedAnalyses.length,
      itemBuilder: (context, index) {
        final analysis = _savedAnalyses[index];
        return _buildSavedAnalysisCard(analysis);
      },
    );
  }

  Widget _buildSavedAnalysisCard(SavedAnalysis analysis) {
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
                // Insights section
                if (analysis.result.insights.isNotEmpty) ...[
                  const Text('Key Insights',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...analysis.result.insights.map((insight) => _buildHistoryInsightCard(insight)),
                  const SizedBox(height: 16),
                ],

                // Recommendations section
                if (analysis.result.recommendations.isNotEmpty) ...[
                  const Text('Recommendations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...analysis.result.recommendations.map((rec) => _buildHistoryRecommendationCard(rec)),
                ],

                // Delete button
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await MoodAnalysisService.deleteSavedAnalysis(analysis.id);
                        await _loadSavedAnalyses();
                      },
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  Widget _buildHistoryInsightCard(MoodInsight insight) {
    Color color;
    IconData icon;

    switch (insight.type) {
      case InsightType.positive:
        color = Colors.green;
        icon = Icons.trending_up;
        break;
      case InsightType.negative:
        color = Colors.red;
        icon = Icons.trending_down;
        break;
      case InsightType.neutral:
        color = Colors.blue;
        icon = Icons.insights;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            insight.description,
            style: const TextStyle(fontSize: 13),
          ),

          // Show action steps if they exist
          if (insight.actionSteps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.checklist, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Action Steps:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...insight.actionSteps.map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(fontSize: 12, height: 1.2),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryRecommendationCard(MoodRecommendation recommendation) {
    Color color;
    IconData icon;

    switch (recommendation.priority) {
      case RecommendationPriority.high:
        color = Colors.red;
        icon = Icons.priority_high;
        break;
      case RecommendationPriority.medium:
        color = Colors.orange;
        icon = Icons.star;
        break;
      case RecommendationPriority.low:
        color = Colors.blue;
        icon = Icons.lightbulb;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  recommendation.priority.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.description,
            style: const TextStyle(fontSize: 13),
          ),

          // Show action steps if they exist
          if (recommendation.actionSteps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_turned_in, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Action Plan:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...recommendation.actionSteps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(fontSize: 12, height: 1.2),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentAnalysisTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Disclaimer banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI analysis for informational purposes only. Not professional health advice.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _showDisclaimer,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date range selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Date Range: ${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Change'),
                  onPressed: _selectDateRange,
                ),
              ],
            ),
          ),

          // Data selection card
          _buildDataSelectionCard(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Deep Analysis Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _isAnalyzing
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.psychology),
                    label: Text(_isAnalyzing ? 'Analyzing...' : 'Deep Dive Analysis'),
                    onPressed: (_isAnalyzing || !_hasValidKey) ? null : () async => await _performAnalysis(AnalysisType.deepDive),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.indigo.shade600
                          : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Comparative Analysis Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Compare Time Periods'),
                    onPressed: (_isAnalyzing || !_hasValidKey) ? null : () => _showComparativeAnalysisDialog(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // AI Provider Settings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AIProviderSettings(
              title: 'AI Provider Configuration',
              currentProvider: _selectedProvider,
              currentModel: _selectedModel,
              onProviderChanged: _onProviderChanged,
            ),
          ),

          // Content area
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_hasValidKey) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.key, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'API Key Required for ${AIProviderService.getProviderDisplayName(_selectedProvider)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your API key in the settings below to use AI analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            AIProviderSettings(
              title: 'AI Provider Configuration',
              currentProvider: _selectedProvider,
              currentModel: _selectedModel,
              onProviderChanged: _onProviderChanged,
            ),
          ],
        ),
      );
    }

    if (_analysisResult == null && !_isAnalyzing) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ready to Analyze',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your date range and data types, then click "Analyze My Moods" to get AI insights.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_isAnalyzing) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI is analyzing your mood patterns...'),
            SizedBox(height: 8),
            Text(
              'This may take a few seconds',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (!_analysisResult!.success) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Analysis Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _analysisResult!.error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'This might be due to:\n• API rate limits\n• Invalid API key\n• Network issues\n• Insufficient mood data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _performAnalysis(AnalysisType.deepDive),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insights section
          if (_analysisResult!.insights.isNotEmpty) ...[
            const Text(
              'Key Insights',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._analysisResult!.insights
                .map((insight) => _buildInsightCard(insight)),
            const SizedBox(height: 24),
          ],

          // Recommendations section
          if (_analysisResult!.recommendations.isNotEmpty) ...[
            const Text(
              'Recommendations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._analysisResult!.recommendations
                .map((rec) => _buildRecommendationCard(rec)),
          ],

          // Add bottom padding to prevent cutoff
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInsightCard(MoodInsight insight) {
    Color color;
    IconData icon;

    switch (insight.type) {
      case InsightType.positive:
        color = Colors.green;
        icon = Icons.trending_up;
        break;
      case InsightType.negative:
        color = Colors.red;
        icon = Icons.trending_down;
        break;
      case InsightType.neutral:
        color = Colors.blue;
        icon = Icons.insights;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight.description,
              style: const TextStyle(fontSize: 14),
            ),

            // ALWAYS show action steps if they exist
            if (insight.actionSteps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          'Action Steps:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...insight.actionSteps.map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(MoodRecommendation recommendation) {
    Color color;
    IconData icon;

    switch (recommendation.priority) {
      case RecommendationPriority.high:
        color = Colors.red;
        icon = Icons.priority_high;
        break;
      case RecommendationPriority.medium:
        color = Colors.orange;
        icon = Icons.star;
        break;
      case RecommendationPriority.low:
        color = Colors.blue;
        icon = Icons.lightbulb;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    recommendation.priority.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.description,
              style: const TextStyle(fontSize: 14),
            ),

            // ALWAYS show action steps if they exist
            if (recommendation.actionSteps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_turned_in, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          'Action Plan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...recommendation.actionSteps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                step,
                                style: const TextStyle(fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
