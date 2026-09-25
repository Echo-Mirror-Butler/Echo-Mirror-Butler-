import 'package:echomirror/core/services/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger', () {
    test('error does not throw when Sentry is not initialized', () {
      expect(
        () => AppLogger.error('TestLabel', Exception('Test error')),
        returnsNormally,
      );
    });

    test('error with stack trace does not throw', () {
      expect(
        () => AppLogger.error(
          'TestLabel',
          Exception('Test error'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('warning does not throw', () {
      expect(
        () => AppLogger.warning('TestLabel', 'Test warning'),
        returnsNormally,
      );
    });

    test('info does not throw', () {
      expect(
        () => AppLogger.info('TestLabel', 'Test info'),
        returnsNormally,
      );
    });

    test('debug does not throw', () {
      expect(
        () => AppLogger.debug('TestLabel', 'Test debug'),
        returnsNormally,
      );
    });
  });
}
