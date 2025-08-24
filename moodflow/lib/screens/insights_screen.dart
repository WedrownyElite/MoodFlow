// lib/screens/insights_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/insights/smart_insights_service.dart';
import '../services/data/correlation_data_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<SmartInsight> _insights = [];
  List<CorrelationInsight> _correlations = [];
  WeeklySummary? _weeklySummary;
  bool _isLoading = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInsights();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    try {
      // Load existing insights
      final insights = await SmartInsightsService.loadInsights();

      // Load correlation insights
      final correlations = await CorrelationDataService.generateInsights();

      // Generate weekly summary
      final weeklySummary = await SmartInsightsService.generateWeeklySummary();

      setState(() {
        _insights = insights;
        _correlations = correlations;
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

  Future<void> _generateNewInsights() async {
    setState(() => _isGenerating = true);

    try {
      final insights = await SmartInsightsService.generateInsights(forceRefresh: true);
      setState(() {
        _insights = insights;
        _isGenerating = false;
      });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Insights'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
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
                : const Icon(Icons.refresh),
            onPressed: _isGenerating ? null : _generateNewInsights,
            tooltip: 'Generate new insights',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.lightbulb, size: 20), text: 'Insights'),
            Tab(icon: Icon(Icons.analytics, size: 20), text: 'Patterns'),
            Tab(icon: Icon(Icons.assessment, size: 20), text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInsightsTab(),
          _buildPatternsTab(),
          _buildSummaryTab(),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_insights.isEmpty) {
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
                'No insights yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep logging your moods and daily factors to generate personalized insights!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
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

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _insights.length,
        itemBuilder: (context, index) {
          final insight = _insights[index];
          return _buildInsightCard(insight);
        },
      ),
    );
  }

  Widget _buildInsightCard(SmartInsight insight) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _handleInsightTap(insight),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and priority
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getInsightColor(insight.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getInsightIcon(insight.type),
                      color: _getInsightColor(insight.type),
                      size: 20,
                    ),
                  ),
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
                  _buildPriorityBadge(insight.priority),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                insight.description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),

              const SizedBox(height: 12),

              // Footer with time and action
              Row(
                children: [
                  Text(
                    _formatInsightTime(insight.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (insight.actionText != null)
                    TextButton(
                      onPressed: () => _handleInsightAction(insight),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        insight.actionText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildPatternsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_correlations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No patterns found yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log daily factors like weather, sleep, and activities to discover what affects your mood!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_chart),
                label: const Text('Log Daily Factors'),
                onPressed: () {
                  Navigator.pushNamed(context, '/correlation');
                },
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _correlations.length,
      itemBuilder: (context, index) {
        final correlation = _correlations[index];
        return _buildCorrelationCard(correlation);
      },
    );
  }

  Widget _buildCorrelationCard(CorrelationInsight correlation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(correlation.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(correlation.category),
                    color: _getCategoryColor(correlation.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    correlation.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStrengthIndicator(correlation.strength),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              correlation.description,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),

            // Strength bar
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Correlation strength',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${(correlation.strength * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(correlation.category),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: correlation.strength,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getCategoryColor(correlation.category),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

    final summary = _weeklySummary!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Weekly Summary',
            style: const TextStyle(
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
            const Text(
              'Highlights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
            const Text(
              'Areas to Watch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
            const Text(
              'Suggestions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...summary.recommendations.map((recommendation) => _buildSummaryItem(
              recommendation,
              Icons.lightbulb,
              Colors.blue,
            )),
          ],
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildStrengthIndicator(double strength) {
    Color color;
    String text;

    if (strength >= 0.7) {
      color = Colors.green;
      text = 'STRONG';
    } else if (strength >= 0.4) {
      color = Colors.orange;
      text = 'MODERATE';
    } else {
      color = Colors.grey;
      text = 'WEAK';
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

  // Helper methods
  Color _getInsightColor(InsightType type) {
    switch (type) {
      case InsightType.achievement:
        return Colors.green;
      case InsightType.celebration:
        return Colors.purple;
      case InsightType.concern:
        return Colors.red;
      case InsightType.pattern:
        return Colors.blue;
      case InsightType.suggestion:
        return Colors.orange;
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.achievement:
        return Icons.emoji_events;
      case InsightType.celebration:
        return Icons.celebration;
      case InsightType.concern:
        return Icons.warning;
      case InsightType.pattern:
        return Icons.insights;
      case InsightType.suggestion:
        return Icons.lightbulb;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'weather':
        return Colors.orange;
      case 'sleep':
        return Colors.indigo;
      case 'exercise':
        return Colors.green;
      case 'social':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'weather':
        return Icons.wb_sunny;
      case 'sleep':
        return Icons.bedtime;
      case 'exercise':
        return Icons.fitness_center;
      case 'social':
        return Icons.people;
      default:
        return Icons.category;
    }
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
    // Mark as read if not already
    if (!insight.isRead) {
      // Would implement marking as read in the service
    }

    // Show detailed view or action
    if (insight.actionRoute != null) {
      Navigator.pushNamed(context, insight.actionRoute!);
    }
  }

  void _handleInsightAction(SmartInsight insight) {
    if (insight.actionRoute != null) {
      Navigator.pushNamed(context, insight.actionRoute!);
    } else {
      // Default action - show more details
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(insight.title),
          content: Text(insight.description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}