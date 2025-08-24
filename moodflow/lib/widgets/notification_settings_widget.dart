import 'package:flutter/material.dart';
import '../services/notifications/enhanced_notification_service.dart';

class NotificationSettingsWidget extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const NotificationSettingsWidget({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<NotificationSettingsWidget> createState() => _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState extends State<NotificationSettingsWidget> {
  NotificationSettings? _notificationSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final settings = await EnhancedNotificationService.loadSettings();
    setState(() {
      _notificationSettings = settings;
      _isLoading = false;
    });
  }

  Future<void> _updateNotificationSettings(NotificationSettings settings) async {
    await EnhancedNotificationService.saveSettings(settings);
    setState(() {
      _notificationSettings = settings;
    });
  }

  Future<void> _selectEndOfDayTime(NotificationSettings settings) async {
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

  Future<void> _selectMorningTime(NotificationSettings settings) async {
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

  Future<void> _selectMiddayTime(NotificationSettings settings) async {
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

  Future<void> _selectEveningTime(NotificationSettings settings) async {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final settings = _notificationSettings!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Header with master toggle
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notifications_active,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            title: const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              settings.enabled
                  ? 'Reminders and updates enabled'
                  : 'All notifications disabled',
              style: TextStyle(
                color: settings.enabled ? Colors.green.shade600 : Colors.grey.shade600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Master toggle switch
                Switch(
                  value: settings.enabled,
                  onChanged: (value) {
                    _updateNotificationSettings(settings.copyWith(enabled: value));
                  },
                ),
                // Expand/collapse button
                IconButton(
                  icon: Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: widget.onToggleExpanded,
                ),
              ],
            ),
          ),

          // Expandable content
          if (widget.isExpanded && settings.enabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Access Reminders Section
                  _buildSubsectionHeader('Mood Log Access'),
                  SwitchListTile(
                    title: const Text('Access reminders'),
                    subtitle: const Text('When new mood logging becomes available'),
                    value: settings.accessReminders,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(accessReminders: value));
                    },
                    contentPadding: EdgeInsets.zero,
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
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          if (settings.morningAccessReminder)
                            ListTile(
                              title: const Text('Morning time'),
                              subtitle: Text(settings.morningTime.toString()),
                              trailing: const Icon(Icons.access_time),
                              onTap: () => _selectMorningTime(settings),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          SwitchListTile(
                            title: Text('Midday (${settings.middayTime})'),
                            subtitle: const Text('When midday mood logging becomes available'),
                            value: settings.middayAccessReminder,
                            onChanged: (value) {
                              _updateNotificationSettings(settings.copyWith(middayAccessReminder: value));
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          if (settings.middayAccessReminder)
                            ListTile(
                              title: const Text('Midday time'),
                              subtitle: Text(settings.middayTime.toString()),
                              trailing: const Icon(Icons.access_time),
                              onTap: () => _selectMiddayTime(settings),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          SwitchListTile(
                            title: Text('Evening (${settings.eveningTime})'),
                            subtitle: const Text('When evening mood logging becomes available'),
                            value: settings.eveningAccessReminder,
                            onChanged: (value) {
                              _updateNotificationSettings(settings.copyWith(eveningAccessReminder: value));
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          if (settings.eveningAccessReminder)
                            ListTile(
                              title: const Text('Evening time'),
                              subtitle: Text(settings.eveningTime.toString()),
                              trailing: const Icon(Icons.access_time),
                              onTap: () => _selectEveningTime(settings),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // End of Day Reminders
                  _buildSubsectionHeader('End of Day'),
                  SwitchListTile(
                    title: const Text('End-of-day reminder'),
                    subtitle: Text('Remind me at ${settings.endOfDayTime} if I haven\'t logged moods'),
                    value: settings.endOfDayReminder,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(endOfDayReminder: value));
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (settings.endOfDayReminder)
                    ListTile(
                      title: const Text('Reminder time'),
                      subtitle: Text(settings.endOfDayTime.toString()),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectEndOfDayTime(settings),
                      contentPadding: EdgeInsets.zero,
                    ),

                  const SizedBox(height: 16),

                  // Goal Reminders
                  _buildSubsectionHeader('Goals'),
                  SwitchListTile(
                    title: const Text('Goal reminders'),
                    subtitle: const Text('Updates about your mood goals'),
                    value: settings.goalReminders,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(goalReminders: value));
                    },
                    contentPadding: EdgeInsets.zero,
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
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          SwitchListTile(
                            title: const Text('Encouragement'),
                            subtitle: const Text('Motivational messages for your goals'),
                            value: settings.goalEncouragement,
                            onChanged: (value) {
                              _updateNotificationSettings(settings.copyWith(goalEncouragement: value));
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Smart Features
                  _buildSubsectionHeader('Smart Features'),
                  SwitchListTile(
                    title: const Text('Correlation insights'),
                    subtitle: const Text('Notifications about mood patterns and correlations'),
                    value: settings.correlationNotifications,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(correlationNotifications: value));
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  SwitchListTile(
                    title: const Text('Smart insights'),
                    subtitle: const Text('AI-powered recommendations and observations'),
                    value: settings.smartInsightNotifications,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(smartInsightNotifications: value));
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 16),

                  // Celebrations
                  _buildSubsectionHeader('Celebrations'),
                  SwitchListTile(
                    title: const Text('Streak celebrations'),
                    subtitle: const Text('Celebrate when you maintain logging streaks'),
                    value: settings.streakCelebrations,
                    onChanged: (value) {
                      _updateNotificationSettings(settings.copyWith(streakCelebrations: value));
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ] else if (widget.isExpanded && !settings.enabled) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Enable notifications above to configure specific reminder settings.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubsectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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