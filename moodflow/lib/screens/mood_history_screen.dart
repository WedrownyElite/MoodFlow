import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data/mood_data_service.dart';
import '../widgets/edit_mood_dialog.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  List<DayMoodData> _dayMoodData = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMoodHistory();
  }

  Future<void> _loadMoodHistory() async {
    setState(() => _isLoading = true);

    final dayDataMap = <String, DayMoodData>{};
    
    // Load mood entries for the selected month
    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final segments = <SegmentMoodData>[];
      bool hasAnyMood = false;
      
      for (int segment = 0; segment < MoodDataService.timeSegments.length; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        if (moodData != null && moodData['rating'] != null) {
          segments.add(SegmentMoodData(
            segment: segment,
            rating: (moodData['rating'] as num).toDouble(),
            note: moodData['note'] as String? ?? '',
          ));
          hasAnyMood = true;
        }
      }
      
      if (hasAnyMood) {
        final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
        dayDataMap[dateKey] = DayMoodData(
          date: currentDate,
          segments: segments,
        );
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Sort by date (most recent first)
    final sortedDays = dayDataMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _dayMoodData = sortedDays;
      _isLoading = false;
    });
  }

  Future<void> _showDayDetail(DayMoodData dayData) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDetailSheet(
        dayData: dayData,
        onSegmentEdit: (segment, rating, note) => _editSegment(dayData.date, segment, rating, note),
        onSegmentDelete: (segment) => _deleteSegment(dayData.date, segment),
      ),
    );
    
    // Refresh after modal closes
    _loadMoodHistory();
  }

  Future<void> _editSegment(DateTime date, int segment, double currentRating, String currentNote) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditMoodDialog(
        initialRating: currentRating,
        initialNote: currentNote,
        date: date,
        segment: segment,
      ),
    );

    if (result != null) {
      await MoodDataService.saveMood(
        date,
        segment,
        result['rating'],
        result['note'],
      );
      _loadMoodHistory();
    }
  }

  Future<void> _deleteSegment(DateTime date, int segment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mood Entry'),
        content: Text(
          'Are you sure you want to delete your ${MoodDataService.timeSegments[segment].toLowerCase()} mood from ${DateFormat('MMM d').format(date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete by removing the stored data
      final prefs = await SharedPreferences.getInstance();
      final key = MoodDataService.getKeyForDateSegment(date, segment);
      await prefs.remove(key);
      
      _loadMoodHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mood entry deleted')),
        );
      }
    }
  }

  void _changeMonth(int direction) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + direction,
        1,
      );
    });
    _loadMoodHistory();
  }

  Future<void> _showDatePicker() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select date to log mood',
    );
    
    if (selectedDate != null) {
      _showManualMoodEntry(selectedDate);
    }
  }

  Future<void> _showManualMoodEntry(DateTime date) async {
    // Create empty day data for the selected date
    final dayData = DayMoodData(date: date, segments: []);
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDetailSheet(
        dayData: dayData,
        onSegmentEdit: (segment, rating, note) => _editSegment(date, segment, rating, note),
        onSegmentDelete: (segment) => _deleteSegment(date, segment),
      ),
    );
    
    // Refresh after modal closes
    _loadMoodHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood History'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMoodHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _selectedMonth.isBefore(DateTime.now())
                      ? () => _changeMonth(1)
                      : null,
                ),
              ],
            ),
          ),
          
          // Day cards list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dayMoodData.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _dayMoodData.length,
                        itemBuilder: (context, index) {
                          final dayData = _dayMoodData[index];
                          return DayMoodCard(
                            dayData: dayData,
                            onTap: () => _showDayDetail(dayData),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDatePicker,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
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
              Icons.history,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No mood entries found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No moods logged for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
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

class DayMoodCard extends StatelessWidget {
  final DayMoodData dayData;
  final VoidCallback onTap;

  const DayMoodCard({
    super.key,
    required this.dayData,
    required this.onTap,
  });

  String _getMoodEmoji(double rating) {
    final roundedRating = rating.round();
    switch (roundedRating) {
      case 1: return '😭';
      case 2: return '😢';
      case 3: return '😔';
      case 4: return '😕';
      case 5: return '😐';
      case 6: return '🙂';
      case 7: return '😊';
      case 8: return '😄';
      case 9: return '😁';
      case 10: return '🤩';
      default: return '😐';
    }
  }

  Color _getMoodColor(double rating) {
    final intensity = (rating - 1) / 9;

    if (intensity < 0.3) {
      return Colors.red.shade600;
    } else if (intensity < 0.7) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  double _getDayAverage() {
    if (dayData.segments.isEmpty) return 5.0;
    final total = dayData.segments.fold(0.0, (sum, segment) => sum + segment.rating);
    return total / dayData.segments.length;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().difference(dayData.date).inDays == 0;
    final isYesterday = DateTime.now().difference(dayData.date).inDays == 1;
    final dayAverage = _getDayAverage();

    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEE, MMM d').format(dayData.date);
    }

    // Use theme text colors for better contrast
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Get appropriate text colors from the theme
    final primaryTextColor = theme.textTheme.bodyLarge?.color ??
        (isDarkMode ? Colors.white : Colors.black87);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ??
        (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600);

    // For "Today", use a more visible primary color or enhanced text color
    final todayTextColor = isToday
        ? (isDarkMode
        ? theme.colorScheme.primary.withOpacity(0.9) // Use colorScheme primary in dark mode
        : theme.primaryColor) // Use regular primary in light mode
        : primaryTextColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and average
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: todayTextColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getMoodColor(dayAverage).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getMoodColor(dayAverage).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getMoodEmoji(dayAverage),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dayAverage.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getMoodColor(dayAverage),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Segment indicators
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _SegmentIndicator(
                        segmentName: MoodDataService.timeSegments[i],
                        segmentData: dayData.segments.firstWhere(
                              (s) => s.segment == i,
                          orElse: () => SegmentMoodData(segment: i, rating: 0, note: ''),
                        ),
                        hasData: dayData.segments.any((s) => s.segment == i),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Tap hint
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view and edit entries',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                      fontStyle: FontStyle.italic,
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
}

class _SegmentIndicator extends StatelessWidget {
  final String segmentName;
  final SegmentMoodData segmentData;
  final bool hasData;

  const _SegmentIndicator({
    required this.segmentName,
    required this.segmentData,
    required this.hasData,
  });

  String _getMoodEmoji(double rating) {
    final roundedRating = rating.round();
    switch (roundedRating) {
      case 1: return '😭';
      case 2: return '😢';
      case 3: return '😔';
      case 4: return '😕';
      case 5: return '😐';
      case 6: return '🙂';
      case 7: return '😊';
      case 8: return '😄';
      case 9: return '😁';
      case 10: return '🤩';
      default: return '😐';
    }
  }

  Color _getMoodColor(double rating) {
    final intensity = (rating - 1) / 9;
    
    if (intensity < 0.3) {
      return Colors.red.shade600;
    } else if (intensity < 0.7) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: hasData 
            ? _getMoodColor(segmentData.rating).withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasData 
              ? _getMoodColor(segmentData.rating).withOpacity(0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Text(
            segmentName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasData ? _getMoodColor(segmentData.rating) : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          if (hasData) ...[
            Text(
              _getMoodEmoji(segmentData.rating),
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              segmentData.rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _getMoodColor(segmentData.rating),
              ),
            ),
          ] else ...[
            Icon(
              Icons.remove,
              size: 16,
              color: Colors.grey.shade400,
            ),
            Text(
              'No data',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DayDetailSheet extends StatefulWidget {
  final DayMoodData dayData;
  final Function(int segment, double rating, String note) onSegmentEdit;
  final Function(int segment) onSegmentDelete;

  const DayDetailSheet({
    super.key,
    required this.dayData,
    required this.onSegmentEdit,
    required this.onSegmentDelete,
  });

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  late DayMoodData _currentDayData;

  @override
  void initState() {
    super.initState();
    _currentDayData = widget.dayData;
  }

  // Reload the data for this day
  Future<void> _refreshDayData() async {
    final segments = <SegmentMoodData>[];

    for (int i = 0; i < 3; i++) {
      final moodData = await MoodDataService.loadMood(_currentDayData.date, i);
      if (moodData != null && moodData['rating'] != null) {
        segments.add(SegmentMoodData(
          segment: i,
          rating: (moodData['rating'] as num).toDouble(),
          note: moodData['note'] as String? ?? '',
        ));
      }
    }

    setState(() {
      _currentDayData = DayMoodData(
        date: widget.dayData.date,
        segments: segments,
      );
    });
  }

  Future<void> _handleSegmentEdit(int segment, double rating, String note) async {
    await widget.onSegmentEdit(segment, rating, note);
    // Refresh the data after editing
    await _refreshDayData();
  }

  Future<void> _handleSegmentDelete(int segment) async {
    await widget.onSegmentDelete(segment);
    // Refresh the data after deleting
    await _refreshDayData();
  }

  String _getMoodEmoji(double rating) {
    final roundedRating = rating.round();
    switch (roundedRating) {
      case 1: return '😭';
      case 2: return '😢';
      case 3: return '😔';
      case 4: return '😕';
      case 5: return '😐';
      case 6: return '🙂';
      case 7: return '😊';
      case 8: return '😄';
      case 9: return '😁';
      case 10: return '🤩';
      default: return '😐';
    }
  }

  Color _getMoodColor(double rating) {
    final intensity = (rating - 1) / 9;

    if (intensity < 0.3) {
      return Colors.red.shade600;
    } else if (intensity < 0.7) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().difference(_currentDayData.date).inDays == 0;
    final isYesterday = DateTime.now().difference(_currentDayData.date).inDays == 1;

    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEEE, MMMM d, y').format(_currentDayData.date);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Segment list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: 3,
              itemBuilder: (context, index) {
                final segmentData = _currentDayData.segments.firstWhere(
                      (s) => s.segment == index,
                  orElse: () => SegmentMoodData(segment: index, rating: 0, note: ''),
                );
                final hasData = _currentDayData.segments.any((s) => s.segment == index);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade600
                            : Colors.grey.shade200
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800.withOpacity(0.3)
                        : Colors.transparent,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      MoodDataService.timeSegments[index],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: hasData
                        ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _getMoodEmoji(segmentData.rating),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              segmentData.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getMoodColor(segmentData.rating),
                              ),
                            ),
                          ],
                        ),
                        if (segmentData.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            segmentData.note.length > 50
                                ? '${segmentData.note.substring(0, 50)}...'
                                : segmentData.note,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    )
                        : Text(
                      'No mood logged',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    trailing: hasData
                        ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _handleSegmentEdit(index, segmentData.rating, segmentData.note);
                        } else if (value == 'delete') {
                          _handleSegmentDelete(index);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                        : const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _handleSegmentEdit(
                        index,
                        hasData ? segmentData.rating : 5.0,
                        hasData ? segmentData.note : ''
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Data classes
class DayMoodData {
  final DateTime date;
  final List<SegmentMoodData> segments;

  DayMoodData({
    required this.date,
    required this.segments,
  });
}

class SegmentMoodData {
  final int segment;
  final double rating;
  final String note;

  SegmentMoodData({
    required this.segment,
    required this.rating,
    required this.note,
  });
}