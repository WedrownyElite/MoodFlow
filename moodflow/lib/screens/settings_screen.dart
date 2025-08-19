import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/data/enhanced_notification_service.dart' as notifications;
import '../services/real_notification_service.dart' as real_notifications;
import '../services/notification_manager.dart';
import '../screens/backup_export_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Settings
          _buildSectionHeader('Appearance'),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: _selectedThemeMode,
            onChanged: _handleThemeChange,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: _selectedThemeMode,
            onChanged: _handleThemeChange,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            value: ThemeMode.system,
            groupValue: _selectedThemeMode,
            onChanged: _handleThemeChange,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Use custom mood gradient background'),
            value: _customGradientEnabled,
            onChanged: _handleGradientToggle,
          ),
          
          const Divider(height: 40),
          
          // Notification Settings
          _buildSectionHeader('Notifications'),
          if (_isLoadingNotifications)
            const Center(child: CircularProgressIndicator())
          else
            _buildNotificationSettings(),
        ],
      ),
    );
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
          
          if (kDebugMode) ...[
            // Debug section (only in development)
            const Divider(height: 40),
            _buildSectionHeader('Debug & Testing'),
            
            // Individual notification tests
            _buildSubsectionHeader('Mood Access Notifications'),
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
            
            const SizedBox(height: 16),
            _buildSubsectionHeader('Goal Notifications'),
            ListTile(
              title: const Text('Test Goal Progress'),
              subtitle: const Text('Goal progress update'),
              leading: const Icon(Icons.trending_up, color: Colors.blue),
              onTap: () => _sendGoalProgressNotification(),
            ),
            ListTile(
              title: const Text('Test Goal Encouragement'),
              subtitle: const Text('Goal encouragement message'),
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              onTap: () => _sendGoalEncouragementNotification(),
            ),
            
            const SizedBox(height: 16),
            _buildSubsectionHeader('General Tests'),
            ListTile(
              title: const Text('Send test notification'),
              subtitle: const Text('Send a real test notification'),
              leading: const Icon(Icons.notifications),
              onTap: () => _showTestNotification(),
            ),
            ListTile(
              title: const Text('Check pending notifications'),
              subtitle: const Text('See what notifications are scheduled'),
              leading: const Icon(Icons.schedule),
              onTap: () => _showPendingNotifications(),
            ),
            ListTile(
              title: const Text('Request notification permission'),
              subtitle: const Text('Show system permission dialog'),
              leading: const Icon(Icons.settings),
              onTap: () => _requestNotificationPermission(),
            ),
          ],
        ],
      ],
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

  Future<void> _testImmediateNotification() async {
    // Test notification in 10 seconds
    await real_notifications.RealNotificationService.scheduleTestNotificationIn(
        10,
        'This test notification was scheduled 10 seconds ago!'
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📱 Test notification scheduled for 10 seconds from now!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  Future<void> _showPendingNotifications() async {
    final pendingNotifications = await notifications.EnhancedNotificationService.getSystemPendingNotifications();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: pendingNotifications.isEmpty
              ? const Text('No pending notifications scheduled.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pendingNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = pendingNotifications[index];
                    return ListTile(
                      title: Text(notification.title ?? 'No title'),
                      subtitle: Text(notification.body ?? 'No body'),
                      trailing: Text('ID: ${notification.id}'),
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
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    // Request real notification permissions
    final granted = await notifications.EnhancedNotificationService.requestPermissions();

    if (granted && mounted) {
      final settings = _notificationSettings!.copyWith(enabled: true);
      await _updateNotificationSettings(settings);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notifications enabled!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Notification permission denied. You can enable it in system settings.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showTestNotification() async {
    await notifications.EnhancedNotificationService.showTestNotification();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📱 Test notification sent!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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

  // Individual notification test methods
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

  Future<void> _sendGoalProgressNotification() async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8006,
      title: 'Goal Progress Update 🎯',
      body: 'Maintain 7+ Average Mood: You\'re doing great! Keep it up!',
      payload: jsonEncode({
        'type': 'goal',
        'goalId': 'test-goal-123',
        'goalTitle': 'Maintain 7+ Average Mood'
      }),
    );
    _showNotificationSentMessage('Goal progress notification');
  }

  Future<void> _sendGoalEncouragementNotification() async {
    await real_notifications.RealNotificationService.showNotification(
      id: 8007,
      title: 'Keep working toward your goal! 💪',
      body: 'Improve Daily Mood - You\'ve been at this for 5 days! Stay motivated!',
      payload: jsonEncode({
        'type': 'goal',
        'goalId': 'test-goal-456',
        'goalTitle': 'Improve Daily Mood',
        'daysSinceCreated': 5
      }),
    );
    _showNotificationSentMessage('Goal encouragement notification');
  }

  void _showNotificationSentMessage(String notificationType) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📱 $notificationType sent! Tap to test navigation.'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}