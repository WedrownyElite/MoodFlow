// Copyright (c) 2025 OddologyInc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_menu_screen.dart';
import 'screens/mood_log_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/mood_history_screen.dart';
import 'screens/mood_trends_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/backup_export_screen.dart';
import 'screens/ai_analysis_screen.dart';
import 'services/notification_manager.dart';
import 'services/data/enhanced_notification_service.dart';
import 'services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await EnhancedNotificationService.initialize();

  runApp(const MoodTrackerApp());
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
  }

  @override
  void dispose() {
    // Clean up notification manager
    NotificationManager.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_prefThemeModeKey);
    final customGradient = prefs.getBool(_prefCustomGradientKey);

    setState(() {
      if (themeIndex != null) {
        _themeMode = ThemeMode.values[themeIndex];
      }
      _useCustomGradient = customGradient ?? true;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefThemeModeKey, mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _setUseCustomGradient(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCustomGradientKey, value);
    setState(() {
      _useCustomGradient = value;
    });
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
      },
    );
  }
}