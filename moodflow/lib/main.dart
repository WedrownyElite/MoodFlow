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
import 'services/notification_manager.dart';
import 'services/data/enhanced_notification_service.dart';
import 'services/navigation_service.dart';
import 'services/backup/cloud_backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await EnhancedNotificationService.initialize();

  // Initialize REAL cloud backup system (not local auto backup)
  if (await RealCloudBackupService.isCloudBackupAvailable()) {
    print('✅ Real cloud backup system is available');

    // Always enable cloud backup for new installations
    await RealCloudBackupService.setAutoBackupEnabled(true);
    print('🔧 Cloud backup enabled');

    // Check for existing cloud backups on startup for auto-restore
    await RealCloudBackupService.checkForRestoreOnStartup();
  } else {
    print('❌ Real cloud backup system is not available on this platform');
  }

  runApp(const MoodTrackerApp());
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
    _loadPreferences();

    // Initialize notification manager
    NotificationManager.initialize();

    // Trigger initial backup check (delayed to not slow down app startup)
    _scheduleInitialBackupCheck();
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

      setState(() {
        if (themeIndex != null) {
          _themeMode = ThemeMode.values[themeIndex];
        }
        _useCustomGradient = customGradient ?? true;
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefThemeModeKey, mode.index);
      setState(() {
        _themeMode = mode;
      });
    } catch (e) {
      print('Error saving theme mode: $e');
    }
  }

  Future<void> _setUseCustomGradient(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefCustomGradientKey, value);
      setState(() {
        _useCustomGradient = value;
      });
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
          '/debug': (context) => const DebugDataScreen(),
      },
    );
  }
}