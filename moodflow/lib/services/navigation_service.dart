import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Get the current navigation context
  static BuildContext? get context => navigatorKey.currentContext;
  
  /// Navigate to a specific route
  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }
  
  /// Navigate and replace current route
  static Future<dynamic> navigateToReplacement(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName, arguments: arguments);
  }
  
  /// Navigate and clear stack
  static Future<dynamic> navigateAndClearStack(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName, 
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }
  
  /// Go back
  static void goBack() {
    return navigatorKey.currentState!.pop();
  }
  
  /// Handle notification taps - this is the main function for notifications
  static Future<void> handleNotificationTap(Map<String, dynamic> payload) async {
    final type = payload['type'] as String?;
    
    switch (type) {
      case 'access_reminder':
        await _handleAccessReminder(payload);
        break;
      case 'end_of_day':
        await _handleEndOfDayReminder(payload);
        break;
      case 'goal':
        await _handleGoalNotification(payload);
        break;
      case 'test':
        // For test notifications, just go to home
        await navigateToHome();
        break;
      default:
        // Unknown notification type, go to home
        await navigateToHome();
    }
  }
  
  /// Handle access reminder notifications (morning, midday, evening)
  static Future<void> _handleAccessReminder(Map<String, dynamic> payload) async {
    final segment = payload['segment'] as int?;
    final timeSegment = payload['timeSegment'] as String?;
    
    // Navigate to mood log screen with specific segment
    await navigateToMoodLog(segment: segment, timeSegment: timeSegment);
  }
  
  /// Handle end of day notifications
  static Future<void> _handleEndOfDayReminder(Map<String, dynamic> payload) async {
    // If user has logged some segments, take them to mood log to complete
    // If they haven't logged anything, also take them to mood log
    await navigateToMoodLog();
  }
  
  /// Handle goal-related notifications
  static Future<void> _handleGoalNotification(Map<String, dynamic> payload) async {
    final goalId = payload['goalId'] as String?;
    
    // Navigate to goals screen
    await navigateToGoals(goalId: goalId);
  }
  
  /// Navigate to mood log screen
  static Future<void> navigateToMoodLog({int? segment, String? timeSegment}) async {
    // First navigate to home to ensure we're in the right navigation stack
    await navigateToHome();
    
    // Then navigate to mood log
    // We'll pass the segment info so the mood log can jump to the right segment
    await navigateTo('/mood-log', arguments: {
      'segment': segment,
      'timeSegment': timeSegment,
    });
  }
  
  /// Navigate to goals screen
  static Future<void> navigateToGoals({String? goalId}) async {
    await navigateToHome();
    await navigateTo('/goals', arguments: {
      'goalId': goalId,
    });
  }
  
  /// Navigate to trends screen
  static Future<void> navigateToTrends() async {
    await navigateToHome();
    await navigateTo('/trends');
  }
  
  /// Navigate to history screen
  static Future<void> navigateToHistory() async {
    await navigateToHome();
    await navigateTo('/history');
  }
  
  /// Navigate to settings screen
  static Future<void> navigateToSettings() async {
    await navigateToHome();
    await navigateTo('/settings');
  }
  
  /// Navigate to home screen
  static Future<void> navigateToHome() async {
    if (navigatorKey.currentState?.canPop() == true) {
      // If we can pop, we're not at home, so go back to home
      navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
    // If we can't pop, we're already at home
  }
  
  /// Show a snackbar message
  static void showSnackBar(String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final context = NavigationService.context;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration,
        ),
      );
    }
  }
  
  /// Show an info message when user taps notification
  static void showNotificationTapInfo(String notificationType) {
    String message;
    switch (notificationType) {
      case 'access_reminder':
        message = '📱 Opened from mood logging reminder';
        break;
      case 'end_of_day':
        message = '🌙 Opened from end-of-day reminder';
        break;
      case 'goal':
        message = '🎯 Opened from goal notification';
        break;
      default:
        message = '📱 Opened from notification';
    }
    
    showSnackBar(message, backgroundColor: Colors.blue);
  }
}