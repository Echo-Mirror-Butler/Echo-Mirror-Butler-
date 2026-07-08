import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
final notificationTimeProvider = FutureProvider<({int hour, int minute})>((
  ref,
) async {
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

// ─────────────────────────────────────────────────────────────
// Weekly Digest preference
// ─────────────────────────────────────────────────────────────

/// Reads the weekly_digest opt-in flag from the user's profile.
final weeklyDigestProvider = FutureProvider<bool>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return false;

  final res = await client
      .from('profiles')
      .select('weekly_digest')
      .eq('id', user.id)
      .maybeSingle();

  return (res?['weekly_digest'] as bool?) ?? false;
});

/// Toggles the weekly_digest preference and invalidates the provider.
final weeklyDigestNotifierProvider = Provider<WeeklyDigestNotifier>((ref) {
  return WeeklyDigestNotifier(ref);
});

class WeeklyDigestNotifier {
  final Ref _ref;

  WeeklyDigestNotifier(this._ref);

  Future<void> setEnabled(bool value) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    await client.from('profiles').upsert({
      'id': user.id,
      'weekly_digest': value,
    });

    _ref.invalidate(weeklyDigestProvider);
  }
}
