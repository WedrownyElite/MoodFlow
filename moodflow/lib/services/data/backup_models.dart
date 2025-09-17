import 'correlation_data_service.dart';

// Data Models for Export/Import
class MoodDataExport {
  final String appVersion;
  final DateTime exportDate;
  final List<MoodEntryExport> moodEntries;
  final List<MoodGoalExport> goals;
  final List<CorrelationEntryExport> correlationEntries;
  final NotificationSettingsExport notificationSettings;
  final Map<String, dynamic> userPreferences;
  final List<Map<String, dynamic>> savedAnalyses;
  // REMOVED: final Map<String, dynamic> smartInsightsData;

  MoodDataExport({
    required this.appVersion,
    required this.exportDate,
    required this.moodEntries,
    required this.goals,
    required this.correlationEntries,
    required this.notificationSettings,
    required this.userPreferences,
    required this.savedAnalyses,
    // REMOVED: required this.smartInsightsData,
  });

  Map<String, dynamic> toJson() => {
    'appVersion': appVersion,
    'exportDate': exportDate.toIso8601String(),
    'moodEntries': moodEntries.map((e) => e.toJson()).toList(),
    'goals': goals.map((g) => g.toJson()).toList(),
    'correlationEntries':
    correlationEntries.map((c) => c.toJson()).toList(),
    'notificationSettings': notificationSettings.toJson(),
    'userPreferences': userPreferences,
    'savedAnalyses': savedAnalyses,
    // REMOVED: 'smartInsightsData': smartInsightsData,
  };

  factory MoodDataExport.fromJson(Map<String, dynamic> json) => MoodDataExport(
    appVersion: json['appVersion'] ?? '1.0.0',
    exportDate: DateTime.parse(json['exportDate']),
    moodEntries: (json['moodEntries'] as List)
        .map((e) => MoodEntryExport.fromJson(e))
        .toList(),
    goals: (json['goals'] as List)
        .map((g) => MoodGoalExport.fromJson(g))
        .toList(),
    correlationEntries: (json['correlationEntries'] as List? ?? [])
        .map((c) => CorrelationEntryExport.fromJson(c))
        .toList(),
    notificationSettings: NotificationSettingsExport.fromJson(
        json['notificationSettings'] ?? {}),
    userPreferences: json['userPreferences'] ?? {},
    savedAnalyses:
    List<Map<String, dynamic>>.from(json['savedAnalyses'] ?? []),
    // REMOVED: smartInsightsData: Map<String, dynamic>.from(json['smartInsightsData'] ?? {}),
  );
}

class MoodEntryExport {
  final DateTime date;
  final int segment;
  final double rating;
  final String note;
  final DateTime loggedAt;
  final DateTime? lastModified;

  MoodEntryExport({
    required this.date,
    required this.segment,
    required this.rating,
    required this.note,
    required this.loggedAt,
    this.lastModified,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'segment': segment,
    'rating': rating,
    'note': note,
    'loggedAt': loggedAt.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
  };

  factory MoodEntryExport.fromJson(Map<String, dynamic> json) =>
      MoodEntryExport(
        date: DateTime.parse(json['date']),
        segment: json['segment'],
        rating: (json['rating'] as num).toDouble(),
        note: json['note'] ?? '',
        loggedAt: DateTime.parse(json['loggedAt']),
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
      );
}

class MoodGoalExport {
  final String id;
  final String title;
  final String description;
  final String type;
  final double targetValue;
  final int targetDays;
  final DateTime createdDate;
  final DateTime? completedDate;
  final bool isCompleted;

