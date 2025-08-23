import 'package:shared_preferences/shared_preferences.dart';
import '../data/backup_models.dart';
import '../data/mood_data_service.dart';
import '../data/mood_analytics_service.dart';
import '../notifications/enhanced_notification_service.dart';
import '../utils/logger.dart';

class BackupService {
  static const String _lastBackupKey = 'last_backup_date';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';

  // Export all data to a single JSON structure
  static Future<MoodDataExport> exportAllData() async {
    final moodEntries = <MoodEntryExport>[];
    final goals = <MoodGoalExport>[];

    // Collect all mood entries from the last 3 years
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 1095));

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        if (moodData != null && moodData['rating'] != null) {
          moodEntries.add(MoodEntryExport(
            date: currentDate,
            segment: segment,
            rating: (moodData['rating'] as num).toDouble(),
            note: moodData['note'] as String? ?? '',
            loggedAt: moodData['timestamp'] != null
                ? DateTime.parse(moodData['timestamp'])
                : currentDate,
            lastModified: moodData['lastModified'] != null
                ? DateTime.parse(moodData['lastModified'])
                : null,
          ));
        }
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Collect goals
    final goalsList = await MoodAnalyticsService.loadGoals();
    for (final goal in goalsList) {
      goals.add(MoodGoalExport(
        id: goal.id,
        title: goal.title,
        description: goal.description,
        type: goal.type.toString(),
        targetValue: goal.targetValue,
        targetDays: goal.targetDays,
        createdDate: goal.createdDate,
        completedDate: goal.completedDate,
        isCompleted: goal.isCompleted,
      ));
    }

    // Get notification settings
    final notificationSettings = await EnhancedNotificationService.loadSettings();
    final notificationExport = NotificationSettingsExport(
      settings: notificationSettings.toJson(),
    );

    // Get user preferences
    final prefs = await SharedPreferences.getInstance();
    final userPreferences = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value != null) {
        userPreferences[key] = value;
      }
    }

    return MoodDataExport(
      appVersion: '1.0.0', // Replace with actual app version
      exportDate: DateTime.now(),
      moodEntries: moodEntries,
      goals: goals,
      notificationSettings: notificationExport,
      userPreferences: userPreferences,
    );
  }

  // Import data from JSON structure
  static Future<ImportResult> importData(MoodDataExport exportData) async {
    try {
      int importedMoods = 0;
      int importedGoals = 0;
      int skippedMoods = 0;
      int skippedGoals = 0;

      // Import mood entries
      for (final entry in exportData.moodEntries) {
        // Check if entry already exists
        final existing = await MoodDataService.loadMood(entry.date, entry.segment);
        if (existing != null && existing['rating'] != null) {
          skippedMoods++;
          continue;
        }

        await MoodDataService.saveMood(
          entry.date,
          entry.segment,
          entry.rating,
          entry.note,
        );
        importedMoods++;
      }

      // Import goals
      final existingGoals = await MoodAnalyticsService.loadGoals();
      final existingGoalIds = existingGoals.map((g) => g.id).toSet();

      for (final goalExport in exportData.goals) {
        if (existingGoalIds.contains(goalExport.id)) {
          skippedGoals++;
          continue;
        }

        final goalType = GoalType.values.firstWhere(
              (type) => type.toString() == goalExport.type,
          orElse: () => GoalType.averageMood,
        );

        final goal = MoodGoal(
          id: goalExport.id,
          title: goalExport.title,
          description: goalExport.description,
          type: goalType,
          targetValue: goalExport.targetValue,
          targetDays: goalExport.targetDays,
          createdDate: goalExport.createdDate,
          completedDate: goalExport.completedDate,
          isCompleted: goalExport.isCompleted,
        );

        existingGoals.add(goal);
        importedGoals++;
      }

      if (importedGoals > 0) {
        await MoodAnalyticsService.saveGoals(existingGoals);
      }

      // Import notification settings (optional)
      try {
        final importedSettings = NotificationSettings.fromJson(
            exportData.notificationSettings.settings
        );
        await EnhancedNotificationService.saveSettings(importedSettings);
      } catch (e) {
        Logger.backupService('Failed to import notification settings: $e');
      }

      return ImportResult(
        success: true,
        importedMoods: importedMoods,
        importedGoals: importedGoals,
        skippedMoods: skippedMoods,
        skippedGoals: skippedGoals,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get last backup date
  static Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastBackupKey);
    if (dateString != null) {
      return DateTime.parse(dateString);
    }
    return null;
  }

  /// Set last backup date
  static Future<void> setLastBackupDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, date.toIso8601String());
  }

  /// Check if auto backup is enabled
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }

  /// Set auto backup enabled/disabled
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }
}