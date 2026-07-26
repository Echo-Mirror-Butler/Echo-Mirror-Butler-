import 'package:echomirror/features/global_mirror/data/services/stellar/stellar_config.dart';
import 'package:echomirror/features/global_mirror/data/services/stellar/stellar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  group('StellarService (unit)', () {
    late MockHttpClient httpClient;

    setUpAll(() {
      registerFallbackValue(FakeUri());
    });

    setUp(() {
      httpClient = MockHttpClient();
    });

    test('createWallet funds via Friendbot and returns a keypair', () async {
      when(
        () => httpClient.get(any()),
      ).thenAnswer((invocation) async => http.Response('{}', 200));

      final keypair = await StellarService.createWallet(httpClient: httpClient);

      expect(keypair.accountId, startsWith('G'));
      expect(keypair.secretSeed, startsWith('S'));

      final captured = verify(() => httpClient.get(captureAny())).captured;
      expect(captured, hasLength(1));
      final uri = captured.single as Uri;
      expect(uri.toString(), startsWith(StellarConfig.friendbotUrl));
      expect(uri.toString(), contains('addr=${keypair.accountId}'));
    });

    test('createWallet throws when Friendbot funding fails', () async {
      when(
        () => httpClient.get(any()),
      ).thenAnswer((_) async => http.Response('nope', 500));

      expect(
        () => StellarService.createWallet(httpClient: httpClient),
        throwsA(isA<Exception>()),
      );
    });

    test('fundWithFriendbot hits Friendbot for the supplied public key',
        () async {
      const targetKey = 'GTESTTARGETPUBLICKEYABCDEFGHIJKLMNOPQRSTUVWXYZ1234';
      when(
        () => httpClient.get(any()),
      ).thenAnswer((_) async => http.Response('{}', 200));

      await StellarService.fundWithFriendbot(targetKey, httpClient: httpClient);

      final captured = verify(() => httpClient.get(captureAny())).captured;
      expect(captured, hasLength(1));
      expect(
        (captured.single as Uri).toString(),
        '${StellarConfig.friendbotUrl}?addr=$targetKey',
      );
    });

    test('fundWithFriendbot throws when Friendbot returns non-200',
        () async {
      when(
        () => httpClient.get(any()),
      ).thenAnswer((_) async => http.Response('unavailable', 503));

      await expectLater(
        StellarService.fundWithFriendbot(
          'GALREADYCREATEDPUBLICKEYABCDEFGHIJKLMNOPQRSTUVWXYZ12',
          httpClient: httpClient,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'establishTrustline returns false when issuer is not configured',
      () async {
        final ok = await StellarService.establishTrustline(
          'SXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
          issuerPublicKey: '',
        );
        expect(ok, isFalse);
      },
    );

    test('sendEcho returns null when issuer is not configured', () async {
      final tx = await StellarService.sendEcho(
        senderSecret:
            'SXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        recipientPublicKey:
            'GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        amount: 1.0,
        issuerPublicKey: '',
      );
      expect(tx, isNull);
    });

    test('getEchoBalance returns 0.0 when issuer is not configured', () async {
      final balance = await StellarService.getEchoBalance(
        'GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        issuerPublicKey: '',
      );
      expect(balance, 0.0);
    });
  });
}
