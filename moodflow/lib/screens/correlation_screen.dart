// lib/screens/correlation_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/data/correlation_data_service.dart';
import '../widgets/weather_api_setup_dialog.dart';
import '../services/insights/smart_insights_service.dart';
import '../services/utils/ai_coach_helper.dart';

class CorrelationScreen extends StatefulWidget {
  final DateTime? initialDate;
  final int? initialTabIndex;

  const CorrelationScreen({
    super.key,
    this.initialDate,
    this.initialTabIndex,
  });

  @override
  State<CorrelationScreen> createState() => _CorrelationScreenState();
}

class _CorrelationScreenState extends State<CorrelationScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _temperatureController;
  DateTime _selectedDate = DateTime.now();
  CorrelationData? _currentData;
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isFetchingWeather = false;
  bool _autoWeatherEnabled = false;
  String _temperatureUnit = 'celsius';
  final List<String> _customHobbyTags = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _temperatureController = TextEditingController();

    // Use the initial tab index if provided, otherwise default to 0
    final initialTab = widget.initialTabIndex ?? 0;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialTab.clamp(0, 3), // Ensure it's within valid range
    );

    _loadData();
    _checkAutoWeatherEnabled();
    _loadCustomHobbyTags();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomHobbyTags() async {
    final prefs = await SharedPreferences.getInstance();
    final customTags = prefs.getStringList('custom_hobby_tags') ?? [];
    setState(() {
      _customHobbyTags.clear();
      _customHobbyTags.addAll(customTags);
    });
  }

  Future<void> _saveCustomHobbyTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_hobby_tags', _customHobbyTags);
  }

  Future<void> _addCustomHobbyTag() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Hobby'),
        content: SingleChildScrollView(
          child: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter hobby name (max 20 chars)',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          ),
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

    if (result != null && result.isNotEmpty && !_customHobbyTags.contains(result)) {
      setState(() {
        _customHobbyTags.add(result);
      });
      await _saveCustomHobbyTags();
    }
  }

  Future<void> _deleteCustomHobbyTag(String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Hobby'),
        content: Text('Are you sure you want to delete "$tag"?'),
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
      setState(() {
        _customHobbyTags.remove(tag);
      });
      await _saveCustomHobbyTags();

      // Remove from current data if selected
      final currentHobbies = Set<String>.from(_currentData?.hobbyActivities ?? []);
      if (currentHobbies.remove(tag)) {
        _updateData(_currentData!.copyWith(hobbyActivities: currentHobbies.toList()));
      }
    }
  }

  void _updateTemperatureController() {
    final newText = _currentData?.temperature != null
        ? _currentData!.temperature!.toStringAsFixed(1)
        : '';

    // Only update if the text is different to avoid cursor jumping
    if (_temperatureController.text != newText) {
      _temperatureController.text = newText;
    }
  }

  Future<void> _checkAutoWeatherEnabled() async {
    final isConfigured = await CorrelationDataService.isWeatherApiConfigured();
    final tempUnit = await CorrelationDataService.getTemperatureUnit();
    setState(() {
      _autoWeatherEnabled = isConfigured;
      _temperatureUnit = tempUnit;
    });
  }

  String _formatTemperature(double temperature) {
    // If we have stored temperature data, convert from stored unit to display unit
    if (_currentData?.temperature != null &&
        _currentData?.temperatureUnit != null) {
      final displayTemp = _getTemperatureInUnit(_temperatureUnit);
      return '${displayTemp.toStringAsFixed(1)}°${_temperatureUnit == 'celsius'
          ? 'C'
          : 'F'}';
    }

    // Fallback for temperatures passed directly
    return '${temperature.toStringAsFixed(1)}°${_temperatureUnit == 'celsius'
        ? 'C'
        : 'F'}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final data = await CorrelationDataService.loadCorrelationData(
        _selectedDate);

    setState(() {
      _currentData = data ?? CorrelationData(date: _selectedDate);
      _isLoading = false;
    });

    // Update the temperature controller
    _updateTemperatureController();
  }

  Future<void> _saveData() async {
    if (_currentData == null || !_hasChanges) return;

    final success = await CorrelationDataService.saveCorrelationData(
        _selectedDate, _currentData!);

    if (success) {
      setState(() => _hasChanges = false);

      // Trigger insights regeneration in background
      SmartInsightsService.backgroundRefresh();

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

  Future<void> _setupWeatherApi() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const WeatherApiSetupDialog(),
    );

    if (result == true) {
      await _checkAutoWeatherEnabled();
      if (_autoWeatherEnabled && _currentData?.weather == null) {
        _fetchWeatherAutomatically();
      }
    }
  }

  Future<void> _fetchWeatherAutomatically() async {
    if (!_autoWeatherEnabled) {
      await _setupWeatherApi();
      return;
    }

    if (mounted) {
      setState(() => _isFetchingWeather = true);
    }

    try {
      final weather =
      await CorrelationDataService.autoFetchWeather(forDate: _selectedDate);

      if (!mounted) return;

      if (weather != null) {
        final updatedData = _currentData!.copyWith(
          weather: weather.condition,
          temperature: weather.temperature,
          temperatureUnit: _temperatureUnit,
          weatherDescription: weather.description,
          autoWeather: true,
          weatherData: weather.rawData,
        );

        _updateData(updatedData);
        _updateTemperatureController();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Weather updated: ${weather.description}, ${_formatTemperature(
                    weather.temperature)}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not fetch weather data. Check your location settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weather fetch failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isFetchingWeather = false);
    }
  }

  void _updateData(CorrelationData newData) {
    setState(() {
      _currentData = newData;
      _hasChanges = true;
    });

    _updateTemperatureController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Factors'),
        backgroundColor: Theme
            .of(context)
            .primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: () => AiCoachHelper.openAiCoach(context),
            tooltip: 'AI Coach',
          ),
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
          // Date header with weather info
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme
                .of(context)
                .primaryColor
                .withValues(alpha: 0.1),
            child: Column(
              children: [
                Row(
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
                    else
                      if (_hasChanges)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                // Quick weather display
                if (_currentData?.weather != null ||
                    _currentData?.temperature != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.wb_sunny,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _buildWeatherSummary(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_currentData?.autoWeather == true)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Auto',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
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
        backgroundColor: Theme
            .of(context)
            .primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      )
          : null,
    );
  }

  String _buildWeatherSummary() {
    final parts = <String>[];

    if (_currentData?.weather != null) {
      parts.add(_getWeatherLabel(_currentData!.weather!));
    }

    if (_currentData?.temperature != null) {
      parts.add(_formatTemperature(_currentData!.temperature!));
    }

    if (_currentData?.weatherDescription != null) {
      parts.add(_currentData!.weatherDescription!);
    }

    return parts.join(' • ');
  }

  Future<void> _changeTemperatureUnit(String newUnit) async {
    if (newUnit == _temperatureUnit) return; // Already in this unit

    final oldUnit = _temperatureUnit;

    // Update the unit preference
    await CorrelationDataService.setTemperatureUnit(newUnit);

    // Convert the current temperature if it exists
    if (_currentData?.temperature != null) {
      final oldTemp = _currentData!.temperature!;
      final storedUnit = _currentData!.temperatureUnit ?? oldUnit;

      // Convert from stored unit to new unit
      final convertedTemp = CorrelationDataService.convertTemperature(
        oldTemp,
        storedUnit,
        newUnit,
      );

      // Update the data with converted temperature
      _updateData(_currentData!.copyWith(
        temperature: convertedTemp,
        temperatureUnit: newUnit,
      ));
    }

    // Update state to show the new unit
    if (mounted) {
      setState(() {
        _temperatureUnit = newUnit;
      });
    }
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

          // Auto-fetch weather card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                          Icons.wb_sunny, size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Weather Data',
                          style: TextStyle(fontWeight: FontWeight.w500,
                              fontSize: 16),
                        ),
                      ),
                      if (_isFetchingWeather)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        if (_autoWeatherEnabled)
                          ElevatedButton.icon(
                            onPressed: _fetchWeatherAutomatically,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Auto-fetch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme
                                  .of(context)
                                  .primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _setupWeatherApi,
                            icon: const Icon(Icons.settings),
                            label: const Text('Setup API'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme
                                  .of(context)
                                  .primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _autoWeatherEnabled
                        ? 'Auto-fetch weather data or enter manually'
                        : 'Set up OpenWeatherMap API for auto-fetch, or enter temperature manually',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  // Temperature input section - always visible
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.thermostat, color: Colors.blue.shade600,
                          size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Temperature:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _temperatureController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(
                                r'^\d*\.?\d*')),
                          ],
                          decoration: InputDecoration(
                            suffixText: _temperatureUnit == 'celsius'
                                ? '°C'
                                : '°F',
                            border: const OutlineInputBorder(),
                            hintText: 'Enter temperature',
                            isDense: true,
                          ),
                          onChanged: (value) {
                            // Use a timer to debounce rapid changes
                            Timer(const Duration(milliseconds: 300), () {
                              if (value.isNotEmpty) {
                                final temp = double.tryParse(value);
                                if (temp != null) {
                                  _updateData(_currentData!.copyWith(
                                    temperature: temp,
                                    temperatureUnit: _temperatureUnit,
                                    autoWeather: false,
                                  ));
                                }
                              } else {
                                _updateData(_currentData!.copyWith(
                                  temperature: null,
                                  temperatureUnit: null,
                                  autoWeather: false,
                                ));
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _currentData?.autoWeather == true
                              ? Colors.green.shade100
                              : _currentData?.temperature != null
                              ? Colors.blue.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _currentData?.autoWeather == true
                              ? 'Auto'
                              : _currentData?.temperature != null
                              ? 'Manual'
                              : 'Empty',
                          style: TextStyle(
                            fontSize: 10,
                            color: _currentData?.autoWeather == true
                                ? Colors.green.shade700
                                : _currentData?.temperature != null
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Weather description section (only show if exists)
                  if (_currentData?.weatherDescription != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud, color: Colors.green.shade600,
                              size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Weather: ${_currentData!.weatherDescription}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
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

          // Temperature unit selector
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temperature Unit',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: _temperatureUnit,
                    onChanged: (value) async {
                      if (value != null) {
                        await _changeTemperatureUnit(value);
                      }
                    },
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Celsius (°C)'),
                          leading: Radio<String>(
                            value: 'celsius',
                          ),
                          onTap: () async {
                            await _changeTemperatureUnit('celsius');
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          title: const Text('Fahrenheit (°F)'),
                          leading: Radio<String>(
                            value: 'fahrenheit',
                          ),
                          onTap: () async {
                            await _changeTemperatureUnit('fahrenheit');
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Weather condition selector
          const Text(
            'Weather Condition',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
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
                    // Allow deselection by setting weather to null
                    _updateData(_currentData!.copyWith(weather: null));
                  }
                },
                selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                checkmarkColor: Theme.of(context).primaryColor,
              );
            }).toList(),
          ),

          if (_currentData?.weatherDescription != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme
                    .of(context)
                    .brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme
                      .of(context)
                      .brightness == Brightness.dark
                      ? Colors.grey.shade600
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weather Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      // Use theme-aware text color
                      color: Theme
                          .of(context)
                          .brightness == Brightness.dark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentData!.weatherDescription!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      // Use theme-aware text color for better contrast
                      color: Theme
                          .of(context)
                          .brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                      const Text('Sleep Quality:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (_currentData?.sleepQuality != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getSleepQualityColor(
                                _currentData!.sleepQuality!)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentData!.sleepQuality!.toStringAsFixed(
                                1)}/10',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getSleepQualityColor(
                                  _currentData!.sleepQuality!),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      showValueIndicator: ShowValueIndicator.onDrag,
                    ),
                    child: Slider(
                      value: _currentData?.sleepQuality ?? 5.0,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      label: _getSleepQualityLabel(
                          _currentData?.sleepQuality ?? 5.0),
                      onChanged: (value) {
                        if (mounted) {
                          _updateData(
                              _currentData!.copyWith(sleepQuality: value));
                        }
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
                            const Text('Bedtime',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectBedtime(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme
                                        .of(context)
                                        .brightness ==
                                        Brightness.dark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  // Add background color for dark mode
                                  color: Theme
                                      .of(context)
                                      .brightness ==
                                      Brightness.dark
                                      ? Colors.grey.shade800
                                      : Colors.transparent,
                                ),
                                child: Text(
                                  _currentData?.bedtime != null
                                      ? DateFormat('h:mm a')
                                      .format(_currentData!.bedtime!)
                                      : 'Select time',
                                  style: TextStyle(
                                    // Use theme-aware text color
                                    color: _currentData?.bedtime != null
                                        ? (Theme
                                        .of(context)
                                        .brightness ==
                                        Brightness.dark
                                        ? Colors.white
                                        : Colors.black87)
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
                            const Text('Wake time',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectWakeTime(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme
                                        .of(context)
                                        .brightness ==
                                        Brightness.dark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  // Add background color for dark mode
                                  color: Theme
                                      .of(context)
                                      .brightness ==
                                      Brightness.dark
                                      ? Colors.grey.shade800
                                      : Colors.transparent,
                                ),
                                child: Text(
                                  _currentData?.wakeTime != null
                                      ? DateFormat('h:mm a')
                                      .format(_currentData!.wakeTime!)
                                      : 'Select time',
                                  style: TextStyle(
                                    // Use theme-aware text color
                                    color: _currentData?.wakeTime != null
                                        ? (Theme
                                        .of(context)
                                        .brightness ==
                                        Brightness.dark
                                        ? Colors.white
                                        : Colors.black87)
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
                  if (_currentData?.bedtime != null &&
                      _currentData?.wakeTime != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Sleep duration: ${_formatDuration(
                                _calculateSleepDuration())}',
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
                  RadioGroup<ActivityLevel>(
                    groupValue: _currentData?.exerciseLevel,
                    onChanged: (value) {
                      _updateData(_currentData!.copyWith(exerciseLevel: value));
                    },
                    child: Column(
                      children: ActivityLevel.values.map((level) {
                        return RadioListTile<ActivityLevel>(
                          title: Text(_getActivityLevelTitle(level)),
                          subtitle: Text(_getActivityLevelDescription(level)),
                          value: level,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      }).toList(),
                    ),
                  ),
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
                    'Who did you spend time with today? (Select all that apply)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SocialActivity.values.map((activity) {
                      final isSelected = _currentData?.socialActivities.contains(activity) ?? false;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(_getSocialActivityLabel(activity)),
                        onSelected: (selected) {
                          final currentActivities = Set<SocialActivity>.from(_currentData?.socialActivities ?? {});
                          if (selected) {
                            currentActivities.add(activity);
                          } else {
                            currentActivities.remove(activity);
                          }
                          _updateData(_currentData!.copyWith(socialActivities: currentActivities.toList()));
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
          
          const SizedBox(height: 16),

          // Hobby activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hobbies & Interests',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'What hobbies or interests did you engage in today? (Select all that apply)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Default hobby chips
                      ...HobbyActivity.values.map((hobby) {
                        final hobbyName = _getHobbyActivityLabel(hobby);
                        final isSelected = _currentData?.hobbyActivities.contains(hobbyName) ?? false;
                        return FilterChip(
                          selected: isSelected,
                          label: Text(hobbyName),
                          onSelected: (selected) {
                            final currentHobbies = Set<String>.from(_currentData?.hobbyActivities ?? {});
                            if (selected) {
                              currentHobbies.add(hobbyName);
                            } else {
                              currentHobbies.remove(hobbyName);
                            }
                            _updateData(_currentData!.copyWith(hobbyActivities: currentHobbies.toList()));
                          },
                          selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          checkmarkColor: Theme.of(context).primaryColor,
                        );
                      }),
                      // Custom hobby chips with delete button
                      ..._customHobbyTags.map((tag) {
                        final isSelected = _currentData?.hobbyActivities.contains(tag) ?? false;
                        return FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tag),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _deleteCustomHobbyTag(tag),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          onSelected: (selected) {
                            final currentHobbies = Set<String>.from(_currentData?.hobbyActivities ?? {});
                            if (selected) {
                              currentHobbies.add(tag);
                            } else {
                              currentHobbies.remove(tag);
                            }
                            _updateData(_currentData!.copyWith(hobbyActivities: currentHobbies.toList()));
                          },
                          selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          checkmarkColor: Theme.of(context).primaryColor,
                        );
                      }),
                      // Add custom tag button
                      ActionChip(
                        label: const Text('Add custom'),
                        avatar: const Icon(Icons.add, size: 16),
                        onPressed: _addCustomHobbyTag,
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ],
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
                      const Text('Work Stress Level:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (_currentData?.workStress != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStressColor(_currentData!.workStress!)
                                .withValues(alpha: 0.2),
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
                      if (mounted) {
                        _updateData(
                            _currentData!.copyWith(workStress: value.round()));
                      }
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
                      ..._currentData!.customTags.map((tag) =>
                          Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Tag'),
                                  content: Text('Are you sure you want to remove "$tag"?'),
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
                                final newTags = List<String>.from(_currentData!.customTags);
                                newTags.remove(tag);
                                _updateData(_currentData!.copyWith(customTags: newTags));
                              }
                            },
                          ),
                      ),
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
                    controller:
                    TextEditingController(text: _currentData?.notes ?? ''),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                      'Any other factors that might have influenced your mood today...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _updateData(_currentData!
                          .copyWith(notes: value.isEmpty ? null : value));
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

  double _getTemperatureInUnit(String targetUnit) {
    if (_currentData?.temperature == null) return 0.0;

    final currentTemp = _currentData!.temperature!;
    final storedUnit = _currentData!.temperatureUnit ?? 'celsius';

    if (storedUnit == targetUnit) {
      return currentTemp;
    }

    return CorrelationDataService.convertTemperature(
        currentTemp, storedUnit, targetUnit);
  }

  // Helper methods
  String _getWeatherLabel(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.rainy:
        return 'Rainy';
      case WeatherCondition.stormy:
        return 'Stormy';
      case WeatherCondition.snowy:
        return 'Snowy';
      case WeatherCondition.foggy:
        return 'Foggy';
    }
  }

  String _getWeatherEmoji(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return '☀️';
      case WeatherCondition.cloudy:
        return '☁️';
      case WeatherCondition.rainy:
        return '🌧️';
      case WeatherCondition.stormy:
        return '⛈️';
      case WeatherCondition.snowy:
        return '🌨️';
      case WeatherCondition.foggy:
        return '🌫️';
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
      case ActivityLevel.none:
        return 'No Exercise';
      case ActivityLevel.light:
        return 'Light Activity';
      case ActivityLevel.moderate:
        return 'Moderate Exercise';
      case ActivityLevel.intense:
        return 'Intense Workout';
    }
  }

  String _getActivityLevelDescription(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.none:
        return 'Sedentary day, no planned exercise';
      case ActivityLevel.light:
        return 'Walking, stretching, light movement';
      case ActivityLevel.moderate:
        return 'Jogging, cycling, gym workout';
      case ActivityLevel.intense:
        return 'High-intensity training, sports';
    }
  }

  String _getSocialActivityLabel(SocialActivity activity) {
    switch (activity) {
      case SocialActivity.none:
        return 'Solo';
      case SocialActivity.friends:
        return 'Friends';
      case SocialActivity.family:
        return 'Family';
      case SocialActivity.work:
        return 'Colleagues';
      case SocialActivity.party:
        return 'Party/Event';
      case SocialActivity.date:
        return 'Date';
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

    // If duration is negative or more than 24 hours, it's likely an error
    if (duration.isNegative) {
      duration = duration + const Duration(days: 1);
    }

    // Cap at 24 hours maximum to prevent unrealistic values
    if (duration.inHours > 24) {
      duration = const Duration(hours: 24);
    }

    return duration;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Future<void> _selectBedtime() async {
    if (!mounted) return;

    // Show date picker first for bedtime date
    final bedtimeDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _selectedDate.subtract(const Duration(days: 1)),
      lastDate: _selectedDate.add(const Duration(days: 1)),
      helpText: 'Select bedtime date',
    );

    if (!mounted || bedtimeDate == null) return;

    // Then show time picker
    final time = await showTimePicker(
      context: context,
      initialTime: _currentData?.bedtime != null
          ? TimeOfDay.fromDateTime(_currentData!.bedtime!)
          : const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Select bedtime',
    );

    if (!mounted || time == null) return;

    final bedtime = DateTime(
      bedtimeDate.year,
      bedtimeDate.month,
      bedtimeDate.day,
      time.hour,
      time.minute,
    );

    _updateData(_currentData!.copyWith(bedtime: bedtime));
  }

  Future<void> _selectWakeTime() async {
    if (!mounted) return;

    // Show date picker first for wake time date
    final wakeDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _selectedDate,
      lastDate: _selectedDate.add(const Duration(days: 1)),
      helpText: 'Select wake up date',
    );

    if (!mounted || wakeDate == null) return;

    // Then show time picker
    final time = await showTimePicker(
      context: context,
      initialTime: _currentData?.wakeTime != null
          ? TimeOfDay.fromDateTime(_currentData!.wakeTime!)
          : const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Select wake up time',
    );

    if (!mounted || time == null) return;

    final wakeTime = DateTime(
      wakeDate.year,
      wakeDate.month,
      wakeDate.day,
      time.hour,
      time.minute,
    );

    _updateData(_currentData!.copyWith(wakeTime: wakeTime));
  }

  Future<void> _showAddTagDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Add Custom Tag'),
            content: SingleChildScrollView(
              child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter tag name...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text
                      .trim()
                      .isNotEmpty) {
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

  String _getHobbyActivityLabel(HobbyActivity hobby) {
    switch (hobby) {
      case HobbyActivity.reading:
        return 'Reading';
      case HobbyActivity.music:
        return 'Music';
      case HobbyActivity.gaming:
        return 'Gaming';
      case HobbyActivity.cooking:
        return 'Cooking';
      case HobbyActivity.gardening:
        return 'Gardening';
      case HobbyActivity.art:
        return 'Art';
      case HobbyActivity.photography:
        return 'Photography';
      case HobbyActivity.writing:
        return 'Writing';
      case HobbyActivity.sports:
        return 'Sports';
      case HobbyActivity.crafts:
        return 'Crafts';
    }
  }
}
