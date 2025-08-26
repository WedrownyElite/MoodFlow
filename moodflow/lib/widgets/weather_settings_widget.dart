// lib/widgets/weather_settings_widget.dart
import 'package:flutter/material.dart';
import '../services/data/correlation_data_service.dart';
import 'weather_api_setup_dialog.dart';

class WeatherSettingsWidget extends StatefulWidget {
  const WeatherSettingsWidget({super.key});

  @override
  State<WeatherSettingsWidget> createState() => _WeatherSettingsWidgetState();
}

class _WeatherSettingsWidgetState extends State<WeatherSettingsWidget> {
  bool _isConfigured = false;
  bool _isLoading = true;
  String? _apiKeyPreview;
  String _temperatureUnit = 'celsius';

  @override
  void initState() {
    super.initState();
    _loadWeatherSettings();
  }

  Future<void> _loadWeatherSettings() async {
    setState(() => _isLoading = true);

    final isConfigured = await CorrelationDataService.isWeatherApiConfigured();
    String? keyPreview;
    String tempUnit = 'celsius';

    if (isConfigured) {
      final fullKey = await CorrelationDataService.getWeatherApiKey();
      if (fullKey != null && fullKey.length > 8) {
        keyPreview =
            '${fullKey.substring(0, 4)}...${fullKey.substring(fullKey.length - 4)}';
      }
    }

    // Fetch saved temperature unit
    tempUnit = await CorrelationDataService.getTemperatureUnit();

    setState(() {
      _isConfigured = isConfigured;
      _apiKeyPreview = keyPreview;
      _temperatureUnit = tempUnit;
      _isLoading = false;
    });
  }

  Future<void> _configureWeather() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const WeatherApiSetupDialog(),
    );

    if (result == true) {
      await _loadWeatherSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weather API configured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _testWeatherApi() async {
    if (!_isConfigured) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Testing weather API...')),
          ],
        ),
      ),
    );

    try {
      // Test with New York coordinates
      final weather = await CorrelationDataService.fetchWeatherForLocation(
        latitude: 40.7128,
        longitude: -74.0060,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (weather != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('API Test Successful'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your weather API is working correctly!'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Result (New York):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Weather: ${weather.description}'),
                        Text(
                            'Temperature: ${weather.temperature.toStringAsFixed(1)}°C'),
                        Text('Condition: ${weather.condition.name}'),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('API Test Failed'),
                ],
              ),
              content: const Text(
                'The weather API test failed. Please check your API key and internet connection.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _configureWeather();
                  },
                  child: const Text('Reconfigure'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('API Test Error'),
              ],
            ),
            content: Text('Error testing API: ${e.toString()}'),
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

  Future<void> _removeWeatherApi() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Weather API'),
        content: const Text(
          'Are you sure you want to remove your weather API configuration? '
          'This will disable automatic weather fetching.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CorrelationDataService.setWeatherApiKey('');
      await _loadWeatherSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weather API configuration removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.wb_sunny,
                    color: Colors.orange.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather Integration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Automatically track weather conditions',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    _isConfigured ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConfigured
                      ? Colors.green.shade200
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConfigured ? Icons.check_circle : Icons.info,
                    color: _isConfigured
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConfigured ? 'API Configured' : 'Not Configured',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _isConfigured
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (_isConfigured && _apiKeyPreview != null)
                          Text(
                            'API Key: $_apiKeyPreview',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          )
                        else if (!_isConfigured)
                          Text(
                            'Set up OpenWeatherMap API to enable automatic weather tracking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (!_isConfigured) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _configureWeather,
                      icon: const Icon(Icons.settings),
                      label: const Text('Setup Weather API'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testWeatherApi,
                      icon: const Icon(Icons.science),
                      label: const Text('Test API'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _configureWeather,
                      icon: const Icon(Icons.edit),
                      label: const Text('Reconfigure'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (_isConfigured) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _removeWeatherApi,
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Remove API Configuration'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],

            // Feature explanation
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Temperature unit selection
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Temperature Unit',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _setTemperatureUnit('celsius'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _temperatureUnit == 'celsius'
                                        ? Theme.of(context)
                                            .primaryColor
                                            .withValues(alpha: 0.1)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _temperatureUnit == 'celsius'
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'celsius',
                                      ),
                                      const Expanded(
                                          child: Text('Celsius (°C)')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _setTemperatureUnit('fahrenheit'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _temperatureUnit == 'fahrenheit'
                                        ? Theme.of(context)
                                            .primaryColor
                                            .withValues(alpha: 0.1)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _temperatureUnit == 'fahrenheit'
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'fahrenheit',
                                      ),
                                      const Expanded(
                                          child: Text('Fahrenheit (°F)')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Automatically fetches weather data when logging daily factors\n'
                    '• Helps identify correlations between weather and your mood\n'
                    '• Uses OpenWeatherMap\'s free API (requires account)\n'
                    '• Your API key is stored securely on your device only',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setTemperatureUnit(String? value) async {
    if (value == null) return;

    await CorrelationDataService.setTemperatureUnit(value);

    if (!mounted) return; // Check mounted before setState
    setState(() => _temperatureUnit = value);

    if (!mounted) return; // Check mounted before using context

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Temperature unit changed to ${value == 'celsius' ? 'Celsius' : 'Fahrenheit'}'),
      ),
    );
  }
}
