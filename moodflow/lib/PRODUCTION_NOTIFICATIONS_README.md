# Production Notification Implementation

## Current Status: Development/Testing Mode
The current notification system is designed for development and testing. To make it work with real system notifications, follow these steps:

## 1. Add Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_local_notifications: ^16.3.2
  permission_handler: ^11.2.0  # For Android 13+ permissions
  timezone: ^0.9.2  # For scheduling notifications
```

## 2. Platform Configuration

### Android Setup (`android/app/src/main/AndroidManifest.xml`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    
    <application android:name="${applicationName}">
        <!-- Add this receiver for boot completed -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>
        </receiver>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    </application>
</manifest>
```

### iOS Setup (`ios/Runner/AppDelegate.swift`):

```swift
import UIKit
import Flutter
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Request permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 3. Update NotificationManager

Replace the placeholder methods in `services/notification_manager.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationManager {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone
    tz.initializeTimeZones();
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    _isInitialized = true;
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.request().isGranted) {
        return true;
      }
      // For Android 13+, also request POST_NOTIFICATIONS
      return await Permission.notification.request().isGranted;
    } else if (Platform.isIOS) {
      return await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  static Future<void> scheduleNotification(NotificationContent notification) async {
    // Schedule the actual system notification
    await _notifications.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mood_tracker_channel',
          'Mood Tracker Notifications',
          channelDescription: 'Notifications for mood tracking reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(notification.data),
    );
  }

  static void _handleNotificationTap(NotificationResponse response) {
    // Handle notification tap - navigate to appropriate screen
    final data = jsonDecode(response.payload ?? '{}');
    // Add navigation logic here
  }
}
```

## 4. Update Permission Dialog

The current permission dialog is just a preview. In production:

1. **iOS**: The system automatically shows permission dialog when you call `requestPermissions()`
2. **Android**: For Android 13+, the system shows permission dialog when you request `POST_NOTIFICATIONS` permission

## 5. Testing Real Notifications

To test with real notifications:

1. Add the dependencies
2. Configure platforms
3. Update the NotificationManager
4. Run on physical device (notifications don't work in simulator/emulator reliably)

## Current Development Features

✅ **Works Now:**
- Permission tracking
- Notification scheduling logic  
- Settings panel
- Time-based triggers
- Goal integration
- Snackbar previews for testing

🔧 **Needs Production Setup:**
- Actual system notifications
- Real permission dialogs
- Background scheduling
- Notification tapping/navigation

## Testing the Current System

1. **Test Notifications**: Shows example notifications as snackbars
2. **Check Real Pending**: Shows what notifications would be scheduled (usually none during development)
3. **Request Permission**: Simulates the permission flow

The notification logic and timing are all working - it just needs the real notification plugin to show actual system notifications!