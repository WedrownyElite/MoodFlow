// ─────────────────────────────────────────────────────────────
//  MoodFlow
//  Copyright (c) 2025 OddologyInc. All rights reserved.
//
//  This software is licensed under the MoodFlow License.
//
//  - Free for personal, educational, and research use.
//  - Modification and redistribution allowed with attribution
//    and inclusion of this license.
//  - Commercial use and rebranding strictly prohibited.
//
//  See the LICENSE file in the root of this repository for full terms.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/main_menu_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/mood_history_screen.dart';
import 'screens/mood_trends_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/backup_export_screen.dart';
import 'screens/ai_analysis_screen.dart';
import 'screens/debug_data_screen.dart';
import 'services/notifications/enhanced_notification_service.dart';
import 'services/notifications/notification_manager.dart';
import 'services/navigation_service.dart';
import 'services/backup/cloud_backup_service.dart';
import 'services/data/mood_data_service.dart';
import 'services/utils/logger.dart';
import 'screens/correlation_screen.dart';
import 'screens/insights_screen.dart';
import '/services/insights/smart_insights_service.dart';
import '/services/onboarding/onboarding_service.dart';
import '/services/backup/startup_restore_service.dart';
import '/services/widgets/mood_widget_service.dart';

void main() async {
  // CRITICAL: Ensure Flutter bindings are initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services in the correct order
  await _initializeServices();

  runApp(const MoodTrackerApp());
}

/// Initialize all services in the correct order to prevent binding issues
Future<void> _initializeServices() async {
  try {
    // 1. Initialize notifications FIRST (this often causes the binding errors)
    Logger.notificationService('🔄 Initializing notification services...');
    await EnhancedNotificationService.initialize();
    Logger.notificationService('✅ Notification services initialized');

    // 2. Initialize notification manager
    NotificationManager.initialize();
    Logger.notificationService('✅ Notification manager initialized');

    // 3. Initialize SmartInsightService
    await SmartInsightsService.generateInsights();
    Logger.smartInsightService('✅ Generated Insights');
    await SmartInsightsService.scheduleAdaptiveReminders();
    Logger.smartInsightService('✅ Scheduled Adaptive Reminders');

    // 3. Initialize MoodDataService
    await MoodDataService.initialize();
    Logger.moodService('✅ MoodDataService initialized');

    // 4. Initialize enhanced notifications with personalization
    await EnhancedNotificationService.initialize();
    Logger.notificationService('✅ Enhanced notifications initialized');

    // 5. Initialize cloud backup services
    await _initializeCloudBackup();
  } catch (e) {
    Logger.moodService('❌ Error during service initialization: $e');
    // Continue with app launch even if some services fail
  }
}

/// Initialize cloud backup with proper error handling
Future<void> _initializeCloudBackup() async {
  try {
    if (kDebugMode) {
      if (await RealCloudBackupService.isCloudBackupAvailable()) {
        Logger.cloudService('✅ Real cloud backup system is available');
        await RealCloudBackupService.setAutoBackupEnabled(true);
        Logger.cloudService('🔧 Cloud backup enabled');
        await RealCloudBackupService.checkForRestoreOnStartup();
        Logger.cloudService('✅ Cloud backup initialization complete');
      } else {
        Logger.cloudService(
            '❌ Real cloud backup system is not available on this platform');
      }
    } else {
      // PRODUCTION: Silent cloud backup initialization
      try {
        if (await RealCloudBackupService.isCloudBackupAvailable()) {
          await RealCloudBackupService.setAutoBackupEnabled(true);
          await RealCloudBackupService.checkForRestoreOnStartup();
        }
      } catch (e) {
        // Silent fail in production
        Logger.cloudService(
            '⚠️ Cloud backup initialization failed silently: $e');
      }
    }
  } catch (e) {
    Logger.cloudService('❌ Cloud backup initialization error: $e');
  }
}

class MoodTrackerApp extends StatefulWidget {
  const MoodTrackerApp({super.key});

  @override
  State<MoodTrackerApp> createState() => _MoodTrackerAppState();
}

