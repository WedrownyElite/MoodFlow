import 'package:flutter/material.dart';
import '../services/animation/blur_transition_service.dart';
import '../services/animation/scale_transition_service.dart';
import '../services/data/enhanced_notification_service.dart';
import '../widgets/notification_permission_dialog.dart';
import 'mood_log_screen.dart';
import 'mood_trends_screen.dart';
import 'mood_history_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final bool useCustomGradient;
  final ValueChanged<ThemeMode?> onThemeModeChanged;
  final ValueChanged<bool> onUseCustomGradientChanged;

  const MainMenuScreen({
    super.key,
    required this.themeMode,
    required this.useCustomGradient,
    required this.onThemeModeChanged,
    required this.onUseCustomGradientChanged,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with TickerProviderStateMixin {
  late BlurTransitionService _blurService;

  @override
  void initState() {
    super.initState();
    _blurService = BlurTransitionService(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Faster for menu navigation
    );
    
    // Check for notification permission on app start
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final shouldAsk = await EnhancedNotificationService.shouldAskForPermission();
    if (shouldAsk) {
      _showNotificationPermissionDialog();
    }
  }

  Future<void> _showNotificationPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NotificationPermissionDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Notifications enabled! You\'ll get helpful reminders.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _blurService.dispose();
    super.dispose();
  }

  LinearGradient _getBackgroundGradient(BuildContext context) {
    final brightness = widget.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context)
        : (widget.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);

    return brightness == Brightness.dark
        ? const LinearGradient(colors: [Colors.black87, Colors.grey])
        : const LinearGradient(colors: [Colors.blueAccent, Colors.lightBlueAccent]);
  }

  Future<void> _navigateWithBlur(Widget destination) async {
    if (_blurService.isTransitioning) return;

    await _blurService.executeTransition(() async {
      // Navigate while screen is blurred
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionDuration: Duration.zero, // No additional transition
          reverseTransitionDuration: Duration.zero,
        ),
      );
    });
  }

  void _navigateWithScale(Widget destination) {
    Navigator.push(
      context,
      ScaleTransitionService.createScaleRoute(destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getBackgroundGradient(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: BlurTransitionWidget(
            blurService: _blurService,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Mood Tracker',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Log Mood'),
                    onPressed: _blurService.isTransitioning ? null : () {
                      final brightness = widget.themeMode == ThemeMode.system
                          ? MediaQuery.platformBrightnessOf(context)
                          : (widget.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);

                      _navigateWithBlur(
                        MoodLogScreen(
                          useCustomGradient: widget.useCustomGradient,
                          isDarkMode: brightness == Brightness.dark,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.flag),
                    label: const Text('Goals'),
                    onPressed: _blurService.isTransitioning ? null : () {
                      _navigateWithBlur(const GoalsScreen());
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('View History'),
                    onPressed: _blurService.isTransitioning ? null : () {
                      _navigateWithBlur(const MoodHistoryScreen());
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.show_chart),
                    label: const Text('View Trends'),
                    onPressed: _blurService.isTransitioning ? null : () {
                      _navigateWithBlur(const MoodTrendsScreen());
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Settings'),
                    onPressed: () {
                      _navigateWithScale(
                        SettingsScreen(
                          themeMode: widget.themeMode,
                          useCustomGradient: widget.useCustomGradient,
                          onThemeModeChanged: widget.onThemeModeChanged,
                          onUseCustomGradientChanged: widget.onUseCustomGradientChanged,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}