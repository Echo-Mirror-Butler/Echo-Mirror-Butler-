import 'package:echomirror/core/constants/environment_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvironmentConfig', () {
    test('defaults to testnet when STELLAR_NETWORK is not set', () {
      // We exercise the compile-time define via a test-only override.
      expect(EnvironmentConfig.isTestnet, isTrue);
      expect(EnvironmentConfig.network, 'testnet');
    });

    test('network getter returns a non-empty identifier', () {
      expect(EnvironmentConfig.network, isNotEmpty);
    });
  });
}
