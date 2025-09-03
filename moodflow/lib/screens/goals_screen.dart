import 'package:flutter/material.dart';
import '../services/data/mood_analytics_service.dart';
import '../widgets/goal_card.dart';
import '../widgets/create_goal_dialog.dart';
import '../services/utils/ai_coach_helper.dart';

class GoalsScreen extends StatefulWidget {
  final String? highlightGoalId;
  const GoalsScreen({super.key, this.highlightGoalId});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<MoodGoal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);

    final goals = await MoodAnalyticsService.loadGoals();

    setState(() {
      _goals = goals;
      _isLoading = false;
    });
  }

  Future<void> _createGoal() async {
    final result = await showDialog<MoodGoal>(
      context: context,
      builder: (context) => const CreateGoalDialog(),
    );

    if (result != null) {
      final updatedGoals = [..._goals, result];
      await MoodAnalyticsService.saveGoals(updatedGoals);
      _loadGoals();
    }
  }

  Future<void> _deleteGoal(MoodGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.title}"?'),
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
      final updatedGoals = _goals.where((g) => g.id != goal.id).toList();
      await MoodAnalyticsService.saveGoals(updatedGoals);
      _loadGoals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal deleted')),
        );
      }
    }
  }

  Future<void> _markGoalComplete(MoodGoal goal) async {
    final completedGoal = MoodGoal(
      id: goal.id,
      title: goal.title,
      description: goal.description,
      type: goal.type,
      targetValue: goal.targetValue,
      targetDays: goal.targetDays,
      createdDate: goal.createdDate,
      completedDate: DateTime.now(),
      isCompleted: true,
    );

    final updatedGoals =
        _goals.map((g) => g.id == goal.id ? completedGoal : g).toList();
    await MoodAnalyticsService.saveGoals(updatedGoals);
    _loadGoals();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Congratulations! You completed "${goal.title}"'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGoals = _goals.where((g) => !g.isCompleted).toList();
    final completedGoals = _goals.where((g) => g.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Goals'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: () => AiCoachHelper.openAiCoach(context),
            tooltip: 'AI Coach',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createGoal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Goals
                      if (activeGoals.isNotEmpty) ...[
                        const Text(
                          'Active Goals',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...activeGoals.map((goal) => GoalCard(
                              goal: goal,
                              onComplete: () => _markGoalComplete(goal),
                              onDelete: () => _deleteGoal(goal),
                            )),
                        const SizedBox(height: 32),
                      ],

                      // Completed Goals
                      if (completedGoals.isNotEmpty) ...[
                        const Text(
                          'Completed Goals',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...completedGoals.map((goal) => GoalCard(
                              goal: goal,
                              onDelete: () => _deleteGoal(goal),
                            )),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGoal,
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
              Icons.flag,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No goals yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set mood goals to track your progress and build healthy habits!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Goal'),
              onPressed: _createGoal,
            ),
          ],
        ),
      ),
    );
  }
}
