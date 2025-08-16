import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_analytics_service.dart';
import '../services/data/mood_data_service.dart';

class GoalCard extends StatefulWidget {
  final MoodGoal goal;
  final VoidCallback? onComplete;
  final VoidCallback onDelete;

  const GoalCard({
    super.key,
    required this.goal,
    this.onComplete,
    required this.onDelete,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  double _progress = 0.0;
  String _progressText = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateProgress();
  }

  Future<void> _calculateProgress() async {
    if (widget.goal.isCompleted) {
      setState(() {
        _progress = 1.0;
        _progressText = 'Completed!';
        _isLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final startDate = widget.goal.createdDate;
    final daysSinceCreated = now.difference(startDate).inDays + 1;
    
    switch (widget.goal.type) {
      case GoalType.averageMood:
        await _calculateAverageMoodProgress(startDate, now);
        break;
      case GoalType.consecutiveDays:
        await _calculateConsecutiveDaysProgress();
        break;
      case GoalType.minimumMood:
        await _calculateMinimumMoodProgress(startDate, now);
        break;
      case GoalType.improvementStreak:
        await _calculateImprovementStreakProgress();
        break;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _calculateAverageMoodProgress(DateTime startDate, DateTime endDate) async {
    double totalMood = 0;
    int moodCount = 0;

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        if (moodData != null && moodData['rating'] != null) {
          totalMood += (moodData['rating'] as num).toDouble();
          moodCount++;
        }
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    final currentAverage = moodCount > 0 ? totalMood / moodCount : 0;
    _progress = (currentAverage / widget.goal.targetValue).clamp(0.0, 1.0);
    _progressText = 'Current: ${currentAverage.toStringAsFixed(1)}/${widget.goal.targetValue.toStringAsFixed(1)}';
  }

  Future<void> _calculateConsecutiveDaysProgress() async {
    int consecutiveDays = 0;
    final today = DateTime.now();

    for (int i = 0; i < widget.goal.targetDays; i++) {
      final date = today.subtract(Duration(days: i));
      bool hasAnyMood = false;

      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(date, segment);
        if (moodData != null && moodData['rating'] != null) {
          hasAnyMood = true;
          break;
        }
      }

      if (hasAnyMood) {
        consecutiveDays++;
      } else {
        break;
      }
    }

    _progress = (consecutiveDays / widget.goal.targetDays).clamp(0.0, 1.0);
    _progressText = '$consecutiveDays/${widget.goal.targetDays} days';
  }

  Future<void> _calculateMinimumMoodProgress(DateTime startDate, DateTime endDate) async {
    int daysAboveMinimum = 0;
    int totalDays = 0;

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      bool dayHasMood = false;
      bool dayAboveMinimum = true;

      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        if (moodData != null && moodData['rating'] != null) {
          dayHasMood = true;
          final mood = (moodData['rating'] as num).toDouble();
          if (mood < widget.goal.targetValue) {
            dayAboveMinimum = false;
          }
        }
      }

      if (dayHasMood) {
        totalDays++;
        if (dayAboveMinimum) {
          daysAboveMinimum++;
        }
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    _progress = totalDays > 0 ? (daysAboveMinimum / totalDays).clamp(0.0, 1.0) : 0.0;
    _progressText = '$daysAboveMinimum/$totalDays days above ${widget.goal.targetValue.toStringAsFixed(1)}';
  }

  Future<void> _calculateImprovementStreakProgress() async {
    int currentStreak = 0;
    final today = DateTime.now();
    double? previousAverage;

    for (int i = 0; i < widget.goal.targetDays; i++) {
      final date = today.subtract(Duration(days: i));
      double dayTotal = 0;
      int dayCount = 0;

      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(date, segment);
        if (moodData != null && moodData['rating'] != null) {
          dayTotal += (moodData['rating'] as num).toDouble();
          dayCount++;
        }
      }

      if (dayCount > 0) {
        final dayAverage = dayTotal / dayCount;
        if (previousAverage != null && dayAverage > previousAverage) {
          currentStreak++;
        } else if (previousAverage != null) {
          break;
        }
        previousAverage = dayAverage;
      } else {
        break;
      }
    }

    _progress = (currentStreak / widget.goal.targetDays).clamp(0.0, 1.0);
    _progressText = '$currentStreak/${widget.goal.targetDays} improving days';
  }

  String _getGoalTypeDescription() {
    switch (widget.goal.type) {
      case GoalType.averageMood:
        return 'Average Mood Goal';
      case GoalType.consecutiveDays:
        return 'Logging Streak Goal';
      case GoalType.minimumMood:
        return 'Minimum Mood Goal';
      case GoalType.improvementStreak:
        return 'Improvement Streak Goal';
    }
  }

  Color _getProgressColor() {
    if (widget.goal.isCompleted) return Colors.green;
    if (_progress >= 0.8) return Colors.green;
    if (_progress >= 0.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.goal.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getGoalTypeDescription(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.goal.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      '✓ Completed',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'complete' && widget.onComplete != null) {
                        widget.onComplete!();
                      } else if (value == 'delete') {
                        widget.onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      if (widget.onComplete != null)
                        const PopupMenuItem(
                          value: 'complete',
                          child: Row(
                            children: [
                              Icon(Icons.check, size: 18, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Mark Complete'),
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
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              widget.goal.description,
              style: const TextStyle(fontSize: 14),
            ),
            
            const SizedBox(height: 16),
            
            // Progress
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _progressText,
                    style: TextStyle(
                      color: _getProgressColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}% complete',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            
            // Dates
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Created: ${DateFormat('MMM d, y').format(widget.goal.createdDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (widget.goal.completedDate != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Completed: ${DateFormat('MMM d, y').format(widget.goal.completedDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}