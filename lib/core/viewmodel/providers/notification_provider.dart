import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';
import '../../../core/routing/app_router.dart';

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
  
  // Set up notification tap callback to navigate to logging
  service.setNotificationTapCallback(() {
    final router = ref.read(routerProvider);
    router.go('/logging/create');
  });
  
  // Reschedule if needed
  await service.rescheduleIfNeeded();
});

