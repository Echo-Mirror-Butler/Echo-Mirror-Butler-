import 'package:echomirror/features/global_mirror/data/services/stellar/stellar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class MockStellarSDK extends Mock implements StellarSDK {}

class MockAccountsResponseBuilder extends Mock
    implements AccountsResponseBuilder {}

void main() {
  group('StellarService.getLiveBalances', () {
    // Both '_' and 'native' are valid assetType values returned by Horizon.
    const tNative = 'native';
    const tCredit = 'credit_alphanum4';

    late MockStellarSDK sdk;
    late MockAccountsResponseBuilder accounts;

    Balance nativeBalance(double amount) => _FakeBalance(
          assetType: tNative,
          balance: amount.toString(),
        );

    Balance echoBalance(double amount, {String? issuer}) => _FakeBalance(
          assetType: tCredit,
          assetCode: 'ECHO',
          assetIssuer: issuer ?? _testIssuer,
          balance: amount.toString(),
        );

    setUp(() {
      sdk = MockStellarSDK();
      accounts = MockAccountsResponseBuilder();
      when(() => sdk.accounts).thenReturn(accounts);
    });

    test('returns XLM and ECHO balances for a funded wallet', () async {
      final account = _FakeAccountResponse(
        balances: [
          nativeBalance(12.5),
          echoBalance(45.0),
        ],
      );
      when(() => accounts.account(any())).thenAnswer((_) async => account);

      final result = await StellarService.getLiveBalances(
        _testPublicKey,
        sdk: sdk,
      );

      expect(result.xlm, 12.5);
      expect(result.echo, 45.0);
      expect(result.isFunded, isTrue);
      expect(result.publicKey, _testPublicKey);
    });

    test('returns xlm=0 and isFunded=false for an empty funded wallet',
        () async {
      final account = _FakeAccountResponse(balances: [nativeBalance(0.0)]);
      when(() => accounts.account(any())).thenAnswer((_) async => account);

      final result = await StellarService.getLiveBalances(
        _testPublicKey,
        sdk: sdk,
      );

      expect(result.xlm, 0.0);
      expect(result.echo, 0.0);
      expect(result.isFunded, isFalse);
    });

    test('throws AccountNotFoundException when Horizon returns 404',
        () async {
      when(() => accounts.account(any())).thenThrow(
        Exception('HTTP 404: Account Not Found'),
      );

      await expectLater(
        StellarService.getLiveBalances(_testPublicKey, sdk: sdk),
        throwsA(isA<AccountNotFoundException>()),
      );
    });

    test('throws AccountNotFoundException when message says "not found"',
        () async {
      when(() => accounts.account(any())).thenThrow(
        Exception('Resource not found'),
      );

      await expectLater(
        StellarService.getLiveBalances(_testPublicKey, sdk: sdk),
        throwsA(isA<AccountNotFoundException>()),
      );
    });

    test('rethrows non-404 errors so the caller can surface them', () async {
      when(() => accounts.account(any())).thenThrow(
        Exception('Connection refused'),
      );

      await expectLater(
        StellarService.getLiveBalances(_testPublicKey, sdk: sdk),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Connection refused'),
          ),
        ),
      );
    });

    test('uses issuer from environment when matching ECHO balance', () async {
      final customIssuer =
          'GCUSTOMISSUERPUBLICBUSTOMATCHECHOBALANCEONHORIZON1234567';
      final account = _FakeAccountResponse(
        balances: [
          nativeBalance(10.0),
          echoBalance(7.0, issuer: customIssuer),
        ],
      );
      when(() => accounts.account(any())).thenAnswer((_) async => account);

      // Without overriding the issuer, this ECHO balance should NOT match.
      final wrongIssuerResult = await StellarService.getLiveBalances(
        _testPublicKey,
        sdk: sdk,
      );
      expect(wrongIssuerResult.echo, 0.0);

      // With the right issuer, it should match.
      final rightIssuerResult = await StellarService.getLiveBalances(
        _testPublicKey,
        sdk: sdk,
        issuerPublicKey: customIssuer,
      );
      expect(rightIssuerResult.echo, 7.0);
    });

    test('LiveAccountBalances.isFunded mirrors xlm > 0', () {
      expect(
        const LiveAccountBalances(
          publicKey: 'G',
          xlm: 0,
          echo: 0,
        ).isFunded,
        isFalse,
      );
      expect(
        const LiveAccountBalances(
          publicKey: 'G',
          xlm: 0.0001,
          echo: 0,
        ).isFunded,
        isTrue,
      );
    });
  });
}

const _testIssuer =
    'GISSUERPUBLICBUTTONOTBEUSEDINREALENVIRONMENTSEEDFORUNITTEST';
const _testPublicKey =
    'GTESTPUBLICKEYABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJ';

class _FakeAccountResponse extends Fake implements AccountResponse {
  _FakeAccountResponse({required this.balances});

  final List<Balance> balances;

  @override
  List<Balance> get balancesValue => balances;

  @override
  String get accountId => _testPublicKey;
}

class _FakeBalance extends Fake implements Balance {
  _FakeBalance({
    required this.assetType,
    this.assetCode,
    this.assetIssuer,
    required this.balance,
  });

  @override
  final String assetType;
  @override
  final String? assetCode;
  @override
  final String? assetIssuer;
  @override
  final String balance;
}
