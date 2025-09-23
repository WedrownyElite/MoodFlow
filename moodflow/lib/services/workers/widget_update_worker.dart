import 'package:workmanager/workmanager.dart';
import '../widgets/mood_widget_service.dart';
import '../utils/logger.dart';

class WidgetUpdateWorker {
  static const String _updateTaskName = 'widget_daily_update';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await scheduleUpdates();
  }

  static Future<void> scheduleUpdates() async {
    await Workmanager().registerPeriodicTask(
      _updateTaskName,
      _updateTaskName,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await MoodWidgetService.updateWidget();
      return Future.value(true);
    } catch (e) {
      Logger.moodService('❌ Widget background update failed: $e');
      return Future.value(false);
    }
  });
}