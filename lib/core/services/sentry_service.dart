import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  SentryService._();

  static bool _initialized = false;

  static Future<void> init({String environment = 'development'}) async {
    if (_initialized) return;

    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment(
          'SENTRY_DSN',
          defaultValue: '',
        );
        options.environment = environment;
        options.tracesSampleRate = environment == 'production' ? 0.2 : 1.0;
        options.debug = kDebugMode;
        options beforeSend = (event, {hint}) {
          // Strip PII — never send email or user metadata
          event.user = null;
          return event;
        };
      },
    );

    _initialized = true;
  }

  static Future<void> captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    if (!_initialized) return;

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: Hint.withMap({
        if (extra != null) 'extra': extra,
      }),
    );
  }

  static void setUserId(String? userId) {
    if (!_initialized) return;

    Sentry.configureScope((scope) {
      scope.setUser(userId != null ? SentryUser(id: userId) : null);
    });
  }
}
