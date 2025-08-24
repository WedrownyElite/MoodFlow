// Updated settings_screen.dart - Fixed RadioListTile deprecation warnings

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/notifications/enhanced_notification_service.dart' as notifications;
import '../services/notifications/real_notification_service.dart' as real_notifications;
import '../services/backup/cloud_backup_service.dart';
import '../screens/backup_export_screen.dart';
import '../services/data/correlation_data_service.dart';
import '../widgets/weather_api_setup_dialog.dart';
import '../services/onboarding/onboarding_service.dart';
import 'debug_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final bool useCustomGradient;
  final ValueChanged<ThemeMode?> onThemeModeChanged;
  final ValueChanged<bool> onUseCustomGradientChanged;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.useCustomGradient,
    required this.onThemeModeChanged,
    required this.onUseCustomGradientChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _selectedThemeMode;
  late bool _customGradientEnabled;
  notifications.NotificationSettings? _notificationSettings;
  bool _isLoadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.themeMode;
    _customGradientEnabled = widget.useCustomGradient;
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final settings = await notifications.EnhancedNotificationService.loadSettings();
    setState(() {
      _notificationSettings = settings;
      _isLoadingNotifications = false;
    });
  }

  Future<void> _updateNotificationSettings(notifications.NotificationSettings settings) async {
    await notifications.EnhancedNotificationService.saveSettings(settings);
    setState(() {
      _notificationSettings = settings;
    });
  }

  void _handleThemeChange(ThemeMode? mode) {
    if (mode != null) {
      setState(() {
        _selectedThemeMode = mode;
      });
      widget.onThemeModeChanged(mode);
    }
  }

  void _handleGradientToggle(bool value) {
    setState(() {
      _customGradientEnabled = value;
    });
    widget.onUseCustomGradientChanged(value);
  }

  Future<void> _selectEndOfDayTime(notifications.NotificationSettings settings) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.endOfDayTime.hour, minute: settings.endOfDayTime.minute),
      helpText: 'Select end-of-day reminder time',
    );

    if (picked != null) {
      final newTime = notifications.TimeOfDay(hour: picked.hour, minute: picked.minute);
      _updateNotificationSettings(settings.copyWith(endOfDayTime: newTime));
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Settings
          _buildSectionHeader('Appearance'),
          // Manual radio group implementation to avoid deprecation warnings
          Column(
            children: [
              ListTile(
                title: const Text('Light'),
                leading: GestureDetector(
                  onTap: () => _handleThemeChange(ThemeMode.light),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: _selectedThemeMode == ThemeMode.light
                        ? Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    )
                        : null,
                  ),
                ),
                onTap: () => _handleThemeChange(ThemeMode.light),
              ),
              ListTile(
                title: const Text('Dark'),
                leading: GestureDetector(
                  onTap: () => _handleThemeChange(ThemeMode.dark),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: _selectedThemeMode == ThemeMode.dark
                        ? Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    )
                        : null,
                  ),
                ),
                onTap: () => _handleThemeChange(ThemeMode.dark),
              ),
              ListTile(
                title: const Text('System Default'),
                leading: GestureDetector(
                  onTap: () => _handleThemeChange(ThemeMode.system),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: _selectedThemeMode == ThemeMode.system
                        ? Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    )
                        : null,
                  ),
                ),
                onTap: () => _handleThemeChange(ThemeMode.system),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Use custom mood gradient background'),
            value: _customGradientEnabled,
            onChanged: _handleGradientToggle,
          ),

          const Divider(height: 40),

          _buildSectionHeader('Automatic Cloud Backup'),
          FutureBuilder<Map<String, dynamic>>(
            future: RealCloudBackupService.getBackupStatus(),
            builder: (context, snapshot) {
              final status = snapshot.data ?? {};
              final isAvailable = status['available'] ?? false;
              final isEnabled = status['isSignedIn'] ?? false;

              return Column(
                children: [
                  if (isAvailable && isEnabled) ...[
                    SwitchListTile(
                      title: const Text('Automatic cloud backup'),
                      subtitle: const Text('Backup data immediately when you make changes'),
                      value: status['autoBackupEnabled'] ?? true,
                      onChanged: (value) async {
                        await RealCloudBackupService.setAutoBackupEnabled(value);
                        setState(() {});
                        _showSnackBar(
                          value ? 'Auto backup enabled' : 'Auto backup disabled',
                          value ? Colors.green : Colors.orange,
                        );
                      },
                    ),
                  ] else if (isAvailable && !isEnabled) ...[
                    ListTile(
                      title: const Text('Sign in for automatic backup'),
                      subtitle: const Text('Sign in to enable automatic cloud backup'),
                      leading: const Icon(Icons.cloud_off),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final success = await RealCloudBackupService.signInToCloudService();
                          if (success) {
                            _showSnackBar('Signed in successfully!', Colors.green);
                            setState(() {});
                          } else {
                            _showSnackBar('Sign in failed', Colors.red);
                          }
                        },
                        child: const Text('Sign In'),
                      ),
                    ),
                  ] else ...[
                    const ListTile(
                      title: Text('Cloud backup not available'),
                      subtitle: Text('Your device doesn\'t support cloud backup'),
                      leading: Icon(Icons.info_outline, color: Colors.grey),
                    ),
                  ],
                ],
              );
            },
          ),

          _buildSectionHeader('Cloud Backup'),
          FutureBuilder<Map<String, dynamic>>(
            future: RealCloudBackupService.getBackupStatus(),
            builder: (context, snapshot) {
              final status = snapshot.data ?? {};
              final isAvailable = status['available'] ?? false;
              final isSignedIn = status['isSignedIn'] ?? false;
              final lastBackup = status['lastBackup'] as DateTime?;

              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isAvailable && isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                      color: isAvailable && isSignedIn ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      isAvailable && isSignedIn
                          ? 'Cloud backup active'
                          : 'Cloud backup not available',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(status['type'] ?? 'Unknown'),
                        if (lastBackup != null)
                          Text('Last backup: ${_formatLastBackupTime(lastBackup)}'),
                      ],
                    ),
                    trailing: isAvailable
                        ? IconButton(
                      icon: const Icon(Icons.backup),
                      onPressed: () async {
                        _showSnackBar('Starting backup...', Colors.blue);
                        final result = await RealCloudBackupService.performManualBackup();
                        _showSnackBar(
                          result.success
                              ? 'Backup completed!'
                              : 'Backup failed: ${result.error}',
                          result.success ? Colors.green : Colors.red,
                        );
                      },
                    )
                        : null,
                  ),

                  if (isAvailable) ...[
                    ListTile(
                      title: const Text('Restore from backup'),
                      subtitle: const Text('Import data from cloud backup'),
                      leading: const Icon(Icons.cloud_download),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BackupExportScreen(initialTabIndex: 2), // Restore tab
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),

          _buildSectionHeader('Weather Integration'),
          FutureBuilder<bool>(
            future: CorrelationDataService.isWeatherApiConfigured(),
            builder: (context, snapshot) {
              final isConfigured = snapshot.data ?? false;

              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isConfigured ? Icons.wb_sunny : Icons.wb_sunny_outlined,
                      color: isConfigured ? Colors.orange : Colors.grey,
                    ),
                    title: Text(
                      isConfigured
                          ? 'Weather API configured'
                          : 'Weather API not configured',
                    ),
                    subtitle: Text(
                      isConfigured
                          ? 'Automatic weather tracking enabled'
                          : 'Set up OpenWeatherMap API for mood correlations',
                    ),
                    trailing: isConfigured
                        ? IconButton(
                      icon: const Icon(Icons.science),
                      onPressed: () => _testWeatherApi(),
                    )
                        : null,
                    onTap: () => _configureWeatherApi(),
                  ),

                  if (isConfigured) ...[
                    ListTile(
                      title: const Text('View weather correlations'),
                      subtitle: const Text('See how weather affects your mood'),
                      leading: const Icon(Icons.analytics),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(context, '/correlation');
                      },
                    ),

                    ListTile(
                      title: const Text('Remove weather API'),
                      subtitle: const Text('Disable automatic weather tracking'),
                      leading: const Icon(Icons.delete, color: Colors.red),
                      onTap: () => _removeWeatherApi(),
                    ),
                  ],
                ],
              );
            },
          ),

          const Divider(height: 40),

          // Notification Settings
          _buildSectionHeader('Notifications'),
          if (_isLoadingNotifications)
            const Center(child: CircularProgressIndicator())
          else
            _buildNotificationSettings(),

          // Debug Section (only in debug mode)
          if (kDebugMode) ...[
            const Divider(height: 40),
            _buildSectionHeader('Debug & Testing'),
            
            ListTile(
              title: const Text('Reset Onboarding'),
              subtitle: const Text('Reset onboarding flow for testing'),
              leading: const Icon(Icons.restart_alt, color: Colors.purple),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Onboarding'),
                    content: const Text(
                      'This will reset the onboarding flow so it shows again on next app launch. '
                          'This is for testing purposes only.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await OnboardingService.resetOnboarding();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Onboarding reset! Restart the app to see it again.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),

            ListTile(
              title: const Text('Show Onboarding Now'),
              subtitle: const Text('Trigger onboarding flow immediately'),
              leading: const Icon(Icons.play_arrow, color: Colors.blue),
              onTap: () async {
                await OnboardingService.showOnboardingFlow(context);
              },
            ),
              
            ListTile(
              title: const Text('Debug Data'),
              subtitle: const Text('Test data persistence and troubleshoot issues'),
              leading: const Icon(Icons.bug_report, color: Colors.purple),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DebugDataScreen()),
                );
              },
            ),

            // Keep existing debug notification tests...
            _buildSubsectionHeader('Notification Tests'),
            ListTile(
              title: const Text('Test Morning Access'),
              subtitle: const Text('Morning mood logging available notification'),
              leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              onTap: () => _sendMorningAccessNotification(),
            ),
            ListTile(
              title: const Text('Test Midday Access'),
              subtitle: const Text('Midday mood logging available notification'),
              leading: const Icon(Icons.wb_sunny_outlined, color: Colors.yellow),
              onTap: () => _sendMiddayAccessNotification(),
            ),
            ListTile(
              title: const Text('Test Evening Access'),
              subtitle: const Text('Evening mood logging available notification'),
              leading: const Icon(Icons.nightlight_round, color: Colors.indigo),
              onTap: () => _sendEveningAccessNotification(),
            ),

            const SizedBox(height: 16),
            _buildSubsectionHeader('End of Day Notifications'),
            ListTile(
              title: const Text('Test End of Day Reminder'),
              subtitle: const Text('Missing mood log reminder'),
              leading: const Icon(Icons.bedtime, color: Colors.purple),
              onTap: () => _sendEndOfDayReminderNotification(),
            ),
            ListTile(
              title: const Text('Test Day Complete'),
              subtitle: const Text('Perfect day celebration'),
              leading: const Icon(Icons.celebration, color: Colors.green),
              onTap: () => _sendDayCompleteNotification(),
            ),
            ListTile(
              title: const Text('Test 10-Second Notification'),
              subtitle: const Text('Schedule a notification for 10 seconds from now'),
              leading: const Icon(Icons.timer, color: Colors.green),
              onTap: () => _testImmediateNotification(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatLastBackupTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubsectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    final settings = _notificationSettings!;

    return Column(
      children: [
        // Master notification toggle
        SwitchListTile(
          title: const Text('Enable notifications'),
          subtitle: const Text('Receive reminders and updates'),
          value: settings.enabled,
          onChanged: (value) {
            _updateNotificationSettings(settings.copyWith(enabled: value));
          },
        ),

        if (settings.enabled) ...[
          const Divider(),

          // Access Reminders Section
          _buildSubsectionHeader('Mood Log Access'),
          SwitchListTile(
            title: const Text('Access reminders'),
            subtitle: const Text('When new mood logging becomes available'),
            value: settings.accessReminders,
            onChanged: (value) {
              _updateNotificationSettings(settings.copyWith(accessReminders: value));
            },
          ),

          if (settings.accessReminders) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Morning (${settings.morningTime})'),
                    subtitle: const Text('When morning mood logging becomes available'),
                    value: settings.morningAccessReminder,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(morningAccessReminder: value));
                    },
                  ),
                  if (settings.morningAccessReminder)
                    ListTile(
                      title: const Text('Morning time'),
                      subtitle: Text(settings.morningTime.toString()),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectMorningTime(settings),
                    ),
                  SwitchListTile(
                    title: Text('Midday (${settings.middayTime})'),
                    subtitle: const Text('When midday mood logging becomes available'),
                    value: settings.middayAccessReminder,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(middayAccessReminder: value));
                    },
                  ),
                  if (settings.middayAccessReminder)
                    ListTile(
                      title: const Text('Midday time'),
                      subtitle: Text(settings.middayTime.toString()),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectMiddayTime(settings),
                    ),
                  SwitchListTile(
                    title: Text('Evening (${settings.eveningTime})'),
                    subtitle: const Text('When evening mood logging becomes available'),
                    value: settings.eveningAccessReminder,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(eveningAccessReminder: value));
                    },
                  ),
                  if (settings.eveningAccessReminder)
                    ListTile(
                      title: const Text('Evening time'),
                      subtitle: Text(settings.eveningTime.toString()),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectEveningTime(settings),
                    ),
                ],
              ),
            ),
          ],

          const Divider(),

          // End of Day Reminders
          _buildSubsectionHeader('End of Day'),
          SwitchListTile(
            title: const Text('End-of-day reminder'),
            subtitle: Text('Remind me at ${settings.endOfDayTime} if I haven\'t logged moods'),
            value: settings.endOfDayReminder,
            onChanged: (value) {
              _updateNotificationSettings(settings.copyWith(endOfDayReminder: value));
            },
          ),

          if (settings.endOfDayReminder)
            ListTile(
              title: const Text('Reminder time'),
              subtitle: Text(settings.endOfDayTime.toString()),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectEndOfDayTime(settings),
            ),

          const Divider(),

          // Goal Reminders
          _buildSubsectionHeader('Goals'),
          SwitchListTile(
            title: const Text('Goal reminders'),
            subtitle: const Text('Updates about your mood goals'),
            value: settings.goalReminders,
            onChanged: (value) {
              _updateNotificationSettings(settings.copyWith(goalReminders: value));
            },
          ),

          if (settings.goalReminders) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Progress updates'),
                    subtitle: const Text('Regular updates on goal progress'),
                    value: settings.goalProgress,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(goalProgress: value));
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Encouragement'),
                    subtitle: const Text('Motivational messages for your goals'),
                    value: settings.goalEncouragement,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(goalEncouragement: value));
                    },
                  ),
                ],
              ),
            ),
          ],

          const Divider(),

          // Celebrations
          _buildSubsectionHeader('Celebrations'),
          SwitchListTile(
            title: const Text('Streak celebrations'),
            subtitle: const Text('Celebrate when you maintain logging streaks'),
            value: settings.streakCelebrations,
            onChanged: (value) {
              _updateNotificationSettings(settings.copyWith(streakCelebrations: value));
            },
          ),
        ],
      ],
    );
  }

  // Keep all the existing notification test methods...
  Future<void> _testImmediateNotification() async {
    await real_notifications.RealNotificationService.scheduleTestNotificationIn(
        10, 'This test notification was scheduled 10 seconds ago!');

    if (mounted) {
      _showSnackBar('📱 Test notification scheduled for 10 seconds from now!', Colors.green);
    }
  }

  Future<void> _sendMorningAccessNotification() async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8001,
      title: 'Good morning! ☀️',
      body: 'Morning mood logging is now available. How are you feeling?',
      payload: jsonEncode({
        'type': 'access_reminder',
        'segment': 0,
        'timeSegment': 'morning'
      }),
    );
    _showNotificationSentMessage('Morning access notification');
  }

  Future<void> _sendMiddayAccessNotification() async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8002,
      title: 'Midday check-in ⚡',
      body: 'Midday mood logging is now available. Take a moment to check in.',
      payload: jsonEncode({
        'type': 'access_reminder',
        'segment': 1,
        'timeSegment': 'midday'
      }),
    );
    _showNotificationSentMessage('Midday access notification');
  }

  Future<void> _sendEveningAccessNotification() async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8003,
      title: 'Evening reflection 🌙',
      body: 'Evening mood logging is now available. How has your evening been?',
      payload: jsonEncode({
        'type': 'access_reminder',
        'segment': 2,
        'timeSegment': 'evening'
      }),
    );
    _showNotificationSentMessage('Evening access notification');
  }

  Future<void> _sendEndOfDayReminderNotification() async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8004,
      title: 'Don\'t forget to complete your mood log! 📝',
      body: 'You\'re missing some mood entries. Quick check-in before bed?',
      payload: jsonEncode({
        'type': 'end_of_day',
        'missingSegments': ['Evening'],
        'loggedSegments': 2
      }),
    );
    _showNotificationSentMessage('End of day reminder');
  }

  Future<void> _sendDayCompleteNotification() async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8005,
      title: 'Perfect day of mood tracking! 🎉',
      body: 'You logged all your moods today. Great job staying mindful!',
      payload: jsonEncode({
        'type': 'end_of_day',
        'segmentsLogged': 3
      }),
    );
    _showNotificationSentMessage('Day complete celebration');
  }

  // Keep all the existing time picker methods...
  Future<void> _selectMorningTime(notifications.NotificationSettings settings) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.morningTime.hour, minute: settings.morningTime.minute),
      helpText: 'Select morning reminder time',
    );

    if (picked != null) {
      final newTime = notifications.TimeOfDay(hour: picked.hour, minute: picked.minute);
      _updateNotificationSettings(settings.copyWith(morningTime: newTime));
    }
  }

  Future<void> _selectMiddayTime(notifications.NotificationSettings settings) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.middayTime.hour, minute: settings.middayTime.minute),
      helpText: 'Select midday reminder time',
    );

    if (picked != null) {
      final newTime = notifications.TimeOfDay(hour: picked.hour, minute: picked.minute);
      _updateNotificationSettings(settings.copyWith(middayTime: newTime));
    }
  }

  Future<void> _selectEveningTime(notifications.NotificationSettings settings) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.eveningTime.hour, minute: settings.eveningTime.minute),
      helpText: 'Select evening reminder time',
    );

    if (picked != null) {
      final newTime = notifications.TimeOfDay(hour: picked.hour, minute: picked.minute);
      _updateNotificationSettings(settings.copyWith(eveningTime: newTime));
    }
  }

  Future<void> _configureWeatherApi() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const WeatherApiSetupDialog(),
    );

    if (result == true) {
      setState(() {}); // Refresh the UI
      _showSnackBar('Weather API configured successfully!', Colors.green);
    }
  }

  Future<void> _testWeatherApi() async {
    _showSnackBar('Testing weather API...', Colors.blue);

    try {
      // Test with New York coordinates
      final weather = await CorrelationDataService.fetchWeatherForLocation(
        latitude: 40.7128,
        longitude: -74.0060,
      );

      if (weather != null) {
        _showSnackBar(
          'API test successful! Weather: ${weather.description}, ${weather.temperature.toStringAsFixed(1)}°C',
          Colors.green,
        );
      } else {
        _showSnackBar('API test failed. Check your API key.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('API test error: ${e.toString()}', Colors.red);
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
      setState(() {}); // Refresh the UI
      _showSnackBar('Weather API configuration removed', Colors.orange);
    }
  }

  void _showNotificationSentMessage(String notificationType) {
    _showSnackBar('📱 $notificationType sent! Tap to test navigation.', Colors.green);
  }
}