  MoodGoalExport({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.targetDays,
    required this.createdDate,
    this.completedDate,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'targetValue': targetValue,
    'targetDays': targetDays,
    'createdDate': createdDate.toIso8601String(),
    'completedDate': completedDate?.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory MoodGoalExport.fromJson(Map<String, dynamic> json) => MoodGoalExport(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: json['type'],
    targetValue: (json['targetValue'] as num).toDouble(),
    targetDays: json['targetDays'],
    createdDate: DateTime.parse(json['createdDate']),
    completedDate: json['completedDate'] != null
        ? DateTime.parse(json['completedDate'])
        : null,
    isCompleted: json['isCompleted'] ?? false,
  );
}

class NotificationSettingsExport {
  final Map<String, dynamic> settings;

  NotificationSettingsExport({required this.settings});

  Map<String, dynamic> toJson() => settings;

  factory NotificationSettingsExport.fromJson(Map<String, dynamic> json) =>
      NotificationSettingsExport(settings: json);
}

class ImportResult {
  final bool success;
  final int importedMoods;
  final int importedGoals;
  final int skippedMoods;
  final int skippedGoals;
  final String? error;

  ImportResult({
    required this.success,
    this.importedMoods = 0,
    this.importedGoals = 0,
    this.skippedMoods = 0,
    this.skippedGoals = 0,
    this.error,
  });
}

// FIXED: Added missing BackupResult class
class BackupResult {
  final bool success;
  final String? message;
  final String? error;

  BackupResult(this.success, {this.message, this.error});
}

class CorrelationEntryExport {
  final DateTime date;
  final String? weather;
  final double? temperature;
  final String? weatherDescription;
  final double? sleepQuality;
  final int? sleepDurationMinutes;
  final DateTime? bedtime;
  final DateTime? wakeTime;
  final String? exerciseLevel;
  final String? socialActivity;
  final int? workStress;
  final List<String> customTags;
  final String? notes;
  final bool autoWeather;
  final Map<String, dynamic>? weatherData;
  final String? hobbyActivity;

  CorrelationEntryExport({
    required this.date,
    this.weather,
    this.temperature,
    this.weatherDescription,
    this.sleepQuality,
    this.sleepDurationMinutes,
    this.bedtime,
    this.wakeTime,
    this.exerciseLevel,
    this.socialActivity,
    this.workStress,
    this.customTags = const [],
    this.notes,
    this.autoWeather = false,
    this.weatherData,
    this.hobbyActivity,
  });

  factory CorrelationEntryExport.fromCorrelationData(CorrelationData data) {
    return CorrelationEntryExport(
      date: data.date,
      weather: data.weather?.name,
      temperature: data.temperature,
      weatherDescription: data.weatherDescription,
      sleepQuality: data.sleepQuality,
      sleepDurationMinutes: data.sleepDuration?.inMinutes,
      bedtime: data.bedtime,
      wakeTime: data.wakeTime,
      exerciseLevel: data.exerciseLevel?.name,
      socialActivity: data.socialActivity?.name,
      workStress: data.workStress,
      customTags: data.customTags,
      notes: data.notes,
      autoWeather: data.autoWeather,
      weatherData: data.weatherData,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'weather': weather,
    'temperature': temperature,
    'weatherDescription': weatherDescription,
    'sleepQuality': sleepQuality,
    'sleepDurationMinutes': sleepDurationMinutes,
    'bedtime': bedtime?.toIso8601String(),
    'wakeTime': wakeTime?.toIso8601String(),
    'exerciseLevel': exerciseLevel,
    'socialActivity': socialActivity,
    'workStress': workStress,
    'customTags': customTags,
    'notes': notes,
    'autoWeather': autoWeather,
    'weatherData': weatherData,
    'hobbyActivity': hobbyActivity,
  };

  factory CorrelationEntryExport.fromJson(Map<String, dynamic> json) =>
      CorrelationEntryExport(
        date: DateTime.parse(json['date']),
        weather: json['weather'],
        temperature: json['temperature']?.toDouble(),
        weatherDescription: json['weatherDescription'],
        sleepQuality: json['sleepQuality']?.toDouble(),
        sleepDurationMinutes: json['sleepDurationMinutes'],
        bedtime:
        json['bedtime'] != null ? DateTime.parse(json['bedtime']) : null,
        wakeTime:
        json['wakeTime'] != null ? DateTime.parse(json['wakeTime']) : null,
        exerciseLevel: json['exerciseLevel'],
        socialActivity: json['socialActivity'],
        workStress: json['workStress'],
        customTags: List<String>.from(json['customTags'] ?? []),
        notes: json['notes'],
        autoWeather: json['autoWeather'] ?? false,
        weatherData: json['weatherData'],
        hobbyActivity: json['hobbyActivity'],
      );
}