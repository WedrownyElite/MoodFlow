import 'package:flutter/material.dart';
import '../services/notifications/enhanced_notification_service.dart'
as notifications;
import '../services/notifications/real_notification_service.dart';

class NotificationSettingsWidget extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const NotificationSettingsWidget({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<NotificationSettingsWidget> createState() =>
      _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState
    extends State<NotificationSettingsWidget> {
  notifications.NotificationSettings? _notificationSettings;
  bool _isLoading = true;
  bool _systemPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _checkSystemPermissions();
  }

  Future<void> _loadNotificationSettings() async {
    final settings =
    await notifications.EnhancedNotificationService.loadSettings();
    setState(() {
      _notificationSettings = settings;
      _isLoading = false;
    });
  }

  Future<void> _checkSystemPermissions() async {
    final granted = await RealNotificationService.areNotificationsEnabled();
    setState(() {
      _systemPermissionGranted = granted;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await RealNotificationService.requestPermissions();

    if (!mounted) return;

    setState(() {
      _systemPermissionGranted = granted;
    });

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications enabled successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permissions are required for reminders to work.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _updateNotificationSettings(
      notifications.NotificationSettings settings) async {
    await notifications.EnhancedNotificationService.saveSettings(settings);
    setState(() {
      _notificationSettings = settings;
    });
  }

  Future<void> _showTestNotification() async {
    await RealNotificationService.showTestNotification();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _selectTime(
      String timeType,
      notifications.TimeOfDay currentTime,
      Function(notifications.TimeOfDay) onTimeSelected,
      ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentTime.hour, minute: currentTime.minute),
      helpText: 'Select $timeType time',
    );

    if (picked != null && mounted) {
      final newTime =
      notifications.TimeOfDay(hour: picked.hour, minute: picked.minute);
      onTimeSelected(newTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: EdgeInsets.zero,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final settings = _notificationSettings!;
    final canUseNotifications = _systemPermissionGranted && settings.enabled;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // Header with master toggle and system permission status
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _systemPermissionGranted
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _systemPermissionGranted
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _systemPermissionGranted
                    ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Theme.of(context).primaryColor)
                    : Colors.grey,
                size: 24,
              ),
            ),
            title: const Text(
              'Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: _buildHeaderSubtitle(settings),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // System permission button if not granted
                if (!_systemPermissionGranted)
                  TextButton(
                    onPressed: _requestPermissions,
                    child: const Text('Enable'),
                  ),

                // Master toggle switch
                if (_systemPermissionGranted)
                  Switch(
                    value: settings.enabled,
                    onChanged: (value) {
                      _updateNotificationSettings(
                          settings.copyWith(enabled: value));
                    },
                  ),

                // Expand/collapse button
                IconButton(
                  icon: Icon(widget.isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                  onPressed: widget.onToggleExpanded,
                ),
              ],
            ),
          ),

          // Expandable content
          if (widget.isExpanded) ...[
            const Divider(height: 1),

            // System permission warning if not granted
            if (!_systemPermissionGranted) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'System Permission Required',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MoodFlow needs notification permissions to send you mood logging reminders. Tap "Enable" above to grant permission.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ] else if (canUseNotifications) ...[
              // Main notification settings when system permission is granted
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Test notification button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showTestNotification,
                        icon: const Icon(Icons.send),
                        label: const Text('Send Test Notification'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Mood Logging Reminders Section
                    _buildSectionHeader('Mood Logging Reminders', Icons.access_time),
                    _buildSwitchTile(
                      title: 'Access reminders',
                      subtitle: 'When new mood logging becomes available',
                      value: settings.accessReminders,
                      onChanged: (value) {
                        _updateNotificationSettings(
                            settings.copyWith(accessReminders: value));
                      },
                    ),

                    if (settings.accessReminders) ...[
                      const SizedBox(height: 8),
                      _buildTimeCard(
                        title: '☀️ Morning',
                        subtitle: 'When morning logging becomes available',
                        time: settings.morningTime,
                        enabled: settings.morningAccessReminder,
                        onEnabledChanged: (value) {
                          _updateNotificationSettings(
                              settings.copyWith(morningAccessReminder: value));
                        },
                        onTimeChanged: (time) {
                          _updateNotificationSettings(
                              settings.copyWith(morningTime: time));
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildTimeCard(
                        title: '⚡ Midday',
                        subtitle: 'When midday logging becomes available',
                        time: settings.middayTime,
                        enabled: settings.middayAccessReminder,
                        onEnabledChanged: (value) {
                          _updateNotificationSettings(
                              settings.copyWith(middayAccessReminder: value));
                        },
                        onTimeChanged: (time) {
                          _updateNotificationSettings(
                              settings.copyWith(middayTime: time));
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildTimeCard(
                        title: '🌙 Evening',
                        subtitle: 'When evening logging becomes available',
                        time: settings.eveningTime,
                        enabled: settings.eveningAccessReminder,
                        onEnabledChanged: (value) {
                          _updateNotificationSettings(
                              settings.copyWith(eveningAccessReminder: value));
                        },
                        onTimeChanged: (time) {
                          _updateNotificationSettings(
                              settings.copyWith(eveningTime: time));
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // End of Day Section
                    _buildSectionHeader('End of Day', Icons.bedtime),
                    _buildTimeCard(
                      title: 'End-of-day reminder',
                      subtitle: 'Remind me if I haven\'t logged moods',
                      time: settings.endOfDayTime,
                      enabled: settings.endOfDayReminder,
                      onEnabledChanged: (value) {
                        _updateNotificationSettings(
                            settings.copyWith(endOfDayReminder: value));
                      },
                      onTimeChanged: (time) {
                        _updateNotificationSettings(
                            settings.copyWith(endOfDayTime: time));
                      },
                      showTimeWhenDisabled: true,
                    ),

                    const SizedBox(height: 24),

                    // Goals & Progress Section
                    _buildSectionHeader('Goals & Progress', Icons.emoji_events),
                    _buildSwitchTile(
                      title: 'Goal reminders',
                      subtitle: 'Updates about your mood goals',
                      value: settings.goalReminders,
                      onChanged: (value) {
                        _updateNotificationSettings(
                            settings.copyWith(goalReminders: value));
                      },
                    ),

                    if (settings.goalReminders) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              title: 'Progress updates',
                              subtitle: 'Regular updates on goal progress',
                              value: settings.goalProgress,
                              onChanged: (value) {
                                _updateNotificationSettings(
                                    settings.copyWith(goalProgress: value));
                              },
                              isSubsetting: true,
                            ),
                            _buildSwitchTile(
                              title: 'Encouragement messages',
                              subtitle: 'Motivational messages for your goals',
                              value: settings.goalEncouragement,
                              onChanged: (value) {
                                _updateNotificationSettings(
                                    settings.copyWith(goalEncouragement: value));
                              },
                              isSubsetting: true,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Smart Features Section
                    _buildSectionHeader('Smart Features', Icons.psychology),
                    _buildSwitchTile(
                      title: 'Smart insights',
                      subtitle: 'AI-powered recommendations and observations',
                      value: settings.smartInsightNotifications,
                      onChanged: (value) {
                        _updateNotificationSettings(
                            settings.copyWith(smartInsightNotifications: value));
                      },
                    ),
                    _buildSwitchTile(
                      title: 'Correlation insights',
                      subtitle: 'Notifications about mood patterns',
                      value: settings.correlationNotifications,
                      onChanged: (value) {
                        _updateNotificationSettings(
                            settings.copyWith(correlationNotifications: value));
                      },
                    ),

                    const SizedBox(height: 24),

                    // Celebrations Section
                    _buildSectionHeader('Celebrations', Icons.celebration),
                    _buildSwitchTile(
                      title: 'Streak celebrations',
                      subtitle: 'Celebrate when you maintain logging streaks',
                      value: settings.streakCelebrations,
                      onChanged: (value) {
                        _updateNotificationSettings(
                            settings.copyWith(streakCelebrations: value));
                      },
                    ),
                  ],
                ),
              ),
            ] else if (_systemPermissionGranted && !settings.enabled) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.notifications_paused, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'All notifications are disabled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Enable notifications above to configure specific reminder settings.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSubtitle(notifications.NotificationSettings settings) {
    if (!_systemPermissionGranted) {
      return const Text(
        'System permission required',
        style: TextStyle(color: Colors.orange),
      );
    }

    if (!settings.enabled) {
      return Text(
        'All notifications disabled',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }

    // Count enabled reminders
    int enabledCount = 0;
    if (settings.accessReminders) {
      if (settings.morningAccessReminder) enabledCount++;
      if (settings.middayAccessReminder) enabledCount++;
      if (settings.eveningAccessReminder) enabledCount++;
    }
    if (settings.endOfDayReminder) enabledCount++;
    if (settings.goalReminders) enabledCount++;
    if (settings.streakCelebrations) enabledCount++;

    return Text(
      '$enabledCount active reminder${enabledCount != 1 ? 's' : ''}',
      style: TextStyle(color: Colors.green.shade600),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isSubsetting = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isSubsetting ? 0 : 0,
      ),
      child: Container(
        decoration: isSubsetting
            ? BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        )
            : null,
        child: SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSubsetting ? 12 : 0,
            vertical: isSubsetting ? 0 : 0,
          ),
          dense: isSubsetting,
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String title,
    required String subtitle,
    required notifications.TimeOfDay time,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<notifications.TimeOfDay> onTimeChanged,
    bool showTimeWhenDisabled = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled
            ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
            : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: enabled ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled ? Colors.grey.shade600 : Colors.grey,
                  ),
                ),
                if (enabled || showTimeWhenDisabled) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: enabled
                        ? () => _selectTime(title, time, onTimeChanged)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: enabled
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: enabled
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: enabled
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                            ),
                          ),
                          if (enabled) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit,
                              size: 12,
                              color: Theme.of(context).primaryColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onEnabledChanged,
          ),
        ],
      ),
    );
  }
}