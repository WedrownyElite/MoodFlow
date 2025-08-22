// Copyright (c) 2025 OddologyInc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    print('🔄 Initializing notification services...');
    await EnhancedNotificationService.initialize();
    print('✅ Notification services initialized');

    // 2. Initialize notification manager
    NotificationManager.initialize();
    print('✅ Notification manager initialized');

    // 3. Initialize MoodDataService
    await MoodDataService.initialize();
    print('✅ MoodDataService initialized');

    // 4. Initialize cloud backup services
    await _initializeCloudBackup();

  } catch (e) {
    print('❌ Error during service initialization: $e');
    // Continue with app launch even if some services fail
  }
}

/// Initialize cloud backup with proper error handling
Future<void> _initializeCloudBackup() async {
  try {
    if (kDebugMode) {
      if (await RealCloudBackupService.isCloudBackupAvailable()) {
        print('✅ Real cloud backup system is available');
        await RealCloudBackupService.setAutoBackupEnabled(true);
        print('🔧 Cloud backup enabled');
        await RealCloudBackupService.checkForRestoreOnStartup();
        print('✅ Cloud backup initialization complete');
      } else {
        print('❌ Real cloud backup system is not available on this platform');
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
        print('⚠️ Cloud backup initialization failed silently: $e');
      }
    }
  } catch (e) {
    print('❌ Cloud backup initialization error: $e');
  }
}

/// Check if the user has existing mood data (not a fresh install)
Future<bool> _hasExistingData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final moodKeys = allKeys.where((key) => key.startsWith('mood_')).toList();
    return moodKeys.isNotEmpty;
  } catch (e) {
    print('Error checking existing data: $e');
    return false;
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

  static const _prefThemeModeKey = 'theme_mode';
  static const _prefCustomGradientKey = 'use_custom_gradient';

  @override
  void initState() {
    super.initState();

    // Load preferences after a short delay to ensure everything is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      _loadPreferences();
      _scheduleInitialBackupCheck();
    });
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
        print('Initial backup check failed: $e');
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
      print('Error loading preferences: $e');
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
      print('Error saving theme mode: $e');
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
      print('Error saving gradient preference: $e');
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
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final brightness = _themeMode == ThemeMode.system
              ? MediaQuery.platformBrightnessOf(context)
              : (_themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);

          return MoodLogScreen(
            useCustomGradient: _useCustomGradient,
            isDarkMode: brightness == Brightness.dark,
            initialSegment: args?['segment'],
            timeSegment: args?['timeSegment'],
          );
        },
        '/goals': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return GoalsScreen(highlightGoalId: args?['goalId']);
        },
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
          '/debug': (context) => kDebugMode ? const DebugDataScreen() : const SizedBox(),
      },
    );
  }
}