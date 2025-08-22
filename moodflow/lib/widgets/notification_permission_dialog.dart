import 'package:flutter/material.dart';
import '../services/notifications/enhanced_notification_service.dart';

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Stay on track with notifications',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get helpful reminders to:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          _buildBenefit(
            icon: Icons.access_time,
            title: 'Log moods at the right time',
            description: 'Morning, midday, and evening reminders',
          ),
          const SizedBox(height: 8),
          _buildBenefit(
            icon: Icons.bedtime,
            title: 'End-of-day check-ins',
            description: 'Gentle reminders before bed',
          ),
          const SizedBox(height: 8),
          _buildBenefit(
            icon: Icons.flag,
            title: 'Track your goals',
            description: 'Progress updates and encouragement',
          ),
          const SizedBox(height: 8),
          _buildBenefit(
            icon: Icons.local_fire_department,
            title: 'Celebrate streaks',
            description: 'Acknowledge your consistency',
          ),
          const SizedBox(height: 16),
          Text(
            'You can customize or disable these anytime in Settings.',
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
          onPressed: () async {
            await EnhancedNotificationService.markPermissionAsked();
            
            // Save settings with notifications disabled
            final settings = NotificationSettings.defaultSettings().copyWith(enabled: false);
            await EnhancedNotificationService.saveSettings(settings);
            
            if (context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () async {
            await EnhancedNotificationService.markPermissionAsked();
            
            // Request permissions using the real notification service
            final granted = await EnhancedNotificationService.requestPermissions();
            
            if (granted) {
              // Save enabled settings and schedule notifications
              final settings = NotificationSettings.defaultSettings();
              await EnhancedNotificationService.saveSettings(settings);
            } else {
              // Save disabled settings if permission was denied
              final settings = NotificationSettings.defaultSettings().copyWith(enabled: false);
              await EnhancedNotificationService.saveSettings(settings);
            }
            
            if (context.mounted) {
              Navigator.of(context).pop(granted);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Enable notifications'),
        ),
      ],
    );
  }

  Widget _buildBenefit({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}