import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/modules/memory/controllers/memory_controller.dart';
import 'package:super_up_core/super_up_core.dart';

class MemoryNotificationService {
  static MemoryNotificationService? _instance;
  static MemoryNotificationService get instance {
    _instance ??= MemoryNotificationService._();
    return _instance!;
  }

  MemoryNotificationService._();

  Timer? _reminderTimer;
  final _memoryController = GetIt.I.get<MemoryController>();

  void startReminderService() {
    // Check for reminders every hour
    _reminderTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkForReminders();
    });

    // Also check immediately when service starts
    _checkForReminders();
  }

  void stopReminderService() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }

  Future<void> _checkForReminders() async {
    try {
      await _memoryController.getTodayReminders();

      final reminders = _memoryController.data.todayReminders;

      if (reminders.isNotEmpty) {
        _showReminderNotification(reminders.length);
      }
    } catch (e) {
      print('Error checking for memory reminders: $e');
    }
  }

  void _showReminderNotification(int count) {
    final message = count == 1
        ? 'You have a memory from this day!'
        : 'You have $count memories from this day!';

    // Show a simple toast notification
    // In a real app, you would use a proper notification plugin like flutter_local_notifications
    VAppAlert.showSuccessSnackBarWithoutContext(
      message: message,
      duration: const Duration(seconds: 5),
    );
  }

  // Method to manually trigger reminder check (useful for testing)
  Future<void> checkRemindersNow() async {
    await _checkForReminders();
  }
}
