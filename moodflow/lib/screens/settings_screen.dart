// Updated settings_screen.dart - Condensed with proper widget separation

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notifications/real_notification_service.dart'
    as real_notifications;
import '../services/backup/cloud_backup_service.dart';
import '../screens/backup_export_screen.dart';
import '../services/data/correlation_data_service.dart';
import '../widgets/weather_api_setup_dialog.dart';
import '../services/onboarding/onboarding_service.dart';
import '../widgets/notification_settings_widget.dart';
import '../services/notifications/real_notification_service.dart';
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
  bool _notificationsExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.themeMode;
    _customGradientEnabled = widget.useCustomGradient;
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
          // Appearance Section
          _AppearanceSection(
            themeMode: _selectedThemeMode,
            customGradientEnabled: _customGradientEnabled,
            onThemeChanged: _handleThemeChange,
            onGradientToggled: _handleGradientToggle,
          ),

          const SizedBox(height: 24),

          // Notifications Section
          NotificationSettingsWidget(
            isExpanded: _notificationsExpanded,
            onToggleExpanded: () {
              setState(() {
                _notificationsExpanded = !_notificationsExpanded;
              });
            },
          ),

          const SizedBox(height: 24),

          // Cloud Backup Section
          _CloudBackupSection(onShowSnackBar: _showSnackBar),

          const SizedBox(height: 24),

          // Weather Integration Section
          _WeatherIntegrationSection(onShowSnackBar: _showSnackBar),

          // Debug Section (only in debug mode)
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            _DebugSection(onShowSnackBar: _showSnackBar),
          ],
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  final ThemeMode themeMode;
  final bool customGradientEnabled;
  final ValueChanged<ThemeMode?> onThemeChanged;
  final ValueChanged<bool> onGradientToggled;

  const _AppearanceSection({
    required this.themeMode,
    required this.customGradientEnabled,
    required this.onThemeChanged,
    required this.onGradientToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Appearance'),
            const SizedBox(height: 12),

            // Theme selection
            ..._buildThemeOptions(context),

            const SizedBox(height: 8),

            // Custom gradient toggle
            SwitchListTile(
              title: const Text('Use custom mood gradient background'),
              value: customGradientEnabled,
              onChanged: onGradientToggled,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildThemeOptions(BuildContext context) {
    final options = [
      ('Light', ThemeMode.light),
      ('Dark', ThemeMode.dark),
      ('System Default', ThemeMode.system),
    ];

    return options.map((option) {
      final (title, mode) = option;
      return ListTile(
        title: Text(title),
        leading: _buildRadioButton(context, mode == themeMode),
        onTap: () => onThemeChanged(mode),
        contentPadding: EdgeInsets.zero,
      );
    }).toList();
  }

  Widget _buildRadioButton(BuildContext context, bool selected) {
    return GestureDetector(
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
        child: selected
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CloudBackupSection extends StatefulWidget {
  final Function(String, Color) onShowSnackBar;

  const _CloudBackupSection({required this.onShowSnackBar});

  @override
  State<_CloudBackupSection> createState() => _CloudBackupSectionState();
}

class _CloudBackupSectionState extends State<_CloudBackupSection> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Cloud Backup'),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: RealCloudBackupService.getBackupStatus(),
              builder: (context, snapshot) {
                final status = snapshot.data ?? {};
                final isAvailable = status['available'] ?? false;
                final isSignedIn = status['isSignedIn'] ?? false;
                final lastBackup = status['lastBackup'] as DateTime?;

                return Column(
                  children: [
                    // Automatic backup toggle (if available and signed in)
                    if (isAvailable && isSignedIn) ...[
                      SwitchListTile(
                        title: const Text('Automatic cloud backup'),
                        subtitle: const Text(
                            'Backup data immediately when you make changes'),
                        value: status['autoBackupEnabled'] ?? true,
                        onChanged: (value) async {
                          await RealCloudBackupService.setAutoBackupEnabled(
                              value);
                          setState(() {});
                          widget.onShowSnackBar(
                            value
                                ? 'Auto backup enabled'
                                : 'Auto backup disabled',
                            value ? Colors.green : Colors.orange,
                          );
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                    ],

                    // Cloud backup status
                    ListTile(
                      leading: Icon(
                        isAvailable && isSignedIn
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        color: isAvailable && isSignedIn
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: Text(
                        isAvailable && isSignedIn
                            ? 'Cloud backup active'
                            : isAvailable
                                ? 'Cloud backup not signed in'
                                : 'Cloud backup not available',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status['type'] ?? 'Unknown'),
                          if (lastBackup != null)
                            Text(
                                'Last backup: ${_formatLastBackupTime(lastBackup)}'),
                        ],
                      ),
                      trailing: isAvailable
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isSignedIn)
                                  ElevatedButton(
                                    onPressed: () async {
                                      final success =
                                          await RealCloudBackupService
                                              .signInToCloudService();
                                      if (success) {
                                        widget.onShowSnackBar(
                                            'Signed in successfully!',
                                            Colors.green);
                                        setState(() {});
                                      } else {
                                        widget.onShowSnackBar(
                                            'Sign in failed', Colors.red);
                                      }
                                    },
                                    child: const Text('Sign In'),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.backup),
                                    onPressed: () async {
                                      widget.onShowSnackBar(
                                          'Starting backup...', Colors.blue);
                                      final result =
                                          await RealCloudBackupService
                                              .performManualBackup();
                                      widget.onShowSnackBar(
                                        result.success
                                            ? 'Backup completed!'
                                            : 'Backup failed: ${result.error}',
                                        result.success
                                            ? Colors.green
                                            : Colors.red,
                                      );
                                    },
                                  ),
                              ],
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (isAvailable && isSignedIn) ...[
                      const Divider(),
                      ListTile(
                        title: const Text('Restore from backup'),
                        subtitle: const Text('Import data from cloud backup'),
                        leading: const Icon(Icons.cloud_download),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BackupExportScreen(initialTabIndex: 2),
                            ),
                          );
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _WeatherIntegrationSection extends StatefulWidget {
  final Function(String, Color) onShowSnackBar;

  const _WeatherIntegrationSection({required this.onShowSnackBar});

  @override
  State<_WeatherIntegrationSection> createState() =>
      _WeatherIntegrationSectionState();
}

class _WeatherIntegrationSectionState
    extends State<_WeatherIntegrationSection> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Weather Integration'),
            const SizedBox(height: 12),
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
                              onPressed: _testWeatherApi,
                            )
                          : null,
                      onTap: _configureWeatherApi,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (isConfigured) ...[
                      const Divider(),
                      ListTile(
                        title: const Text('View weather correlations'),
                        subtitle:
                            const Text('See how weather affects your mood'),
                        leading: const Icon(Icons.analytics),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pushNamed(context, '/correlation');
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        title: const Text('Remove weather API'),
                        subtitle:
                            const Text('Disable automatic weather tracking'),
                        leading: const Icon(Icons.delete, color: Colors.red),
                        onTap: _removeWeatherApi,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configureWeatherApi() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const WeatherApiSetupDialog(),
    );

    if (result == true) {
      setState(() {});
      widget.onShowSnackBar(
          'Weather API configured successfully!', Colors.green);
    }
  }

  Future<void> _testWeatherApi() async {
    widget.onShowSnackBar('Testing weather API...', Colors.blue);

    try {
      final weather = await CorrelationDataService.fetchWeatherForLocation(
        latitude: 40.7128,
        longitude: -74.0060,
      );

      if (weather != null) {
        widget.onShowSnackBar(
          'API test successful! Weather: ${weather.description}, ${weather.temperature.toStringAsFixed(1)}°C',
          Colors.green,
        );
      } else {
        widget.onShowSnackBar(
            'API test failed. Check your API key.', Colors.red);
      }
    } catch (e) {
      widget.onShowSnackBar('API test error: ${e.toString()}', Colors.red);
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
      setState(() {});
      widget.onShowSnackBar('Weather API configuration removed', Colors.orange);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _DebugSection extends StatelessWidget {
  final Function(String, Color) onShowSnackBar;

  const _DebugSection({required this.onShowSnackBar});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Debug & Testing'),
            const SizedBox(height: 12),

            // Onboarding controls
            _DebugListTile(
              icon: Icons.restart_alt,
              iconColor: Colors.purple,
              title: 'Reset Onboarding',
              subtitle: 'Reset onboarding flow for testing',
              onTap: () => _resetOnboarding(context),
            ),

            _DebugListTile(
              icon: Icons.play_arrow,
              iconColor: Colors.blue,
              title: 'Show Onboarding Now',
              subtitle: 'Trigger onboarding flow immediately',
              onTap: () => _showOnboarding(context),
            ),

            _DebugListTile(
              icon: Icons.bug_report,
              iconColor: Colors.purple,
              title: 'Debug Data',
              subtitle: 'Test data persistence and troubleshoot issues',
              onTap: () => _openDebugData(context),
              showChevron: true,
            ),

            const Divider(),

            // Notification tests
            _buildSubsectionHeader('Notification Tests', context),

            _DebugListTile(
              icon: Icons.wb_sunny,
              iconColor: Colors.orange,
              title: 'Test Morning Access',
              subtitle: 'Morning mood logging available notification',
              onTap: () => _sendMorningAccessNotification(context),
            ),

            _DebugListTile(
              icon: Icons.wb_sunny_outlined,
              iconColor: Colors.yellow,
              title: 'Test Midday Access',
              subtitle: 'Midday mood logging available notification',
              onTap: () => _sendMiddayAccessNotification(context),
            ),

            _DebugListTile(
              icon: Icons.nightlight_round,
              iconColor: Colors.indigo,
              title: 'Test Evening Access',
              subtitle: 'Evening mood logging available notification',
              onTap: () => _sendEveningAccessNotification(context),
            ),

            const Divider(),

            _buildSubsectionHeader('End of Day Notifications', context),

            _DebugListTile(
              icon: Icons.bedtime,
              iconColor: Colors.purple,
              title: 'Test End of Day Reminder',
              subtitle: 'Missing mood log reminder',
              onTap: () => _sendEndOfDayReminderNotification(context),
            ),

            _DebugListTile(
              icon: Icons.celebration,
              iconColor: Colors.green,
              title: 'Test Day Complete',
              subtitle: 'Perfect day celebration',
              onTap: () => _sendDayCompleteNotification(context),
            ),

            _DebugListTile(
              icon: Icons.timer,
              iconColor: Colors.green,
              title: 'Test 10-Second Notification',
              subtitle: 'Schedule a notification for 10 seconds from now',
              onTap: () => _testImmediateNotification(context),
            ),
            _DebugListTile(
              icon: Icons.schedule,
              iconColor: Colors.blue,
              title: 'View Scheduled Notifications',
              subtitle: 'See all pending system notifications',
              onTap: () => _showScheduledNotifications(context),
              showChevron: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScheduledNotifications(BuildContext context) async {
    final pendingNotifications = await RealNotificationService.getPendingNotifications();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => _ScheduledNotificationsDialog(
        notifications: pendingNotifications,
      ),
    );
  }
  
  // Debug action methods
  Future<void> _resetOnboarding(BuildContext context) async {
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
      if (context.mounted) {
        onShowSnackBar(
            'Onboarding reset! Restart the app to see it again.', Colors.green);
      }
    }
  }

  Future<void> _showOnboarding(BuildContext context) async {
    await OnboardingService.showOnboardingFlow(context);
  }

  void _openDebugData(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DebugDataScreen()),
    );
  }

  // Notification test methods
  Future<void> _testImmediateNotification(BuildContext context) async {
    await real_notifications.RealNotificationService.scheduleTestNotificationIn(
        10, 'This test notification was scheduled 10 seconds ago!');
    onShowSnackBar('📱 Test notification scheduled for 10 seconds from now!',
        Colors.green);
  }

  Future<void> _sendMorningAccessNotification(BuildContext context) async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8001,
      title: 'Good morning! ☀️',
      body: 'Morning mood logging is now available. How are you feeling?',
      payload: jsonEncode(
          {'type': 'access_reminder', 'segment': 0, 'timeSegment': 'morning'}),
    );
    onShowSnackBar('📱 Morning access notification sent!', Colors.green);
  }

  Future<void> _sendMiddayAccessNotification(BuildContext context) async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8002,
      title: 'Midday check-in ⚡',
      body: 'Midday mood logging is now available. Take a moment to check in.',
      payload: jsonEncode(
          {'type': 'access_reminder', 'segment': 1, 'timeSegment': 'midday'}),
    );
    onShowSnackBar('📱 Midday access notification sent!', Colors.green);
  }

  Future<void> _sendEveningAccessNotification(BuildContext context) async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8003,
      title: 'Evening reflection 🌙',
      body: 'Evening mood logging is now available. How has your evening been?',
      payload: jsonEncode(
          {'type': 'access_reminder', 'segment': 2, 'timeSegment': 'evening'}),
    );
    onShowSnackBar('📱 Evening access notification sent!', Colors.green);
  }

  Future<void> _sendEndOfDayReminderNotification(BuildContext context) async {
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
    onShowSnackBar('📱 End of day reminder sent!', Colors.green);
  }

  Future<void> _sendDayCompleteNotification(BuildContext context) async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8005,
      title: 'Perfect day of mood tracking! 🎉',
      body: 'You logged all your moods today. Great job staying mindful!',
      payload: jsonEncode({'type': 'end_of_day', 'segmentsLogged': 3}),
    );
    onShowSnackBar('📱 Day complete celebration sent!', Colors.green);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSubsectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class _DebugListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  const _DebugListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: showChevron ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _ScheduledNotificationsDialog extends StatelessWidget {
  final List<PendingNotificationRequest> notifications;

  const _ScheduledNotificationsDialog({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scheduled Notifications'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: notifications.isEmpty
            ? const Center(
          child: Text('No scheduled notifications'),
        )
            : ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ID: ${notification.id}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (notification.payload != null)
                          Icon(Icons.data_object, size: 16, color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.title ?? 'No title',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body ?? 'No body',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (notification.payload != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Payload: ${notification.payload}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
