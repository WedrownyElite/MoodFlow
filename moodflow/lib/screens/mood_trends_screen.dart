import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_trends_service.dart';
import '../services/data/mood_data_service.dart';
import '../widgets/mood_line_chart.dart';
import '../widgets/mood_heatmap.dart';
import '../widgets/mood_statistics_cards.dart';
import '../widgets/date_range_picker_dialog.dart';
import '../widgets/mood_line_chart.dart';

enum TimeRange { week, month, quarter, year, all, custom }

class MoodTrendsScreen extends StatefulWidget {
  const MoodTrendsScreen({super.key});

  @override
  State<MoodTrendsScreen> createState() => _MoodTrendsScreenState();
}

class _MoodTrendsScreenState extends State<MoodTrendsScreen> {
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
    _loadTrendData();
  }

  Future<void> _loadTrendData() async {
    setState(() => _isLoading = true);

    final endDate = DateTime.now();
    late DateTime startDate;

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
        startDate = endDate.subtract(const Duration(days: 1095)); // 3 years max
        break;
      case TimeRange.custom:
        if (_customStartDate != null && _customEndDate != null) {
          startDate = _customStartDate!;
        } else {
          startDate = endDate.subtract(const Duration(days: 30)); // Fallback
        }
        break;
    }

    final actualEndDate = _selectedRange == TimeRange.custom && _customEndDate != null
        ? _customEndDate!
        : endDate;

    final trends = await MoodTrendsService.getMoodTrends(
      startDate: startDate,
      endDate: actualEndDate,
    );

    final statistics = MoodTrendsService.calculateStatistics(trends);

    setState(() {
      _trendData = trends;
      _statistics = statistics;
      _isLoading = false;
    });
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

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Time range buttons
          Row(
            children: [
              ...TimeRange.values.take(5).map((range) { // Don't include custom in main row
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
                        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                        foregroundColor: isSelected ? Colors.white : Colors.black87,
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
              }).toList(),
            ],
          ),

          const SizedBox(height: 8),

          // Custom date range and aggregation controls
          Row(
            children: [
              // Custom date range button
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.date_range,
                    size: 16,
                    color: _selectedRange == TimeRange.custom
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                  ),
                  label: Text(
                    _selectedRange == TimeRange.custom
                        ? _buildCustomRangeText()
                        : 'Custom Range',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedRange == TimeRange.custom
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade600,
                    ),
                  ),
                  onPressed: _showCustomDateRangePicker,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _selectedRange == TimeRange.custom
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade400,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Chart aggregation dropdown
              Expanded(
                child: DropdownButtonFormField<ChartAggregation>(
                  value: _chartAggregation,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _chartAggregation = value);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'View',
                    labelStyle: const TextStyle(fontSize: 12),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  items: ChartAggregation.values.map((aggregation) {
                    return DropdownMenuItem(
                      value: aggregation,
                      child: Text(_getAggregationDisplayName(aggregation)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

    if (result != null) {
      setState(() {
        _customStartDate = result['startDate'];
        _customEndDate = result['endDate'];
        _selectedRange = TimeRange.custom;
      });
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
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
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
            _buildTimeRangeSelector(),
            _buildDateRangeInfo(),
            const SizedBox(height: 16),

            // Enhanced Statistics Cards with Streak Options
            MoodStatisticsCards(statistics: _statistics),
            const SizedBox(height: 24),

            // Line Chart Section
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
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_chartAggregation != ChartAggregation.daily)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _chartAggregation == ChartAggregation.weekly ? 'Averaged by week' : 'Averaged by month',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    if (_trendData.length > 365) return false; // Don't show for more than a year
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
                'Date Ranges:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Use preset ranges (7D, 30D, 3M, 1Y, All) for quick access'),
              Text('• Use "Custom Range" to select specific start and end dates'),
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
}