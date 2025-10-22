import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_trends_service.dart';
import '../widgets/mood_line_chart.dart';
import '../widgets/mood_heatmap.dart';
import '../widgets/mood_statistics_cards.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../services/utils/logger.dart';
import '../services/utils/ai_coach_helper.dart';

enum TimeRange { week, month, quarter, year, all, custom }

class MoodTrendsScreen extends StatefulWidget {
  const MoodTrendsScreen({super.key});

  @override
  State<MoodTrendsScreen> createState() => _MoodTrendsScreenState();
}

class _MoodTrendsScreenState extends State<MoodTrendsScreen>
    with WidgetsBindingObserver {
  TimeRange _selectedRange = TimeRange.month;
  ChartAggregation _chartAggregation = ChartAggregation.daily;
  List<DayMoodData> _trendData = [];
  MoodStatistics _statistics = MoodStatistics.empty();
  bool _isLoading = true;

  // Custom date range
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTrendData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadTrendData() async {
    setState(() => _isLoading = true);

    try {
      final endDate = DateTime.now();
      late DateTime startDate;

      // Optimize date ranges - keep them reasonable
      switch (_selectedRange) {
        case TimeRange.week:
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case TimeRange.month:
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        case TimeRange.quarter:
          startDate = endDate.subtract(const Duration(days: 90));
          break;
        case TimeRange.year:
          startDate = endDate.subtract(const Duration(days: 365));
          break;
        case TimeRange.all:
          final earliestDate = await MoodTrendsService.getEarliestMoodDate();
          if (earliestDate != null) {
            startDate = earliestDate;
          } else {
            // If no moods exist, default to 30 days ago
            startDate = endDate.subtract(const Duration(days: 30));
          }
          break;
        case TimeRange.custom:
          if (_customStartDate != null && _customEndDate != null) {
            startDate = _customStartDate!;
            final daysDiff =
                _customEndDate!.difference(_customStartDate!).inDays;
            if (daysDiff > 365) {
              startDate = _customEndDate!.subtract(const Duration(days: 365));
            }
          } else {
            startDate = endDate.subtract(const Duration(days: 30));
          }
          break;
      }

      final actualEndDate =
          _selectedRange == TimeRange.custom && _customEndDate != null
              ? _customEndDate!
              : endDate;

      // Load trends (should be much faster now)
      final trends = await MoodTrendsService.getMoodTrends(
        startDate: startDate,
        endDate: actualEndDate,
      );

      if (!mounted) return;

      // Calculate statistics
      final statistics =
          await MoodTrendsService.calculateStatisticsForDateRange(
              trends, startDate, actualEndDate);

      setState(() {
        _trendData = trends;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      Logger.trendsService('Error loading trend data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRangeDisplayName(TimeRange range) {
    switch (range) {
      case TimeRange.week:
        return '7D';
      case TimeRange.month:
        return '30D';
      case TimeRange.quarter:
        return '3M';
      case TimeRange.year:
        return '1Y';
      case TimeRange.all:
        return 'All';
      case TimeRange.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return 'Custom';
        }
        return 'Custom';
    }
  }

  String _getAggregationDisplayName(ChartAggregation aggregation) {
    switch (aggregation) {
      case ChartAggregation.daily:
        return 'Daily';
      case ChartAggregation.weekly:
        return 'Weekly';
      case ChartAggregation.monthly:
        return 'Monthly';
    }
  }

  String _buildCustomRangeText() {
    if (_customStartDate != null && _customEndDate != null) {
      final formatter = DateFormat('MMM d');
      return '${formatter.format(_customStartDate!)} - ${formatter.format(_customEndDate!)}';
    }
    return 'Custom Range';
  }

  Future<void> _showCustomDateRangePicker() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => CustomDateRangePickerDialog(
        initialStartDate: _customStartDate,
        initialEndDate: _customEndDate,
      ),
    );

    if (result != null &&
        result['startDate'] != null &&
        result['endDate'] != null) {
      setState(() {
        _customStartDate = result['startDate'];
        _customEndDate = result['endDate'];
        _selectedRange = TimeRange.custom;
      });

      _loadTrendData();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - refresh data
      _loadTrendData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && mounted) {
      // This screen is now the current route - refresh data
      _loadTrendData();
    }
  }

  Widget _buildDateRangeInfo() {
    if (_trendData.isEmpty) return const SizedBox.shrink();

    final startDate = _trendData.first.date;
    final endDate = _trendData.last.date;
    final dayCount = _trendData.length;
    final daysWithData = _trendData.where((day) => day.hasAnyMood).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('MMM d, y').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)} • '
              '$daysWithData of $dayCount days with data',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Trends'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: () => AiCoachHelper.openAiCoach(context),
            tooltip: 'AI Coach',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showStreakInfoDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trendData.isEmpty || !_trendData.any((day) => day.hasAnyMood)
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDateRangeInfo(),
                      const SizedBox(height: 16),

                      // Date range selector
                      _buildChartTimeRangeSelector(),
                      _buildChartDateRangeInfo(),
                      const SizedBox(height: 16),

                      // Enhanced Statistics Cards with Streak Options
                      MoodStatisticsCards(statistics: _statistics),
                      const SizedBox(height: 24),

                      // FIXED: Restored Line Chart Section
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_getAggregationDisplayName(_chartAggregation)} Trends',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (_chartAggregation !=
                                        ChartAggregation.daily)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _chartAggregation ==
                                                  ChartAggregation.weekly
                                              ? 'Averaged by week'
                                              : 'Averaged by month',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: MoodLineChart(
                                    trendData: _trendData,
                                    aggregation: _chartAggregation,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Heatmap Section (only show for reasonable date ranges)
                      if (_shouldShowHeatmap()) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Activity Calendar',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  MoodHeatmap(
                                    trendData: _trendData,
                                    timeRange: _selectedRange,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
    );
  }

  bool _shouldShowHeatmap() {
    // Only show heatmap for reasonable date ranges (not too long)
    if (_trendData.isEmpty) return false;
    if (_trendData.length > 365) {
      return false; // Don't show for more than a year
      }
    return true;
  }

  void _showStreakInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Trends & Charts'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistics Info:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                  '• "Days Logged" and "Current Streaks" show your total across all time'),
              Text('• Other stats reflect the selected date range'),
              SizedBox(height: 16),
              Text(
                'Date Ranges:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                  '• Use preset ranges (7D, 30D, 3M, 1Y, All) for quick access'),
              Text(
                  '• Use "Custom Range" to select specific start and end dates'),
              SizedBox(height: 16),
              Text(
                'Chart Views:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Daily: Shows each day individually'),
              Text('• Weekly: Shows weekly averages (Sunday-Saturday)'),
              Text('• Monthly: Shows monthly averages'),
              SizedBox(height: 16),
              Text(
                'Streak Types:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('🔥 Live Streak: Moods logged on the actual day'),
              Text('✅ Total Streak: Includes backfilled entries'),
              SizedBox(height: 8),
              Text(
                'Tap the streak card to change calculation mode.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No mood data yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging your moods to see trends and insights!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTimeRangeSelector() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final primaryTextColor = theme.textTheme.bodyLarge?.color ??
        (isDarkMode ? Colors.white : Colors.black87);
    final secondaryTextColor =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
            (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600);
    final buttonBackgroundColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Time range buttons
            Row(
              children: [
                ...TimeRange.values.take(5).map((range) {
                  // Don't include custom in main row
                  final isSelected = range == _selectedRange;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedRange = range);
                          _loadTrendData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Theme.of(context).primaryColor
                              : buttonBackgroundColor,
                          foregroundColor:
                              isSelected ? Colors.white : primaryTextColor,
                          elevation: isSelected ? 2 : 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          _getRangeDisplayName(range),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 8),

            // Custom date range and aggregation controls
            Row(
              children: [
                // Custom date range button
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final isCustomSelected =
                          _selectedRange == TimeRange.custom;

                      Color backgroundColor;
                      Color textColor;
                      Color iconColor;
                      Color borderColor;

                      if (isCustomSelected) {
                        backgroundColor = Theme.of(context)
                            .primaryColor
                            .withValues(alpha: isDarkMode ? 0.15 : 0.1);

                        if (isDarkMode) {
                          final primaryHSL = HSLColor.fromColor(
                              Theme.of(context).primaryColor);
                          final brightPrimary = primaryHSL
                              .withLightness(0.7)
                              .withSaturation(0.8)
                              .toColor();
                          textColor = brightPrimary;
                          iconColor = brightPrimary;
                          borderColor = brightPrimary;
                        } else {
                          textColor = Theme.of(context).primaryColor;
                          iconColor = Theme.of(context).primaryColor;
                          borderColor = Theme.of(context).primaryColor;
                        }
                      } else {
                        backgroundColor =
                            isDarkMode ? theme.cardColor : Colors.white;
                        textColor = primaryTextColor;
                        iconColor = primaryTextColor;
                        borderColor = theme.dividerColor;
                      }

                      return Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: borderColor,
                            width: isCustomSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: backgroundColor,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _showCustomDateRangePicker();
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 16,
                                    color: iconColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isCustomSelected
                                          ? _buildCustomRangeText()
                                          : 'Custom Range',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textColor,
                                        fontWeight: isCustomSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Chart aggregation dropdown
                Expanded(
                  child: DropdownButtonFormField<ChartAggregation>(
                    initialValue: _chartAggregation,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _chartAggregation = value);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'View',
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      isDense: true,
                      fillColor: theme.cardColor,
                      filled: true,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryTextColor,
                    ),
                    dropdownColor: theme.cardColor,
                    items: ChartAggregation.values.map((aggregation) {
                      return DropdownMenuItem(
                        value: aggregation,
                        child: Text(
                          _getAggregationDisplayName(aggregation),
                          style: TextStyle(
                            color: primaryTextColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ));
  }

  Widget _buildChartDateRangeInfo() {
    if (_trendData.isEmpty) return const SizedBox.shrink();

    final startDate = _trendData.first.date;
    final endDate = _trendData.last.date;
    final dayCount = _trendData.length;
    final daysWithData = _trendData.where((day) => day.hasAnyMood).length;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // CALCULATE PROPER COLORS FOR INFO BOX - FIXED FOR DARK PRIMARY
    final backgroundColor = isDarkMode
        ? theme.primaryColor.withValues(alpha: 0.08) // Very light in dark mode
        : theme.primaryColor.withValues(alpha: 0.1);

    final borderColor = isDarkMode
        ? theme.primaryColor
            .withValues(alpha: 0.25) // Light border in dark mode
        : theme.primaryColor.withValues(alpha: 0.3);

    // THE FIX: Use bright color for text in dark mode when primary is dark
    Color textColor;
    if (isDarkMode) {
      // Create a bright version of the primary color for dark mode
      final primaryHSL = HSLColor.fromColor(theme.primaryColor);
      textColor = primaryHSL.withLightness(0.7).withSaturation(0.8).toColor();
    } else {
      textColor = theme.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('MMM d, y').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)} • '
              '$daysWithData of $dayCount days with data',
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
