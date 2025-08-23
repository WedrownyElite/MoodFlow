import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// A centralized logging utility for the MoodFlow app.
/// 
/// Usage:
/// ```dart
/// Logger.log('Simple message');
/// Logger.debug('Debug info');
/// Logger.info('General information');
/// Logger.warning('Something might be wrong');
/// Logger.error('An error occurred');
/// ```
class Logger {
  static const String _appName = 'MoodFlow';

  /// General log - uses debugPrint in debug mode, developer.log in production
  static void log(String message, {String? tag}) {
    final formattedMessage = _formatMessage(message, tag);

    if (kDebugMode) {
      debugPrint(formattedMessage);
    } else {
      developer.log(
        message,
        name: tag ?? _appName,
        time: DateTime.now(),
      );
    }
  }

  /// Debug level logging - only shows in debug mode
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final formattedMessage = _formatMessage(message, tag, level: 'DEBUG');
      debugPrint(formattedMessage);
    }
  }

  /// Info level logging - shows in both debug and production
  static void info(String message, {String? tag}) {
    final formattedMessage = _formatMessage(message, tag, level: 'INFO');

    if (kDebugMode) {
      debugPrint(formattedMessage);
    } else {
      developer.log(
        message,
        name: tag ?? _appName,
        level: 800, // Info level
        time: DateTime.now(),
      );
    }
  }

  /// Warning level logging - shows in both debug and production
  static void warning(String message, {String? tag, Object? error}) {
    final formattedMessage = _formatMessage(message, tag, level: 'WARNING');

    if (kDebugMode) {
      debugPrint('⚠️ $formattedMessage');
      if (error != null) {
        debugPrint('Error details: $error');
      }
    } else {
      developer.log(
        message,
        name: tag ?? _appName,
        level: 900, // Warning level
        error: error,
        time: DateTime.now(),
      );
    }
  }

  /// Error level logging - shows in both debug and production
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final formattedMessage = _formatMessage(message, tag, level: 'ERROR');

    if (kDebugMode) {
      debugPrint('❌ $formattedMessage');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    } else {
      developer.log(
        message,
        name: tag ?? _appName,
        level: 1000, // Error level
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    }
  }

  /// Service-specific loggers for better organization
  static void dataService(String message) => log(message, tag: 'DataService');
  static void backupService(String message) => log(message, tag: 'BackupService');
  static void notificationService(String message) => log(message, tag: 'NotificationService');
  static void cloudService(String message) => log(message, tag: 'CloudService');
  static void moodService(String message) => log(message, tag: 'MoodService');
  static void trendsService(String message) => log(message, tag: 'TrendsService');
  static void analyticsService(String message) => log(message, tag: 'AnalyticsService');
  static void aiService(String message) => log(message, tag: 'AIService');

  /// Format message with timestamp and tag
  static String _formatMessage(String message, String? tag, {String? level}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.SSS
    final tagPart = tag != null ? '[$tag] ' : '';
    final levelPart = level != null ? '$level: ' : '';

    return '$timestamp $tagPart$levelPart$message';
  }
}

/// Extension methods for easy migration from print() statements
extension LoggerShortcuts on String {
  /// Quick way to log a string: 'message'.log();
  void log({String? tag}) => Logger.log(this, tag: tag);

  /// Quick debug log: 'message'.debug();
  void debug({String? tag}) => Logger.debug(this, tag: tag);

  /// Quick info log: 'message'.info();
  void info({String? tag}) => Logger.info(this, tag: tag);

  /// Quick warning log: 'message'.warning();
  void warning({String? tag, Object? error}) => Logger.warning(this, tag: tag, error: error);

  /// Quick error log: 'message'.error();
  void error({String? tag, Object? error, StackTrace? stackTrace}) =>
      Logger.error(this, tag: tag, error: error, stackTrace: stackTrace);
}

/// Convenience methods for common logging patterns
class LoggerHelper {
  /// Log the start of a method/function
  static void methodStart(String methodName, {String? className}) {
    final tag = className ?? 'Method';
    Logger.debug('🔄 Starting $methodName', tag: tag);
  }

  /// Log the completion of a method/function
  static void methodEnd(String methodName, {String? className, Duration? duration}) {
    final tag = className ?? 'Method';
    final durationText = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    Logger.debug('✅ Completed $methodName$durationText', tag: tag);
  }

  /// Log an API call
  static void apiCall(String endpoint, {String? method}) {
    Logger.info('📡 API ${method ?? 'CALL'}: $endpoint', tag: 'API');
  }

  /// Log a database operation
  static void dbOperation(String operation, {String? table}) {
    final tableText = table != null ? ' on $table' : '';
    Logger.debug('💾 DB $operation$tableText', tag: 'Database');
  }

  /// Log a navigation event
  static void navigation(String route, {String? from}) {
    final fromText = from != null ? ' from $from' : '';
    Logger.debug('🧭 Navigate to $route$fromText', tag: 'Navigation');
  }

  /// Log user interactions
  static void userAction(String action, {Map<String, dynamic>? data}) {
    final dataText = data != null ? ' - Data: $data' : '';
    Logger.info('👤 User: $action$dataText', tag: 'UserAction');
  }
}