class _MoodTrackerAppState extends State<MoodTrackerApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _useCustomGradient = true;
  bool _showOnboarding = false; // ignore: unused_field

  static const _prefThemeModeKey = 'theme_mode';
  static const _prefCustomGradientKey = 'use_custom_gradient';

  // Method channel for widget interactions
  static const MethodChannel _widgetChannel = MethodChannel('widget_interaction');

  @override
  @override
  void initState() {
    super.initState();

    // Initialize widget service
    MoodWidgetService.initialize();

    // Listen for widget interactions from home_widget package
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        MoodWidgetService.handleWidgetInteraction(uri.toString());
      }
    });

    // Enhanced widget interaction handling
    _widgetChannel.setMethodCallHandler(_handleWidgetMethodCall);

    // Update widget on app start
    Future.delayed(const Duration(seconds: 1), () {
      MoodWidgetService.updateWidget();
    });

    // Load preferences and check for onboarding after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _loadPreferences();
      _checkOnboarding();
      _scheduleInitialBackupCheck();
      _checkForPendingWidgetMoods();
    });
  }

  // Handle widget method calls from native side
  Future<dynamic> _handleWidgetMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'widgetActionReceived':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final action = arguments['action'] as String?;
        if (action != null) {
          Logger.moodService('📱 Received widget action from native: $action');
          await MoodWidgetService.handleWidgetInteraction(action);
        }
        return true;

      case 'openMoodLog':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final segment = arguments['segment'] as int? ?? 0;
        final fromWidget = arguments['fromWidget'] as bool? ?? false;

        Logger.moodService('📱 Opening mood log from widget: segment=$segment');

        // Navigate to mood log with segment info
        if (mounted) {
          Navigator.pushNamed(context, '/mood-log', arguments: {
            'segment': segment,
            'fromWidget': fromWidget,
          });
        }
        return true;

    // ADD THIS NEW CASE
      case 'forceNavigateToMoodLog':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final segment = arguments['segment'] as int? ?? 0;
        final fromWidget = arguments['fromWidget'] as bool? ?? false;

        Logger.moodService('📱 FORCE navigation to mood log from widget: segment=$segment');

        // Navigate to mood log regardless of current screen
        if (mounted) {
          // Clear navigation stack and go to mood log
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/mood-log',
                (route) => false, // Remove all previous routes
            arguments: {
              'segment': segment,
              'fromWidget': fromWidget,
            },
          );
        }
        return true;

      case 'processPendingWidgetMood':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        await _processPendingWidgetMood(arguments);
        return true;

      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  // Check for pending widget moods on app startup
  Future<void> _checkForPendingWidgetMoods() async {
    try {
      final result = await _widgetChannel.invokeMethod('checkPendingMoods');
      if (result is List && result.isNotEmpty) {
        Logger.moodService('📱 Found ${result.length} pending widget moods');

        for (final moodData in result) {
          await _processPendingWidgetMood(moodData as Map<dynamic, dynamic>);
        }

        // Clear pending moods
        await _widgetChannel.invokeMethod('clearPendingMoods');

        // Update widget to reflect saved moods
        MoodWidgetService.updateWidget();
      }
    } catch (e) {
      Logger.moodService('❌ Error checking for pending widget moods: $e');
    }
  }

  // Process a pending widget mood selection
  Future<void> _processPendingWidgetMood(Map<dynamic, dynamic> moodData) async {
    try {
      final segment = moodData['segment'] as int;
      final rating = moodData['rating'] as double;
      final timestamp = moodData['timestamp'] as int;

      // Convert timestamp to date
      final moodDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final today = DateTime.now();

      // Only process if it's for today (prevent stale data)
      if (moodDate.day == today.day &&
          moodDate.month == today.month &&
          moodDate.year == today.year) {

        final success = await MoodDataService.saveMood(
            today,
            segment,
            rating,
            'Quick mood from widget (background)'
        );

        if (success) {
          Logger.moodService('✅ Processed pending widget mood: $rating for segment $segment');

          // Show user feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Widget mood saved: ${rating.toStringAsFixed(1)}/10 for ${MoodDataService.timeSegments[segment]}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        Logger.moodService('⚠️ Skipping stale widget mood from ${moodDate.toString()}');
      }
    } catch (e) {
      Logger.moodService('❌ Error processing pending widget mood: $e');
    }
  }

  /// Check if onboarding should be shown
  Future<void> _checkOnboarding() async {
    final shouldShow = await OnboardingService.shouldShowOnboarding();
    if (mounted) {
      setState(() {
        _showOnboarding = shouldShow;
      });

      if (shouldShow) {
        // Show onboarding after a short delay to let UI settle
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showOnboardingFlow();
          }
        });
      } else {
        // Existing user - check for restore and other existing flows
        _checkForCloudRestore();
      }
    }
  }

  /// Show the onboarding flow
  Future<void> _showOnboardingFlow() async {
    if (!mounted) return;

    await OnboardingService.showOnboardingFlow(context);

    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }

  Future<void> _checkForCloudRestore() async {
    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if we should prompt for restore (for existing users)
    await StartupRestoreService.checkAndPromptRestore(context);
  }

  /// Schedule an initial backup check after app startup
  void _scheduleInitialBackupCheck() {
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        if (await RealCloudBackupService.isAutoBackupEnabled()) {
          // Trigger backup if needed (this will check intervals automatically)
          RealCloudBackupService.triggerBackupIfNeeded();
        }
      } catch (e) {
        Logger.backupService('Initial backup check failed: $e');
      }
    });
  }

  @override
  void dispose() {
    // Clean up notification manager
    NotificationManager.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_prefThemeModeKey);
      final customGradient = prefs.getBool(_prefCustomGradientKey);

      if (mounted) {
        setState(() {
          if (themeIndex != null) {
            _themeMode = ThemeMode.values[themeIndex];
          }
          _useCustomGradient = customGradient ?? true;
        });
      }
    } catch (e) {
      Logger.dataService('Error loading preferences: $e');
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefThemeModeKey, mode.index);
      if (mounted) {
        setState(() {
          _themeMode = mode;
        });
      }
    } catch (e) {
      Logger.dataService('Error saving theme mode: $e');
    }
  }

  Future<void> _setUseCustomGradient(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefCustomGradientKey, value);
      if (mounted) {
        setState(() {
          _useCustomGradient = value;
        });
      }
    } catch (e) {
      Logger.dataService('Error saving gradient preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Tracker',
      navigatorKey: NavigationService.navigatorKey,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
      ),
      routes: {
        '/': (context) => MainMenuScreen(
          themeMode: _themeMode,
          useCustomGradient: _useCustomGradient,
          onThemeModeChanged: (ThemeMode? mode) {
            if (mode != null) {
              _setThemeMode(mode);
            }
          },
          onUseCustomGradientChanged: _setUseCustomGradient,
        ),
        '/mood-log': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
          final brightness = _themeMode == ThemeMode.system
              ? MediaQuery.platformBrightnessOf(context)
              : (_themeMode == ThemeMode.dark
              ? Brightness.dark
              : Brightness.light);

          return MoodLogScreen(
            useCustomGradient: _useCustomGradient,
            isDarkMode: brightness == Brightness.dark,
            initialSegment: args?['segment'],
            timeSegment: args?['timeSegment'],
            preSelectedRating: args?['preSelectedRating']?.toDouble(), // NEW: Widget rating
            fromWidget: args?['fromWidget'] as bool?, // NEW: Widget flag
          );
        },
        '/goals': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
          return GoalsScreen(highlightGoalId: args?['goalId']);
        },
        '/correlation': (context) => const CorrelationScreen(),
        '/insights': (context) => const InsightsScreen(),
        '/history': (context) => const MoodHistoryScreen(),
        '/trends': (context) => const MoodTrendsScreen(),
        '/ai-analysis': (context) => const AIAnalysisScreen(),
        '/backup-export': (context) => const BackupExportScreen(),
        '/settings': (context) => SettingsScreen(
          themeMode: _themeMode,
          useCustomGradient: _useCustomGradient,
          onThemeModeChanged: (ThemeMode? mode) {
            if (mode != null) {
              _setThemeMode(mode);
            }
          },
          onUseCustomGradientChanged: _setUseCustomGradient,
        ),
        // Add debug route (only available in debug mode)
        if (kDebugMode)
          '/debug': (context) =>
          kDebugMode ? const DebugDataScreen() : const SizedBox(),
      },
    );
  }
}