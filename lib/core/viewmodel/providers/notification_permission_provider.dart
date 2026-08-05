import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_permission_service.dart';

export '../../services/notification_permission_service.dart'
    show NotificationPermissionStatus;

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Provides a [NotificationPermissionService] instance (injectable for tests).
final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>((ref) {
  return NotificationPermissionService();
});

/// Holds the current OS-level notification permission status and refreshes it
/// whenever the user returns to the foreground (via [WidgetsBindingObserver]).
///
/// Consumers should watch this to decide whether to show the permission banner
/// or disable notification-related UI.
final notificationPermissionProvider = AsyncNotifierProvider<
    NotificationPermissionNotifier, NotificationPermissionStatus>(
  NotificationPermissionNotifier.new,
);

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Lifecycle-aware notifier that re-checks permission on each app resume.
class NotificationPermissionNotifier
    extends AsyncNotifier<NotificationPermissionStatus>
    with WidgetsBindingObserver {
  late NotificationPermissionService _service;

  @override
  Future<NotificationPermissionStatus> build() async {
    _service = ref.read(notificationPermissionServiceProvider);

    // Register for lifecycle events so we re-check when the user comes back
    // from OS Settings (where they may have toggled the permission).
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));

    return await _service.checkPermissionStatus();
  }

  // ─── WidgetsBindingObserver ──────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User may have just changed notification settings in OS → re-query.
      refresh();
    }
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Re-queries the OS permission status and updates state.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.checkPermissionStatus(),
    );
  }

  /// Requests OS notification permission (may show the system dialog).
  ///
  /// If the permission is permanently denied, this opens OS App Settings
  /// instead.  After the user returns from settings the status is re-queried
  /// automatically via [didChangeAppLifecycleState].
  Future<void> requestPermission() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.requestPermission(),
    );
  }

  /// Opens OS App Settings for this app without requesting permission again.
  Future<void> openOsSettings() async {
    await _service.openOsAppSettings();
    // Status refresh happens via didChangeAppLifecycleState on resume.
  }
}
