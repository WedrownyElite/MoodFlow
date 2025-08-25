// lib/services/data/correlation_data_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';

enum WeatherCondition {
  sunny,
  cloudy,
  rainy,
  stormy,
  snowy,
  foggy,
}

enum ActivityLevel {
  none,
  light,
  moderate,
  intense,
}

enum SocialActivity {
  none,
  friends,
  family,
  work,
  party,
  date,
}

class CorrelationData {
  final DateTime date;
  final WeatherCondition? weather;
  final double? temperature; // Added temperature
  final String? weatherDescription; // Added detailed description
  final double? sleepQuality; // 1-10 scale
  final Duration? sleepDuration;
  final DateTime? bedtime;
  final DateTime? wakeTime;
  final ActivityLevel? exerciseLevel;
  final SocialActivity? socialActivity;
  final int? workStress; // 1-10 scale
  final List<String> customTags;
  final String? notes;
  final bool autoWeather; // Whether weather was fetched automatically
  final Map<String, dynamic>? weatherData; // Store raw weather data
  final String? temperatureUnit;

  CorrelationData({
    required this.date,
    this.weather,
    this.temperature,
    this.temperatureUnit,
    this.weatherDescription,
    this.sleepQuality,
    this.sleepDuration,
    this.bedtime,
    this.wakeTime,
    this.exerciseLevel,
    this.socialActivity,
    this.workStress,
    this.customTags = const [],
    this.notes,
    this.autoWeather = false,
    this.weatherData,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weather': weather?.name,
    'temperature': temperature,
    'temperatureUnit': temperatureUnit,
    'weatherDescription': weatherDescription,
    'sleepQuality': sleepQuality,
    'sleepDuration': sleepDuration?.inMinutes,
    'bedtime': bedtime?.toIso8601String(),
    'wakeTime': wakeTime?.toIso8601String(),
    'exerciseLevel': exerciseLevel?.name,
    'socialActivity': socialActivity?.name,
    'workStress': workStress,
    'customTags': customTags,
    'notes': notes,
    'autoWeather': autoWeather,
    'weatherData': weatherData,
    'timestamp': DateTime.now().toIso8601String(),
  };

  factory CorrelationData.fromJson(Map<String, dynamic> json) => CorrelationData(
    date: DateTime.parse(json['date']),
    weather: json['weather'] != null
        ? WeatherCondition.values.firstWhere((e) => e.name == json['weather'])
        : null,
    temperature: json['temperature']?.toDouble(),
    temperatureUnit: json['temperatureUnit'],
    weatherDescription: json['weatherDescription'],
    sleepQuality: json['sleepQuality']?.toDouble(),
    sleepDuration: json['sleepDuration'] != null
        ? Duration(minutes: json['sleepDuration'])
        : null,
    bedtime: json['bedtime'] != null
        ? DateTime.parse(json['bedtime'])
        : null,
    wakeTime: json['wakeTime'] != null
        ? DateTime.parse(json['wakeTime'])
        : null,
    exerciseLevel: json['exerciseLevel'] != null
        ? ActivityLevel.values.firstWhere((e) => e.name == json['exerciseLevel'])
        : null,
    socialActivity: json['socialActivity'] != null
        ? SocialActivity.values.firstWhere((e) => e.name == json['socialActivity'])
        : null,
    workStress: json['workStress'],
    customTags: List<String>.from(json['customTags'] ?? []),
    notes: json['notes'],
    autoWeather: json['autoWeather'] ?? false,
    weatherData: json['weatherData'],
  );

  CorrelationData copyWith({
    DateTime? date,
    WeatherCondition? weather,
    double? temperature,
    String? temperatureUnit,
    String? weatherDescription,
    double? sleepQuality,
    Duration? sleepDuration,
    DateTime? bedtime,
    DateTime? wakeTime,
    ActivityLevel? exerciseLevel,
    SocialActivity? socialActivity,
    int? workStress,
    List<String>? customTags,
    String? notes,
    bool? autoWeather,
    Map<String, dynamic>? weatherData,
  }) => CorrelationData(
    date: date ?? this.date,
    weather: weather ?? this.weather,
    temperature: temperature ?? this.temperature,
    temperatureUnit: temperatureUnit ?? this.temperatureUnit,
    weatherDescription: weatherDescription ?? this.weatherDescription,
    sleepQuality: sleepQuality ?? this.sleepQuality,
    sleepDuration: sleepDuration ?? this.sleepDuration,
    bedtime: bedtime ?? this.bedtime,
    wakeTime: wakeTime ?? this.wakeTime,
    exerciseLevel: exerciseLevel ?? this.exerciseLevel,
    socialActivity: socialActivity ?? this.socialActivity,
    workStress: workStress ?? this.workStress,
    customTags: customTags ?? this.customTags,
    notes: notes ?? this.notes,
    autoWeather: autoWeather ?? this.autoWeather,
    weatherData: weatherData ?? this.weatherData,
  );
}

class WeatherResult {
  final WeatherCondition condition;
  final double temperature;
  final String description;
  final Map<String, dynamic> rawData;

