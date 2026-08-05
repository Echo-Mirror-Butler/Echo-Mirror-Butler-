import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Represents the OS-level notification permission state.
enum NotificationPermissionStatus {
  /// Not yet determined — user has never been asked.
  notDetermined,

  /// The user explicitly granted permission.
  granted,

  /// The user explicitly denied permission (can be re-requested on Android;
  /// must go to OS settings on iOS after first denial).
  denied,

  /// The user denied and selected "Don't ask again" (Android), or has denied
  /// more than once on iOS — the system will no longer show the dialog.
  permanentlyDenied,

  /// Permission is restricted by parental controls / MDM (iOS only).
  restricted,
}

/// Service that wraps [permission_handler] to provide a cross-platform API for
/// checking, requesting, and acting on OS-level notification permissions.
///
/// This is intentionally separate from [NotificationService] (which handles
/// scheduling) so that UI layers can depend on permission state without
/// importing flutter_local_notifications.
class NotificationPermissionService {
  // Singleton
  static final NotificationPermissionService _instance =
      NotificationPermissionService._internal();
  factory NotificationPermissionService() => _instance;
  NotificationPermissionService._internal();

  /// Returns the current OS-level notification permission status without
  /// showing any dialog. Safe to call frequently (e.g., on app resume).
  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    try {
      final status = await Permission.notification.status;
      return _mapStatus(status);
    } catch (e) {
      debugPrint('[NotificationPermissionService] checkPermissionStatus: $e');
      // On platforms where permission_handler is not fully supported (e.g.
      // macOS desktop) we optimistically return granted.
      return NotificationPermissionStatus.granted;
    }
  }

  /// Requests OS notification permission.
  ///
  /// - If already [granted] or [restricted], returns immediately without a
  ///   dialog.
  /// - If [permanentlyDenied], opens OS App Settings instead of showing the
  ///   dialog (the system won't show it anyway).
  /// - Returns the resulting [NotificationPermissionStatus].
  Future<NotificationPermissionStatus> requestPermission() async {
    try {
      final current = await checkPermissionStatus();
      if (current == NotificationPermissionStatus.granted ||
          current == NotificationPermissionStatus.restricted) {
        return current;
      }

      if (current == NotificationPermissionStatus.permanentlyDenied) {
        await openAppSettings();
        // Re-check after returning from settings; user may have toggled it on.
        return await checkPermissionStatus();
      }

      final result = await Permission.notification.request();
      return _mapStatus(result);
    } catch (e) {
      debugPrint('[NotificationPermissionService] requestPermission: $e');
      return NotificationPermissionStatus.denied;
    }
  }

  /// Convenience: returns true only if the OS has granted notification
  /// permission (i.e., [NotificationPermissionStatus.granted]).
  Future<bool> isPermissionGranted() async {
    final status = await checkPermissionStatus();
    return status == NotificationPermissionStatus.granted;
  }

  /// Opens the OS App Settings page for this app, where the user can toggle
  /// notification permission (and other settings).
  ///
  /// Works on both Android and iOS. Returns `true` if the settings page was
  /// successfully opened.
  Future<bool> openOsAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('[NotificationPermissionService] openOsAppSettings: $e');
      return false;
    }
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  NotificationPermissionStatus _mapStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited: // iOS limited (photos-style) — treat as granted
        return NotificationPermissionStatus.granted;

      case PermissionStatus.denied:
        return NotificationPermissionStatus.denied;

      case PermissionStatus.permanentlyDenied:
        return NotificationPermissionStatus.permanentlyDenied;

      case PermissionStatus.restricted:
        return NotificationPermissionStatus.restricted;

      case PermissionStatus.provisional:
        // iOS provisional — alerts appear quietly in Notification Centre.
        // Treat as granted so reminders still fire.
        return NotificationPermissionStatus.granted;
    }
  }
}
