// lib/screens/correlation_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/correlation_data_service.dart';

class CorrelationScreen extends StatefulWidget {
  final DateTime? initialDate;

  const CorrelationScreen({super.key, this.initialDate});

  @override
  State<CorrelationScreen> createState() => _CorrelationScreenState();
}

class _CorrelationScreenState extends State<CorrelationScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  CorrelationData? _currentData;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final data = await CorrelationDataService.loadCorrelationData(_selectedDate);

    setState(() {
      _currentData = data ?? CorrelationData(date: _selectedDate);
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    if (_currentData == null || !_hasChanges) return;

    final success = await CorrelationDataService.saveCorrelationData(_selectedDate, _currentData!);

    if (success) {
      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correlation data saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _updateData(CorrelationData newData) {
    setState(() {
      _currentData = newData;
      _hasChanges = true;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      if (_hasChanges) {
        await _saveData();
      }

      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Factors'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveData,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.wb_sunny, size: 20), text: 'Weather'),
            Tab(icon: Icon(Icons.bedtime, size: 20), text: 'Sleep'),
            Tab(icon: Icon(Icons.fitness_center, size: 20), text: 'Activity'),
            Tab(icon: Icon(Icons.more_horiz, size: 20), text: 'Other'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_hasChanges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'Unsaved changes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: _currentData == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                _buildWeatherTab(),
                _buildSleepTab(),
                _buildActivityTab(),
                _buildOtherTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
        onPressed: _saveData,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      )
          : null,
    );
  }

  Widget _buildWeatherTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weather Conditions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'How was the weather today? This helps identify patterns between weather and your mood.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Weather condition selector
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: WeatherCondition.values.map((condition) {
              final isSelected = _currentData?.weather == condition;
              return FilterChip(
                selected: isSelected,
                label: Text(_getWeatherLabel(condition)),
                avatar: Text(_getWeatherEmoji(condition)),
                onSelected: (selected) {
                  if (selected) {
                    _updateData(_currentData!.copyWith(weather: condition));
                  } else {
                    _updateData(_currentData!.copyWith(weather: null));
                  }
                },
                selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                checkmarkColor: Theme.of(context).primaryColor,
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Auto-fetch weather option
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Auto-fetch weather',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Switch(
                        value: false, // Would implement location services
                        onChanged: null, // Disabled for now
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Automatically detect weather conditions using your location (requires location permission)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep Quality',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Rate your sleep quality from last night. Good sleep is crucial for mood regulation.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Sleep quality slider
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Sleep Quality:', style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (_currentData?.sleepQuality != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getSleepQualityColor(_currentData!.sleepQuality!).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentData!.sleepQuality!.toStringAsFixed(1)}/10',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getSleepQualityColor(_currentData!.sleepQuality!),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      showValueIndicator: ShowValueIndicator.always,
                    ),
                    child: Slider(
                      value: _currentData?.sleepQuality ?? 5.0,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      label: _getSleepQualityLabel(_currentData?.sleepQuality ?? 5.0),
                      onChanged: (value) {
                        _updateData(_currentData!.copyWith(sleepQuality: value));
                      },
                    ),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Poor', style: TextStyle(color: Colors.grey)),
                      Text('Excellent', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sleep duration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sleep Duration',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bedtime', style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectBedtime(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _currentData?.bedtime != null
                                      ? DateFormat('h:mm a').format(_currentData!.bedtime!)
                                      : 'Select time',
                                  style: TextStyle(
                                    color: _currentData?.bedtime != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Wake time', style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectWakeTime(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _currentData?.wakeTime != null
                                      ? DateFormat('h:mm a').format(_currentData!.wakeTime!)
                                      : 'Select time',
                                  style: TextStyle(
                                    color: _currentData?.wakeTime != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_currentData?.bedtime != null && _currentData?.wakeTime != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Sleep duration: ${_formatDuration(_calculateSleepDuration())}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Physical Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track your exercise and physical activity. Regular movement can significantly impact mood.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Exercise level
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exercise Level',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  ...ActivityLevel.values.map((level) {
                    final isSelected = _currentData?.exerciseLevel == level;
                    return RadioListTile<ActivityLevel>(
                      title: Text(_getActivityLevelTitle(level)),
                      subtitle: Text(_getActivityLevelDescription(level)),
                      value: level,
                      groupValue: _currentData?.exerciseLevel,
                      onChanged: (value) {
                        _updateData(_currentData!.copyWith(exerciseLevel: value));
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Social activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Social Interaction',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Social connections can greatly influence our mood and wellbeing.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SocialActivity.values.map((activity) {
                      final isSelected = _currentData?.socialActivity == activity;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(_getSocialActivityLabel(activity)),
                        onSelected: (selected) {
                          if (selected) {
                            _updateData(_currentData!.copyWith(socialActivity: activity));
                          } else {
                            _updateData(_currentData!.copyWith(socialActivity: null));
                          }
                        },
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Other Factors',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track other factors that might influence your mood.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Work stress
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Work Stress Level:', style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (_currentData?.workStress != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStressColor(_currentData!.workStress!).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentData!.workStress}/10',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStressColor(_currentData!.workStress!),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: (_currentData?.workStress ?? 5).toDouble(),
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    label: _getStressLabel(_currentData?.workStress ?? 5),
                    onChanged: (value) {
                      _updateData(_currentData!.copyWith(workStress: value.round()));
                    },
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Low stress', style: TextStyle(color: Colors.grey)),
                      Text('High stress', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Custom tags
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom Tags',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add custom tags for specific events, activities, or situations.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._currentData!.customTags.map((tag) => Chip(
                        label: Text(tag),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          final newTags = List<String>.from(_currentData!.customTags);
                          newTags.remove(tag);
                          _updateData(_currentData!.copyWith(customTags: newTags));
                        },
                      )),
                      ActionChip(
                        label: const Text('Add tag'),
                        avatar: const Icon(Icons.add, size: 16),
                        onPressed: _showAddTagDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Notes',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: _currentData?.notes ?? ''),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Any other factors that might have influenced your mood today...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _updateData(_currentData!.copyWith(notes: value.isEmpty ? null : value));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getWeatherLabel(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny: return 'Sunny';
      case WeatherCondition.cloudy: return 'Cloudy';
      case WeatherCondition.rainy: return 'Rainy';
      case WeatherCondition.stormy: return 'Stormy';
      case WeatherCondition.snowy: return 'Snowy';
      case WeatherCondition.foggy: return 'Foggy';
    }
  }

  String _getWeatherEmoji(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny: return '☀️';
      case WeatherCondition.cloudy: return '☁️';
      case WeatherCondition.rainy: return '🌧️';
      case WeatherCondition.stormy: return '⛈️';
      case WeatherCondition.snowy: return '🌨️';
      case WeatherCondition.foggy: return '🌫️';
    }
  }

  Color _getSleepQualityColor(double quality) {
    if (quality >= 8) return Colors.green;
    if (quality >= 6) return Colors.orange;
    return Colors.red;
  }

  String _getSleepQualityLabel(double quality) {
    if (quality >= 8) return 'Excellent';
    if (quality >= 6) return 'Good';
    if (quality >= 4) return 'Fair';
    return 'Poor';
  }

  String _getActivityLevelTitle(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.none: return 'No Exercise';
      case ActivityLevel.light: return 'Light Activity';
      case ActivityLevel.moderate: return 'Moderate Exercise';
      case ActivityLevel.intense: return 'Intense Workout';
    }
  }

  String _getActivityLevelDescription(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.none: return 'Sedentary day, no planned exercise';
      case ActivityLevel.light: return 'Walking, stretching, light movement';
      case ActivityLevel.moderate: return 'Jogging, cycling, gym workout';
      case ActivityLevel.intense: return 'High-intensity training, sports';
    }
  }

  String _getSocialActivityLabel(SocialActivity activity) {
    switch (activity) {
      case SocialActivity.none: return 'Solo';
      case SocialActivity.friends: return 'Friends';
      case SocialActivity.family: return 'Family';
      case SocialActivity.work: return 'Colleagues';
      case SocialActivity.party: return 'Party/Event';
      case SocialActivity.date: return 'Date';
    }
  }

  Color _getStressColor(int stress) {
    if (stress <= 3) return Colors.green;
    if (stress <= 6) return Colors.orange;
    return Colors.red;
  }

  String _getStressLabel(int stress) {
    if (stress <= 3) return 'Low stress';
    if (stress <= 6) return 'Moderate stress';
    return 'High stress';
  }

  Duration _calculateSleepDuration() {
    if (_currentData?.bedtime == null || _currentData?.wakeTime == null) {
      return Duration.zero;
    }

    var duration = _currentData!.wakeTime!.difference(_currentData!.bedtime!);

    // Handle overnight sleep (bedtime after midnight)
    if (duration.isNegative) {
      duration = duration + const Duration(days: 1);
    }

    return duration;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Future<void> _selectBedtime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _currentData?.bedtime != null
          ? TimeOfDay.fromDateTime(_currentData!.bedtime!)
          : const TimeOfDay(hour: 22, minute: 0),
    );

    if (time != null) {
      final bedtime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
          .add(Duration(hours: time.hour, minutes: time.minute));

      _updateData(_currentData!.copyWith(bedtime: bedtime));
    }
  }

  Future<void> _selectWakeTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _currentData?.wakeTime != null
          ? TimeOfDay.fromDateTime(_currentData!.wakeTime!)
          : const TimeOfDay(hour: 7, minute: 0),
    );

    if (time != null) {
      final wakeTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1)
          .add(Duration(hours: time.hour, minutes: time.minute));

      _updateData(_currentData!.copyWith(wakeTime: wakeTime));
    }
  }

  Future<void> _showAddTagDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter tag name...',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newTags = List<String>.from(_currentData!.customTags);
      if (!newTags.contains(result)) {
        newTags.add(result);
        _updateData(_currentData!.copyWith(customTags: newTags));
      }
    }
  }
}