import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../backup/cloud_backup_service.dart';
import '../notifications/enhanced_notification_service.dart';
import '../data/correlation_data_service.dart';
import '../utils/logger.dart';

class OnboardingService {
  static const String _onboardingCompleteKey = 'onboarding_completed';
  static const String _cloudBackupPromptKey = 'cloud_backup_prompted';
  static const String _notificationPromptKey = 'notification_prompted';
  static const String _correlationPromptKey = 'correlation_prompted';

  /// Check if user needs to see onboarding
  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool(_onboardingCompleteKey) ?? false;

    // Also check if user has any existing mood data
    final hasExistingData = await _hasExistingMoodData();

    return !hasCompletedOnboarding && !hasExistingData;
  }

  /// Check if user has existing mood data
  static Future<bool> _hasExistingMoodData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    return allKeys.any((key) => key.startsWith('mood_'));
  }

  /// Mark onboarding as completed
  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    Logger.dataService('✅ Onboarding marked as completed');
  }

  /// Show the full onboarding flow
  static Future<void> showOnboardingFlow(BuildContext context) async {
    if (!context.mounted) return;

    // Step 1: Cloud Backup Setup
    await _showCloudBackupPrompt(context);

    if (!context.mounted) return;

    // Step 2: Notification Setup
    await _showNotificationPrompt(context);

    if (!context.mounted) return;

    // Step 3: Correlation Services Setup
    await _showCorrelationPrompt(context);

    // Mark onboarding as completed
    await markOnboardingCompleted();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Welcome to MoodFlow! You\'re all set up.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Step 1: Cloud Backup Prompt
  static Future<void> _showCloudBackupPrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool(_cloudBackupPromptKey) ?? false;

    if (hasPrompted) return;

    final isAvailable = await RealCloudBackupService.isCloudBackupAvailable();
    if (!isAvailable) {
      await prefs.setBool(_cloudBackupPromptKey, true);
      return;
    }

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CloudBackupPromptDialog(),
    );

    await prefs.setBool(_cloudBackupPromptKey, true);

    if (result == true) {
      // User wants cloud backup
      final signedIn = await RealCloudBackupService.signInToCloudService();

      if (signedIn) {
        await RealCloudBackupService.setAutoBackupEnabled(true);
        Logger.cloudService('✅ Cloud backup enabled during onboarding');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '☁️ Cloud backup enabled! Your data will be automatically backed up.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        Logger.cloudService('❌ Cloud backup sign-in failed during onboarding');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Cloud backup setup failed. You can try again in Settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      // User declined cloud backup
      await RealCloudBackupService.setAutoBackupEnabled(false);
      Logger.cloudService('ℹ️ User declined cloud backup during onboarding');
    }
  }

  /// Step 2: Notification Prompt
  static Future<void> _showNotificationPrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool(_notificationPromptKey) ?? false;

    if (hasPrompted) return;

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NotificationPromptDialog(),
    );

    await prefs.setBool(_notificationPromptKey, true);

    if (result == true) {
      // User wants notifications
      await EnhancedNotificationService.markPermissionAsked();
      final granted = await EnhancedNotificationService.requestPermissions();

      if (granted) {
        final settings = NotificationSettings.defaultSettings();
        await EnhancedNotificationService.saveSettings(settings);
        Logger.notificationService('✅ Notifications enabled during onboarding');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '🔔 Notifications enabled! You\'ll get helpful reminders.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      // User declined notifications
      await EnhancedNotificationService.markPermissionAsked();
      final settings =
          NotificationSettings.defaultSettings().copyWith(enabled: false);
      await EnhancedNotificationService.saveSettings(settings);
      Logger.notificationService(
          'ℹ️ User declined notifications during onboarding');
    }
  }

  /// Step 3: Correlation Services Prompt
  static Future<void> _showCorrelationPrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool(_correlationPromptKey) ?? false;

    if (hasPrompted) return;

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CorrelationPromptDialog(),
    );

    await prefs.setBool(_correlationPromptKey, true);

    if (result == true) {
      // User wants correlation services
      final position = await CorrelationDataService.getCurrentLocation();

      if (position != null) {
        // Location permission granted, now prompt for weather API
        if (context.mounted) {
          final weatherSetup = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.wb_sunny, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Weather Integration'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'To enable weather-mood correlations, you\'ll need a free OpenWeatherMap API key.'),
                  SizedBox(height: 12),
                  Text('You can set this up now or later in Settings.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Set up now'),
                ),
              ],
            ),
          );

          if (weatherSetup == true) {
            // Import your weather setup dialog
            // final weatherResult = await showDialog<bool>(
            //   context: context,
            //   builder: (context) => const WeatherApiSetupDialog(),
            // );
          }
        }

        Logger.correlationService(
            '✅ Location permission granted during onboarding');
      } else {
        Logger.correlationService(
            '❌ Location permission denied during onboarding');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission is needed for weather correlations. You can enable this in Settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      Logger.correlationService(
          'ℹ️ User declined correlation services during onboarding');
    }
  }

  /// Reset onboarding (for testing)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompleteKey);
    await prefs.remove(_cloudBackupPromptKey);
    await prefs.remove(_notificationPromptKey);
    await prefs.remove(_correlationPromptKey);
    Logger.dataService('🔄 Onboarding reset for testing');
  }
}

/// Dialog for cloud backup prompt
class CloudBackupPromptDialog extends StatelessWidget {
  const CloudBackupPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cloud_upload,
              color: Theme.of(context).primaryColor, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('Secure Your Data')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep your mood tracking data safe with automatic cloud backup.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildFeature(Icons.backup, 'Automatic backups',
              'Your data is saved to your Google Drive or iCloud'),
          const SizedBox(height: 8),
          _buildFeature(Icons.sync, 'Sync across devices',
              'Access your data on multiple devices'),
          const SizedBox(height: 8),
          _buildFeature(Icons.security, 'Secure & private',
              'Only you can access your data'),
          const SizedBox(height: 16),
          Text(
            'You can change this setting anytime in the app.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip for now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Enable backup'),
        ),
      ],
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog for notification prompt
class NotificationPromptDialog extends StatelessWidget {
  const NotificationPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.notifications_active,
              color: Theme.of(context).primaryColor, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('Stay Consistent')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get gentle reminders to help build a consistent mood tracking habit.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildFeature(Icons.access_time, 'Timely reminders',
              'Morning, midday, and evening check-ins'),
          const SizedBox(height: 8),
          _buildFeature(Icons.bedtime, 'End-of-day prompts',
              'Gentle reminders before bed'),
          const SizedBox(height: 8),
          _buildFeature(Icons.local_fire_department, 'Celebrate streaks',
              'Acknowledge your consistency'),
          const SizedBox(height: 16),
          Text(
            'You can customize or disable notifications anytime.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No thanks'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Enable reminders'),
        ),
      ],
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog for correlation services prompt
class CorrelationPromptDialog extends StatelessWidget {
  const CorrelationPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.analytics,
              color: Theme.of(context).primaryColor, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('Discover Patterns')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Let MoodFlow analyze how weather, sleep, and activities affect your mood.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildFeature(Icons.wb_sunny, 'Weather correlations',
              'See how weather impacts your mood'),
          const SizedBox(height: 8),
          _buildFeature(Icons.insights, 'Smart insights',
              'Get personalized recommendations'),
          const SizedBox(height: 8),
          _buildFeature(Icons.location_on, 'Location required',
              'Used only for weather data'),
          const SizedBox(height: 16),
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
                    'Your location is only used to get weather data and is never shared.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Enable insights'),
        ),
      ],
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
