import 'package:flutter/foundation.dart';
import 'sentry_service.dart';

class AppLogger {
  AppLogger._();

  static void error(
    String label,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    debugPrint('[$label] $error');
    if (stackTrace != null) {
      debugPrint('[$label] $stackTrace');
    }
    SentryService.captureException(
      error,
      stackTrace: stackTrace,
      extra: {'label': label},
    );
  }

  static void warning(String label, Object message) {
    debugPrint('[$label] $message');
  }
}
