import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_trends_service.dart';
import '../services/data/mood_data_service.dart';
import '../widgets/mood_line_chart.dart';
import '../widgets/mood_heatmap.dart';
import '../widgets/mood_statistics_cards.dart';

enum TimeRange { week, month, quarter, all }

class MoodTrendsScreen extends StatefulWidget {
  const MoodTrendsScreen({super.key});

  @override
  State<MoodTrendsScreen> createState() => _MoodTrendsScreenState();
}

class _MoodTrendsScreenState extends State<MoodTrendsScreen> {
  TimeRange _selectedRange = TimeRange.month;
  List<DayMoodData> _trendData = [];
  MoodStatistics _statistics = MoodStatistics.empty();
  bool _isLoading = true;

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
      case TimeRange.all:
        startDate = endDate.subtract(const Duration(days: 365)); // Max 1 year for performance
        break;
    }

    final trends = await MoodTrendsService.getMoodTrends(
      startDate: startDate,
      endDate: endDate,
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
      case TimeRange.all:
        return 'All';
    }
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: TimeRange.values.map((range) {
          final isSelected = range == _selectedRange;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _selectedRange = range);
                  _loadTrendData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                  foregroundColor: isSelected ? Colors.white : Colors.black87,
                  elevation: isSelected ? 2 : 0,
                ),
                child: Text(_getRangeDisplayName(range)),
              ),
            ),
          );
        }).toList(),
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
                      const SizedBox(height: 16),
                      
                      // Statistics Cards
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
                                const Text(
                                  'Daily Trends',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: MoodLineChart(trendData: _trendData),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Heatmap Section
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
                  ),
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