  WeatherResult({
    required this.condition,
    required this.temperature,
    required this.description,
    required this.rawData,
  });
}

class CorrelationInsight {
  final String title;
  final String description;
  final double strength; // 0-1, how strong the correlation is
  final String category; // 'weather', 'sleep', 'exercise', etc.
  final Map<String, dynamic> data;

  CorrelationInsight({
    required this.title,
    required this.description,
    required this.strength,
    required this.category,
    this.data = const {},
  });
}

class CorrelationDataService {
  static const String _keyPrefix = 'correlation_';
  static const String _settingsKey = 'correlation_settings';
  static const String _weatherApiKeyKey = 'weather_api_key';
  static const String _locationPermissionKey = 'location_permission_granted';
  static const String _temperatureUnitKey = 'temperature_unit';

  // OpenWeatherMap One Call 3.0 API
  static const String _weatherApiUrl = 'https://api.openweathermap.org/data/3.0/onecall';

  /// Save user's weather API key
  static Future<void> setWeatherApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weatherApiKeyKey, apiKey);
    Logger.correlationService('✅ Weather API key saved');
  }

  /// Get user's weather API key
  static Future<String?> getWeatherApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_weatherApiKeyKey);
  }

  /// Check if weather API is configured
  static Future<bool> isWeatherApiConfigured() async {
    final apiKey = await getWeatherApiKey();
    return apiKey != null && apiKey.isNotEmpty && apiKey != 'YOUR_API_KEY';
  }

  /// Set temperature unit preference
  static Future<void> setTemperatureUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_temperatureUnitKey, unit);
    Logger.correlationService('✅ Temperature unit set to $unit');
  }

  /// Get temperature unit preference
  static Future<String> getTemperatureUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_temperatureUnitKey) ?? 'celsius';
  }

  /// Request location permission and get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Logger.correlationService('❌ Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.correlationService('❌ Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Logger.correlationService('❌ Location permissions are permanently denied');
        return null;
      }

      // Mark permission as granted
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_locationPermissionKey, true);

      // Get current position with high accuracy
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      Logger.correlationService('❌ Error getting location: $e');
      return null;
    }
  }

  /// Fetch weather data using OpenWeatherMap One Call 3.0 API
  static Future<WeatherResult?> fetchWeatherForLocation({
    required double latitude,
    required double longitude,
    DateTime? forDate,
  }) async {
    final apiKey = await getWeatherApiKey();
    if (!await isWeatherApiConfigured()) {
      Logger.correlationService('⚠️ Weather API key not configured');
      return null;
    }

    try {
      final now = DateTime.now();
      final targetDate = forDate ?? now;
      final daysDifference = now.difference(targetDate).inDays;

      String url;
      Map<String, String> params = {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'appid': apiKey!,
        'units': await getTemperatureUnit() == 'celsius' ? 'metric' : 'imperial',
        'lang': 'en',
      };

      if (daysDifference > 0 && daysDifference <= 5) {
        // Use timemachine endpoint for historical data (last 5 days)
        final timestamp = (targetDate.millisecondsSinceEpoch / 1000).round();
        url = 'https://api.openweathermap.org/data/3.0/onecall/timemachine';
        params['dt'] = timestamp.toString();
      } else if (daysDifference > 5) {
        // For dates older than 5 days, try the day_summary endpoint
        final dateString = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
        url = 'https://api.openweathermap.org/data/3.0/onecall/day_summary';
        params['date'] = dateString;
      } else {
        // For current/future dates, use current weather
        params['exclude'] = 'minutely,alerts';
        url = 'https://api.openweathermap.org/data/3.0/onecall';
      }

      final uri = Uri.parse(url).replace(queryParameters: params);
      Logger.correlationService('🌤️ Fetching weather from: ${uri.toString().replaceAll(apiKey, 'HIDDEN_KEY')}');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Handle different API response formats
        Map<String, dynamic>? weatherData;

        if (url.contains('timemachine')) {
          // Timemachine API response format
          final hourlyData = data['data'] as List<dynamic>?;
          if (hourlyData != null && hourlyData.isNotEmpty) {
            weatherData = hourlyData.first as Map<String, dynamic>;
          }
        } else if (url.contains('day_summary')) {
          // Day summary API response format
          weatherData = data;
        } else {
          // Current weather API response format
          weatherData = data['current'] as Map<String, dynamic>?;
        }

        if (weatherData == null) {
          Logger.correlationService('❌ No weather data in response');
          return null;
        }

        final weatherArray = weatherData['weather'] as List<dynamic>?;
        if (weatherArray == null || weatherArray.isEmpty) {
          Logger.correlationService('❌ No weather conditions in response');
          return null;
        }

        final weatherInfo = weatherArray.first as Map<String, dynamic>;
        final rawTemp = (weatherData['temp'] as num?)?.toDouble() ??
            (weatherData['temperature'] as num?)?.toDouble() ?? 15.0;
        final unit = await getTemperatureUnit();
        final temperature = rawTemp;
        final description = weatherInfo['description'] as String;
        final weatherMain = (weatherInfo['main'] as String).toLowerCase();

        final condition = _mapWeatherCondition(weatherMain, weatherInfo['id'] as int);

        Logger.correlationService('✅ Weather fetched for ${forDate?.toString() ?? 'current'}: $description, ${temperature.toStringAsFixed(1)}°C');

        return WeatherResult(
          condition: condition,
          temperature: temperature,
          description: description,
          rawData: data,
        );

      } else if (response.statusCode == 401) {
        Logger.correlationService('❌ Weather API authentication failed (401) - check API key');
        return null;
      } else {
        Logger.correlationService('❌ Weather API error (${response.statusCode}): ${response.body}');
        return null;
      }

    } catch (e) {
      Logger.correlationService('❌ Error fetching weather: $e');
      return null;
    }
  }

  static double convertTemperature(double temp, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return temp;

    if (fromUnit == 'celsius' && toUnit == 'fahrenheit') {
      return (temp * 9/5) + 32;
    } else if (fromUnit == 'fahrenheit' && toUnit == 'celsius') {
      return (temp - 32) * 5/9;
    }

    return temp;
  }

  /// Auto-fetch weather for current location and date
  static Future<WeatherResult?> autoFetchWeather({DateTime? forDate}) async {
    if (!await isWeatherApiConfigured()) {
      return null;
    }

    final position = await getCurrentLocation();
    if (position == null) {
      return null;
    }

    return await fetchWeatherForLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      forDate: forDate,
    );
  }

  /// Map OpenWeatherMap weather conditions to our enum
  static WeatherCondition _mapWeatherCondition(String main, int id) {
    // OpenWeatherMap condition IDs: https://openweathermap.org/weather-conditions
    switch (main) {
      case 'clear':
        return WeatherCondition.sunny;
      case 'clouds':
        return WeatherCondition.cloudy;
      case 'rain':
      case 'drizzle':
        return WeatherCondition.rainy;
      case 'thunderstorm':
        return WeatherCondition.stormy;
      case 'snow':
        return WeatherCondition.snowy;
      case 'mist':
      case 'fog':
      case 'haze':
      case 'dust':
      case 'sand':
      case 'ash':
      case 'squall':
      case 'tornado':
        return WeatherCondition.foggy;
      default:
      // Fallback based on condition ID ranges
        if (id >= 200 && id < 300) return WeatherCondition.stormy; // Thunderstorm
        if (id >= 300 && id < 400) return WeatherCondition.rainy;  // Drizzle
        if (id >= 500 && id < 600) return WeatherCondition.rainy;  // Rain
        if (id >= 600 && id < 700) return WeatherCondition.snowy;  // Snow
        if (id >= 700 && id < 800) return WeatherCondition.foggy;  // Atmosphere
        if (id == 800) return WeatherCondition.sunny;              // Clear
        if (id > 800) return WeatherCondition.cloudy;              // Clouds

        return WeatherCondition.cloudy; // Default fallback
    }
  }

  /// Save correlation data for a specific date
  static Future<bool> saveCorrelationData(DateTime date, CorrelationData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForDate(date);
      final jsonData = jsonEncode(data.toJson());

      final success = await prefs.setString(key, jsonData);
      if (success) {
        Logger.correlationService('✅ Correlation data saved for ${_formatDate(date)}');
        return true;
      }
      return false;
    } catch (e) {
      Logger.correlationService('❌ Error saving correlation data: $e');
      return false;
    }
  }

  /// Load correlation data for a specific date
  static Future<CorrelationData?> loadCorrelationData(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForDate(date);
      final jsonString = prefs.getString(key);

      if (jsonString == null) return null;

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return CorrelationData.fromJson(data);
    } catch (e) {
      Logger.correlationService('❌ Error loading correlation data: $e');
      return null;
    }
  }

  /// Generate correlation insights based on historical data
  static Future<List<CorrelationInsight>> generateInsights({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final insights = <CorrelationInsight>[];

    // Default to last 3 months if no range specified
    endDate ??= DateTime.now();
    startDate ??= endDate.subtract(const Duration(days: 90));

    // Load all correlation and mood data for the period
    final correlationData = <CorrelationData>[];
    final moodData = <DateTime, double>{};

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      // Load correlation data
      final correlation = await loadCorrelationData(currentDate);
      if (correlation != null) {
        correlationData.add(correlation);
      }

      // Load mood data (calculate daily average)
      // Note: You'll need to import MoodDataService here
      // final moodService = MoodDataService();
      // double totalMood = 0;
      // int moodCount = 0;
      // for (int segment = 0; segment < 3; segment++) {
      //   final mood = await MoodDataService.loadMood(currentDate, segment);
      //   if (mood != null && mood['rating'] != null) {
      //     totalMood += (mood['rating'] as num).toDouble();
      //     moodCount++;
      //   }
      // }
      // if (moodCount > 0) {
      //   moodData[currentDate] = totalMood / moodCount;
      // }

      currentDate = currentDate.add(const Duration(days: 1));
    }

    if (correlationData.isEmpty || moodData.isEmpty) {
      return insights;
    }

    // Analyze weather correlations
    insights.addAll(await _analyzeWeatherCorrelations(correlationData, moodData));

    // Analyze sleep correlations
    insights.addAll(await _analyzeSleepCorrelations(correlationData, moodData));

    // Analyze exercise correlations
    insights.addAll(await _analyzeExerciseCorrelations(correlationData, moodData));

    // Sort by strength and return top insights
    insights.sort((a, b) => b.strength.compareTo(a.strength));
    return insights.take(10).toList();
  }

  // [Include all the existing analysis methods here - _analyzeWeatherCorrelations, etc.]
  // ... (keeping the same analysis methods from your original code)

  static Future<List<CorrelationInsight>> _analyzeWeatherCorrelations(
      List<CorrelationData> correlationData,
      Map<DateTime, double> moodData,
      ) async {
    final insights = <CorrelationInsight>[];
    final weatherMoods = <WeatherCondition, List<double>>{};
    final temperatureMoods = <double>[];
    final moodValues = <double>[];

    // Group moods by weather condition and collect temperature data
    for (final correlation in correlationData) {
      if (moodData.containsKey(correlation.date)) {
        final mood = moodData[correlation.date]!;

        // Weather condition analysis
        if (correlation.weather != null) {
          weatherMoods.putIfAbsent(correlation.weather!, () => []).add(mood);
        }

        // Temperature correlation analysis
        if (correlation.temperature != null) {
          temperatureMoods.add(correlation.temperature!);
          moodValues.add(mood);
        }
      }
    }

    // Analyze weather conditions
    if (weatherMoods.length >= 2) {
      final weatherAverages = <WeatherCondition, double>{};
      for (final entry in weatherMoods.entries) {
        if (entry.value.length >= 3) {
          weatherAverages[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
        }
      }

      if (weatherAverages.length >= 2) {
        final sortedWeather = weatherAverages.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final best = sortedWeather.first;
        final worst = sortedWeather.last;
        final difference = best.value - worst.value;

        if (difference >= 1.0) {
          insights.add(CorrelationInsight(
            title: 'Weather affects your mood',
            description: 'You feel ${difference.toStringAsFixed(1)} points better on ${_getWeatherName(best.key)} days (${best.value.toStringAsFixed(1)}) vs ${_getWeatherName(worst.key)} days (${worst.value.toStringAsFixed(1)})',
            strength: (difference / 9.0).clamp(0.0, 1.0),
            category: 'weather',
            data: {
              'best': best.key.name,
              'worst': worst.key.name,
              'difference': difference,
            },
          ));
        }
      }
    }

    // Analyze temperature correlation
    if (temperatureMoods.length >= 10) {
      final correlation = _calculateCorrelation(temperatureMoods, moodValues);
      if (correlation.abs() >= 0.3) {
        insights.add(CorrelationInsight(
          title: correlation > 0 ? 'Warmer weather boosts your mood' : 'Cooler weather affects your mood',
          description: correlation > 0
              ? 'Your mood tends to improve with warmer temperatures'
              : 'Your mood seems to be affected by cooler temperatures',
          strength: correlation.abs(),
          category: 'weather',
          data: {'temperatureCorrelation': correlation},
        ));
      }
    }

    return insights;
  }

  // Analyze Sleep Correlation
  static Future<List<CorrelationInsight>> _analyzeSleepCorrelations(
      List<CorrelationData> correlationData,
      Map<DateTime, double> moodData,
      ) async {
    final insights = <CorrelationInsight>[];
    final sleepMoods = <double>[];
    final moodValues = <double>[];

    // Collect sleep quality and corresponding mood data
    for (final correlation in correlationData) {
      if (correlation.sleepQuality != null && moodData.containsKey(correlation.date)) {
        sleepMoods.add(correlation.sleepQuality!);
        moodValues.add(moodData[correlation.date]!);
      }
    }

    if (sleepMoods.length >= 10) {
      final correlation = _calculateCorrelation(sleepMoods, moodValues);
      if (correlation.abs() >= 0.4) {
        insights.add(CorrelationInsight(
          title: correlation > 0 ? 'Better sleep improves your mood' : 'Poor sleep affects your mood',
          description: 'Sleep quality ${correlation > 0 ? 'positively' : 'negatively'} correlates with your mood (${(correlation * 100).round()}% correlation)',
          strength: correlation.abs(),
          category: 'sleep',
          data: {'sleepCorrelation': correlation},
        ));
      }
    }

    return insights;
  }

  // Analyze Exercise Correlations
  static Future<List<CorrelationInsight>> _analyzeExerciseCorrelations(
      List<CorrelationData> correlationData,
      Map<DateTime, double> moodData,
      ) async {
    final insights = <CorrelationInsight>[];
    final exerciseMoods = <ActivityLevel, List<double>>{};

    // Group moods by exercise level
    for (final correlation in correlationData) {
      if (correlation.exerciseLevel != null && moodData.containsKey(correlation.date)) {
        final mood = moodData[correlation.date]!;
        exerciseMoods.putIfAbsent(correlation.exerciseLevel!, () => []).add(mood);
      }
    }

    if (exerciseMoods.length >= 2) {
      final averages = <ActivityLevel, double>{};
      for (final entry in exerciseMoods.entries) {
        if (entry.value.length >= 3) {
          averages[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
        }
      }

      if (averages.length >= 2) {
        final sortedLevels = averages.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final best = sortedLevels.first;
        final worst = sortedLevels.last;
        final difference = best.value - worst.value;

        if (difference >= 1.0) {
          insights.add(CorrelationInsight(
            title: 'Exercise level affects your mood',
            description: 'You feel ${difference.toStringAsFixed(1)} points better on ${_getActivityName(best.key)} days vs ${_getActivityName(worst.key)} days',
            strength: (difference / 9.0).clamp(0.0, 1.0),
            category: 'exercise',
            data: {
              'bestLevel': best.key.name,
              'worstLevel': worst.key.name,
              'difference': difference,
            },
          ));
        }
      }
    }

    return insights;
  }

  static String _getActivityName(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.none: return 'no exercise';
      case ActivityLevel.light: return 'light activity';
      case ActivityLevel.moderate: return 'moderate exercise';
      case ActivityLevel.intense: return 'intense workout';
    }
  }

  /// Simple correlation coefficient calculation
  static double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;

    final n = x.length;
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;

    double numerator = 0;
    double xVariance = 0;
    double yVariance = 0;

    for (int i = 0; i < n; i++) {
      final xDiff = x[i] - xMean;
      final yDiff = y[i] - yMean;

      numerator += xDiff * yDiff;
      xVariance += xDiff * xDiff;
      yVariance += yDiff * yDiff;
    }

    final denominator = (xVariance * yVariance).abs();
    if (denominator == 0) return 0.0;

    return numerator / denominator.abs();
  }

  static String _getWeatherName(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny: return 'sunny';
      case WeatherCondition.cloudy: return 'cloudy';
      case WeatherCondition.rainy: return 'rainy';
      case WeatherCondition.stormy: return 'stormy';
      case WeatherCondition.snowy: return 'snowy';
      case WeatherCondition.foggy: return 'foggy';
    }
  }

  static String _getKeyForDate(DateTime date) {
    return '$_keyPrefix${_formatDate(date)}';
  }

  static String _formatDate(DateTime date) {
    return date.toIso8601String().substring(0, 10); // YYYY-MM-DD
  }
}