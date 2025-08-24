// lib/widgets/weather_api_setup_dialog.dart
import 'package:flutter/material.dart';
import '../services/data/correlation_data_service.dart';

class WeatherApiSetupDialog extends StatefulWidget {
  const WeatherApiSetupDialog({super.key});

  @override
  State<WeatherApiSetupDialog> createState() => _WeatherApiSetupDialogState();
}

class _WeatherApiSetupDialogState extends State<WeatherApiSetupDialog> {
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _isTestingApi = false;
  String? _errorMessage;
  bool _setupComplete = false;

  @override
  void initState() {
    super.initState();
    _loadExistingApiKey();
  }

  Future<void> _loadExistingApiKey() async {
    final existingKey = await CorrelationDataService.getWeatherApiKey();
    if (existingKey != null) {
      _apiKeyController.text = existingKey;
    }
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your API key';
      });
      return;
    }

    setState(() {
      _isTestingApi = true;
      _errorMessage = null;
    });

    try {
      // Save the API key
      await CorrelationDataService.setWeatherApiKey(apiKey);

      // Test the API by fetching weather for a dummy location
      final weather = await CorrelationDataService.fetchWeatherForLocation(
        latitude: 40.7128, // New York coordinates for testing
        longitude: -74.0060,
      );

      if (weather != null) {
        setState(() {
          _setupComplete = true;
          _isTestingApi = false;
        });
      } else {
        setState(() {
          _errorMessage = 'API key test failed. Please check your key and try again.';
          _isTestingApi = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error testing API key: ${e.toString()}';
        _isTestingApi = false;
      });
    }
  }

  void _showOpenWeatherMapInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get Your API Key'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To get your free OpenWeatherMap API key:'),
            SizedBox(height: 8),
            Text('1. Visit: openweathermap.org'),
            Text('2. Sign up for a free account'),
            Text('3. Go to "API keys" in your account'),
            Text('4. Copy your default API key'),
            Text('5. Paste it in the field above'),
          ],
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wb_sunny, color: Colors.orange),
          SizedBox(width: 8),
          Text('Weather API Setup'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_setupComplete) ...[
                const Text(
                  'To enable automatic weather tracking, you need a free OpenWeatherMap API key.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Instructions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to get your free API key:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('1. Visit openweathermap.org'),
                        const Text('2. Sign up for a free account'),
                        const Text('3. Go to "API keys" in your account'),
                        const Text('4. Copy your default API key'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showOpenWeatherMapInfo,
                          icon: const Icon(Icons.info, size: 16),
                          label: const Text('Show detailed steps'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // API Key Input
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'Your API Key',
                    hintText: 'e.g., 1234567890abcdef1234567890abcdef',
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                    suffixIcon: _isTestingApi
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                        : null,
                  ),
                  maxLines: 1,
                ),

                const SizedBox(height: 12),

                // Privacy note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip, size: 16, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Your API key is stored securely on your device only.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Success state
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Weather API Setup Complete!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your weather data will now be automatically fetched to help track correlations with your mood.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_setupComplete) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: _isTestingApi ? null : _saveApiKey,
            child: _isTestingApi
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Save & Test'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}