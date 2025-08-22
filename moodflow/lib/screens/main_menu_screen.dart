import 'package:flutter/material.dart';
import '../services/animation/blur_transition_service.dart';
import '../services/animation/scale_transition_service.dart';
import '../services/notifications/enhanced_notification_service.dart';
import '../widgets/notification_permission_dialog.dart';
import 'mood_log_screen.dart';
import 'mood_trends_screen.dart';
import 'mood_history_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'ai_analysis_screen.dart';
import 'backup_export_screen.dart';
import '../services/backup/startup_restore_service.dart';

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
      duration: const Duration(milliseconds: 300),
    );

    // Check for notification permission on app start
    _checkNotificationPermission();

    // ADDED: Check for cloud backup restore on app start
    _checkForCloudRestore();
  }

  Future<void> _checkForCloudRestore() async {
    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if we should prompt for restore
    await StartupRestoreService.checkAndPromptRestore(context);
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
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionDuration: Duration.zero,
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
                children: [
                  // Primary action - larger, prominent
                  _buildPrimaryButton(
                    'Log Mood',
                    Icons.edit_note,
                        () => _navigateToMoodLog(),
                  ),

                  const SizedBox(height: 24),

                  // Quick access grid (2x2)
                  Row(
                    children: [
                      Expanded(child: _buildQuickButton('History', Icons.history, () => _navigateWithBlur(const MoodHistoryScreen()))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickButton('Trends', Icons.show_chart, () => _navigateWithBlur(const MoodTrendsScreen()))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildQuickButton('Goals', Icons.flag, () => _navigateWithBlur(const GoalsScreen()))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickButton('AI Analysis', Icons.psychology, () => _navigateWithBlur(const AIAnalysisScreen()))),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Secondary actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSecondaryButton('Backup', Icons.cloud_upload, () => _navigateWithBlur(const BackupExportScreen())),
                      _buildSecondaryButton('Settings', Icons.settings, () => _navigateWithScale(
                        SettingsScreen(
                          themeMode: widget.themeMode,
                          useCustomGradient: widget.useCustomGradient,
                          onThemeModeChanged: widget.onThemeModeChanged,
                          onUseCustomGradientChanged: widget.onUseCustomGradientChanged,
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToMoodLog() async {
    if (_blurService.isTransitioning) return;

    final brightness = widget.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context)
        : (widget.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);

    await _blurService.executeTransition(() async {
      Navigator.pushNamed(
        context,
        '/mood-log',
        arguments: {
          'useCustomGradient': widget.useCustomGradient,
          'isDarkMode': brightness == Brightness.dark,
        },
      );
    });
  }
  
  Widget _buildPrimaryButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, IconData icon, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}