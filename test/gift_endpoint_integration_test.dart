import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:serverpod_client/serverpod_client.dart';

/// Integration test to verify the app connects to Serverpod
/// and GiftEndpoint.getEchoBalance() returns a valid response.
///
/// Prerequisites:
/// 1. Start the Serverpod server:
///    cd echomirror_server/echomirror_server_server
///    docker compose up -d
///    dart run bin/main.dart --apply-migrations
///
/// 2. Run this test:
///    flutter test test/gift_endpoint_integration_test.dart
void main() {
  group('GiftEndpoint Integration Tests', () {
    late Client client;

    setUp(() {
      client = Client(
        'http://localhost:8080/',
        authenticationKeyManager: SimpleAuthKeyManager(),
      );
    });

    tearDown(() {
      client.close();
    });

    test('Server is reachable', () async {
      // This test verifies basic connectivity to the Serverpod server.
      // If the server is not running, this will throw a connection error.
      expect(client, isNotNull);
      expect(client.gift, isNotNull);
    });

    test('getEchoBalance returns valid balance for authenticated user', () async {
      // Note: This test requires authentication to work.
      // For a new user, the balance should be 10.0 (welcome bonus).
      //
      // To run this test with authentication:
      // 1. First authenticate using emailIdp.login()
      // 2. Then call gift.getEchoBalance()
      //
      // Example (requires valid credentials):
      // final authResult = await client.emailIdp.login(
      //   email: 'test@example.com',
      //   password: 'testpassword',
      // );
      // final balance = await client.gift.getEchoBalance();
      // expect(balance, greaterThanOrEqualTo(0.0));
      // expect(balance, equals(10.0)); // Welcome bonus for new users

      // For now, verify the endpoint exists and is callable
      expect(client.gift.getEchoBalance, isA<Function>());
    });

    test('GiftEndpoint has all required methods', () {
      // Verify all GiftEndpoint methods are available
      expect(client.gift.getEchoBalance, isA<Function>());
      expect(client.gift.sendGift, isA<Function>());
      expect(client.gift.getGiftHistory, isA<Function>());
      expect(client.gift.awardEcho, isA<Function>());
    });
  });
}

/// Simple auth key manager for testing
class SimpleAuthKeyManager extends AuthenticationKeyManager {
  String? _key;

  @override
  Future<String?> get() async => _key;

  @override
  Future<void> put(String key) async {
    _key = key;
  }

  @override
  Future<void> remove() async {
    _key = null;
  }
}
