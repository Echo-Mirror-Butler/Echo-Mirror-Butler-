import 'package:flutter/foundation.dart';
import 'sentry_service.dart';

class AppLogger {
  AppLogger._();

  /// Log an error - prints to console and reports to Sentry
  static void error(String label, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$label] ERROR: $error');
    if (stackTrace != null) {
      debugPrint('[$label] $stackTrace');
    }
    SentryService.captureException(
      error,
      stackTrace: stackTrace,
      extra: {'label': label},
    );
  }

  /// Log a warning - prints to console in debug mode
  static void warning(String label, Object message) {
    debugPrint('[$label] WARNING: $message');
  }

  /// Log info - prints to console in debug mode only
  static void info(String label, String message) {
    if (kDebugMode) {
      debugPrint('[$label] INFO: $message');
    }
  }

  /// Log debug information - prints to console in debug mode only
  static void debug(String label, String message) {
    if (kDebugMode) {
      debugPrint('[$label] DEBUG: $message');
    }
  }
}
