import 'dart:async';
import 'package:flutter/material.dart';
import 'real_notification_service.dart';

class NotificationManager {
  static Timer? _backgroundTimer;
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Just ensure real notifications are initialized
    RealNotificationService.initialize();
  }

  static void dispose() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _isInitialized = false;
  }

  // Remove all the placeholder/testing methods and keep only these essentials:
  static Future<void> showTestNotification(
      BuildContext context, String title, String body) async {
    await RealNotificationService.showNotification(
      id: 9999,
      title: title,
      body: body,
    );
  }
}
