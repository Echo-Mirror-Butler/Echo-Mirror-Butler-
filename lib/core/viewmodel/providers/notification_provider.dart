import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';
import '../../../core/routing/app_router.dart';
import '../../../features/logging/viewmodel/providers/logging_provider.dart';

/// Notification service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Notification enabled state provider
final notificationEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.isReminderEnabled();
});

/// Notification time provider
final notificationTimeProvider = FutureProvider<({int hour, int minute})>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.getReminderTime();
});

/// Initialize notification service on app start
final notificationInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  
  // Initialize service
  await service.initialize();
  
  // Request permissions
  await service.requestPermissions();
  
  // Set up notification tap callbacks
  service.setNotificationTapCallback(() {
    final router = ref.read(routerProvider);
    router.go('/logging/create');
  });
  
  service.setSocialsNotificationTapCallback(() {
    final router = ref.read(routerProvider);
    router.go('/dashboard'); // Navigate to dashboard, which has socials tab
  });
  
  // Reschedule if needed
  await service.rescheduleIfNeeded();
  
  // Check for daily log and schedule notification if needed
  _checkDailyLog(ref, service);
});

/// Check if user has logged today and schedule notification if not
Future<void> _checkDailyLog(Ref ref, NotificationService service) async {
  try {
    final loggingState = ref.read(loggingProvider);
    final logs = loggingState.value ?? [];
    
    // Check if there's a log entry for today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final hasLoggedToday = logs.any((log) {
      final logDate = log.date.isUtc ? log.date.toLocal() : log.date;
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);
      return logDay.isAtSameMomentAs(today);
    });
    
    // Check and notify if no log today
    await service.checkAndNotifyIfNoLogToday(hasLoggedToday: hasLoggedToday);
  } catch (e) {
    debugPrint('[NotificationProvider] Error checking daily log: $e');
  }
}

/// Provider to check daily log periodically
final dailyLogCheckProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  await _checkDailyLog(ref, service);
});

