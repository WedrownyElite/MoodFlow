// lib/services/data/correlation_data_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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

  CorrelationData({
    required this.date,
    this.weather,
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
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weather': weather?.name,
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
    'timestamp': DateTime.now().toIso8601String(),
  };

  factory CorrelationData.fromJson(Map<String, dynamic> json) => CorrelationData(
    date: DateTime.parse(json['date']),
    weather: json['weather'] != null
        ? WeatherCondition.values.firstWhere((e) => e.name == json['weather'])
        : null,
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
  );

  CorrelationData copyWith({
    DateTime? date,
    WeatherCondition? weather,
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
  }) => CorrelationData(
    date: date ?? this.date,
    weather: weather ?? this.weather,
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
  );
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

  // OpenWeatherMap API (free tier allows 1000 calls/month)
  static const String _weatherApiKey = 'YOUR_API_KEY'; // User should set this
  static const String _weatherApiUrl = 'https://api.openweathermap.org/data/2.5/weather';

  /// Save correlation data for a specific date
  static Future<bool> saveCorrelationData(DateTime date, CorrelationData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForDate(date);
      final jsonData = jsonEncode(data.toJson());

      final success = await prefs.setString(key, jsonData);
      if (success) {
        Logger.dataService('✅ Correlation data saved for ${_formatDate(date)}');
        return true;
      }
      return false;
    } catch (e) {
      Logger.dataService('❌ Error saving correlation data: $e');
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
      Logger.dataService('❌ Error loading correlation data: $e');
      return null;
    }
  }

  /// Fetch weather data automatically for a location
  static Future<WeatherCondition?> fetchWeatherForLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (_weatherApiKey == 'YOUR_API_KEY') {
      Logger.dataService('⚠️ Weather API key not configured');
      return null;
    }

    try {
      final url = '$_weatherApiUrl?lat=$latitude&lon=$longitude&appid=$_weatherApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherMain = data['weather'][0]['main'].toString().toLowerCase();

        // Map OpenWeather conditions to our enum
        switch (weatherMain) {
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
            return WeatherCondition.foggy;
          default:
            return WeatherCondition.cloudy;
        }
      }
    } catch (e) {
      Logger.dataService('❌ Error fetching weather: $e');
    }

    return null;
  }

  /// Get correlation insights based on historical data
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
      double totalMood = 0;
      int moodCount = 0;
      for (int segment = 0; segment < 3; segment++) {
        // You'd import MoodDataService here
        // final mood = await MoodDataService.loadMood(currentDate, segment);
        // if (mood != null && mood['rating'] != null) {
        //   totalMood += (mood['rating'] as num).toDouble();
        //   moodCount++;
        // }
      }
      if (moodCount > 0) {
        moodData[currentDate] = totalMood / moodCount;
      }

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

  static Future<List<CorrelationInsight>> _analyzeWeatherCorrelations(
      List<CorrelationData> correlationData,
      Map<DateTime, double> moodData,
      ) async {
    final insights = <CorrelationInsight>[];
    final weatherMoods = <WeatherCondition, List<double>>{};

    // Group moods by weather condition
    for (final correlation in correlationData) {
      if (correlation.weather != null && moodData.containsKey(correlation.date)) {
        weatherMoods.putIfAbsent(correlation.weather!, () => [])
            .add(moodData[correlation.date]!);
      }
    }

    if (weatherMoods.length < 2) return insights;

    // Calculate averages and find patterns
    final weatherAverages = <WeatherCondition, double>{};
    for (final entry in weatherMoods.entries) {
      if (entry.value.length >= 3) { // Need at least 3 data points
        weatherAverages[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }

    if (weatherAverages.length >= 2) {
      // Find best and worst weather conditions
      final sortedWeather = weatherAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final best = sortedWeather.first;
      final worst = sortedWeather.last;

      final difference = best.value - worst.value;

      if (difference >= 1.0) { // Significant difference
        insights.add(CorrelationInsight(
          title: 'Weather affects your mood',
          description: 'You feel ${difference.toStringAsFixed(1)} points better on ${_getWeatherName(best.key)} days (${best.value.toStringAsFixed(1)}) vs ${_getWeatherName(worst.key)} days (${worst.value.toStringAsFixed(1)})',
          strength: (difference / 9.0).clamp(0.0, 1.0), // Normalize to 0-1
          category: 'weather',
          data: {
            'best': best.key.name,
            'worst': worst.key.name,
            'difference': difference,
          },
        ));
      }
    }

    return insights;
  }

  static Future<List<CorrelationInsight>> _analyzeSleepCorrelations(
      List<CorrelationData> correlationData,
      Map<DateTime, double> moodData,
      ) async {
    final insights = <CorrelationInsight>[];
    final sleepMoods = <int, List<double>>{}; // Sleep quality -> moods
    final durationMoods = <int, List<double>>{}; // Sleep hours -> moods

    for (final correlation in correlationData) {
      if (moodData.containsKey(correlation.date)) {
        final mood = moodData[correlation.date]!;

        // Sleep quality correlation
        if (correlation.sleepQuality != null) {
          final quality = correlation.sleepQuality!.round();
          sleepMoods.putIfAbsent(quality, () => []).add(mood);
        }

        // Sleep duration correlation
        if (correlation.sleepDuration != null) {
          final hours = (correlation.sleepDuration!.inMinutes / 60).round();
          if (hours >= 4 && hours <= 12) { // Reasonable range
            durationMoods.putIfAbsent(hours, () => []).add(mood);
          }
        }
      }
    }

    // Analyze sleep quality correlation
    if (sleepMoods.length >= 3) {
      final qualityAverages = <int, double>{};
      sleepMoods.forEach((quality, moods) {
        if (moods.length >= 2) {
          qualityAverages[quality] = moods.reduce((a, b) => a + b) / moods.length;
        }
      });

      if (qualityAverages.length >= 2) {
        // Calculate correlation coefficient (simplified)
        double correlation = _calculateCorrelation(
          qualityAverages.keys.map((k) => k.toDouble()).toList(),
          qualityAverages.values.toList(),
        );

        if (correlation.abs() >= 0.3) { // Moderate correlation
          insights.add(CorrelationInsight(
            title: correlation > 0 ? 'Better sleep improves mood' : 'Sleep quality affects mood',
            description: correlation > 0
                ? 'Your mood tends to be ${(correlation * 2).toStringAsFixed(1)} points higher when you sleep well'
                : 'Poor sleep quality seems to negatively impact your mood',
            strength: correlation.abs(),
            category: 'sleep',
            data: {'correlation': correlation},
          ));
        }
      }
    }

    return insights;
  }

  static Future<List<CorrelationInsight>> _analyzeExerciseCorrelations(
      List<CorrelationData> correlationData,
      Map<DateTime, double> moodData,
      ) async {
    final insights = <CorrelationInsight>[];
    final exerciseMoods = <ActivityLevel, List<double>>{};

    for (final correlation in correlationData) {
      if (correlation.exerciseLevel != null && moodData.containsKey(correlation.date)) {
        exerciseMoods.putIfAbsent(correlation.exerciseLevel!, () => [])
            .add(moodData[correlation.date]!);
      }
    }

    if (exerciseMoods.length >= 2) {
      final exerciseAverages = <ActivityLevel, double>{};
      exerciseMoods.forEach((level, moods) {
        if (moods.length >= 2) {
          exerciseAverages[level] = moods.reduce((a, b) => a + b) / moods.length;
        }
      });

      if (exerciseAverages.containsKey(ActivityLevel.none) &&
          (exerciseAverages.containsKey(ActivityLevel.moderate) ||
              exerciseAverages.containsKey(ActivityLevel.intense))) {

        final noExercise = exerciseAverages[ActivityLevel.none] ?? 0;
        final withExercise = [
          exerciseAverages[ActivityLevel.moderate],
          exerciseAverages[ActivityLevel.intense],
        ].where((v) => v != null).fold(0.0, (a, b) => a! > b! ? a : b)!;

        final difference = withExercise - noExercise;

        if (difference >= 0.8) { // Noticeable improvement
          insights.add(CorrelationInsight(
            title: 'Exercise boosts your mood',
            description: 'You feel ${difference.toStringAsFixed(1)} points better on days when you exercise (${withExercise.toStringAsFixed(1)}) vs no exercise (${noExercise.toStringAsFixed(1)})',
            strength: (difference / 9.0).clamp(0.0, 1.0),
            category: 'exercise',
            data: {
              'difference': difference,
              'withExercise': withExercise,
              'noExercise': noExercise,
            },
          ));
        }
      }
    }

    return insights;
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
      case WeatherCondition.sunny:
        return 'sunny';
      case WeatherCondition.cloudy:
        return 'cloudy';
      case WeatherCondition.rainy:
        return 'rainy';
      case WeatherCondition.stormy:
        return 'stormy';
      case WeatherCondition.snowy:
        return 'snowy';
      case WeatherCondition.foggy:
        return 'foggy';
    }
  }

  static String _getKeyForDate(DateTime date) {
    return '$_keyPrefix${_formatDate(date)}';
  }

  static String _formatDate(DateTime date) {
    return date.toIso8601String().substring(0, 10); // YYYY-MM-DD
  }
}