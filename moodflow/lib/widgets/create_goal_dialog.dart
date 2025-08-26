import 'package:flutter/material.dart';
import '../services/data/mood_analytics_service.dart';

class CreateGoalDialog extends StatefulWidget {
  const CreateGoalDialog({super.key});

  @override
  State<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<CreateGoalDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  GoalType _selectedType = GoalType.averageMood;
  double _targetValue = 7.0;
  int _targetDays = 7;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateFieldsForGoalType() {
    switch (_selectedType) {
      case GoalType.averageMood:
        _titleController.text =
            'Maintain ${_targetValue.toStringAsFixed(1)}+ Average Mood';
        _descriptionController.text =
            'Keep your overall mood rating above ${_targetValue.toStringAsFixed(1)} on average';
        break;
      case GoalType.consecutiveDays:
        _titleController.text = 'Log Mood for $_targetDays Days Straight';
        _descriptionController.text =
            'Track your mood consistently for $_targetDays consecutive days';
        break;
      case GoalType.minimumMood:
        _titleController.text =
            'No Days Below ${_targetValue.toStringAsFixed(1)}';
        _descriptionController.text =
            'Maintain a minimum mood level of ${_targetValue.toStringAsFixed(1)} every day';
        break;
      case GoalType.improvementStreak:
        _titleController.text = 'Improve Mood for $_targetDays Days';
        _descriptionController.text =
            'Have each day be better than the previous for $_targetDays days';
        break;
    }
  }

  String _getGoalTypeTitle(GoalType type) {
    switch (type) {
      case GoalType.averageMood:
        return 'Average Mood Goal';
      case GoalType.consecutiveDays:
        return 'Logging Streak';
      case GoalType.minimumMood:
        return 'Minimum Mood Level';
      case GoalType.improvementStreak:
        return 'Improvement Streak';
    }
  }

  String _getGoalTypeDescription(GoalType type) {
    switch (type) {
      case GoalType.averageMood:
        return 'Maintain a target average mood rating';
      case GoalType.consecutiveDays:
        return 'Log your mood for consecutive days';
      case GoalType.minimumMood:
        return 'Keep all mood ratings above a minimum';
      case GoalType.improvementStreak:
        return 'Improve your mood day by day';
    }
  }

  Widget _buildValueSlider() {
    if (_selectedType == GoalType.consecutiveDays ||
        _selectedType == GoalType.improvementStreak) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Days: $_targetDays',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Slider(
            value: _targetDays.toDouble(),
            min: 3,
            max: 30,
            divisions: 27,
            label: '$_targetDays days',
            onChanged: (value) {
              setState(() {
                _targetDays = value.round();
                _updateFieldsForGoalType();
              });
            },
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Mood: ${_targetValue.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Slider(
            value: _targetValue,
            min: 1,
            max: 10,
            divisions: 18,
            label: _targetValue.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _targetValue = value;
                _updateFieldsForGoalType();
              });
            },
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Create New Goal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Goal Type Selection with custom radio implementation
              const Text(
                'Goal Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              // Custom radio selection without deprecated parameters
              Column(
                children: GoalType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                        _updateFieldsForGoalType();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade300),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade300
                                        : Colors.grey),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGoalTypeTitle(type),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  _getGoalTypeDescription(type),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Target Value/Days Slider
              _buildValueSlider(),

              const SizedBox(height: 24),

              // Title Field
              const Text(
                'Goal Title',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter goal title',
                ),
              ),

              const SizedBox(height: 16),

              // Description Field
              const Text(
                'Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Describe your goal',
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _titleController.text.trim().isEmpty
                          ? null
                          : () {
                              final goal = MoodGoal(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                title: _titleController.text.trim(),
                                description: _descriptionController.text.trim(),
                                type: _selectedType,
                                targetValue: _targetValue,
                                targetDays: _targetDays,
                                createdDate: DateTime.now(),
                              );
                              Navigator.of(context).pop(goal);
                            },
                      child: const Text('Create Goal'),
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
