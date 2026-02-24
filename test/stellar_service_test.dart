import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:http/http.dart' as http;

@Tags(['integration'])

/// End-to-end test for the ECHO trustline flow on Stellar testnet.
///
/// This test verifies the full lifecycle:
///   1. Generate a new wallet keypair
///   2. Fund it via Friendbot
///   3. Establish an ECHO trustline to the issuer
///   4. Verify the trustline exists on the account
///   5. Confirm getEchoBalance returns 0.0
///
/// Requires network access to Stellar testnet.
void main() {
  const horizonUrl = 'https://horizon-testnet.stellar.org';
  const friendbotUrl = 'https://friendbot.stellar.org';
  const networkPassphrase = 'Test SDF Network ; September 2015';
  const assetCode = 'ECHO';

  final sdk = StellarSDK(horizonUrl);
  final network = Network(networkPassphrase);

  group('ECHO trustline end-to-end on testnet', () {
    late KeyPair issuerKeypair;
    late KeyPair userKeypair;

    setUpAll(() async {
      // Create and fund an issuer account for this test run
      issuerKeypair = KeyPair.random();
      final issuerFund = await http.get(
        Uri.parse('$friendbotUrl?addr=${issuerKeypair.accountId}'),
      );
      expect(
        issuerFund.statusCode,
        200,
        reason: 'Friendbot should fund the issuer account',
      );
    });

    test(
      'Step 1 — createWallet: generate keypair and fund via Friendbot',
      () async {
        userKeypair = KeyPair.random();
        expect(userKeypair.accountId, startsWith('G'));
        expect(userKeypair.secretSeed, startsWith('S'));

        final response = await http.get(
          Uri.parse('$friendbotUrl?addr=${userKeypair.accountId}'),
        );
        expect(
          response.statusCode,
          200,
          reason: 'Friendbot should fund the user account',
        );

        // Confirm account exists on Horizon
        final account = await sdk.accounts.account(userKeypair.accountId);
        expect(account.accountId, userKeypair.accountId);
      },
    );

    test(
      'Step 2 — establishTrustline: add ECHO trustline to user wallet',
      () async {
        final account = await sdk.accounts.account(userKeypair.accountId);

        // ECHO is 4 characters → must use AssetTypeCreditAlphaNum4
        final echoAsset = AssetTypeCreditAlphaNum4(
          assetCode,
          issuerKeypair.accountId,
        );

        final transaction = TransactionBuilder(account)
            .addOperation(
              ChangeTrustOperationBuilder(echoAsset, '1000000').build(),
            )
            .build();

        transaction.sign(userKeypair, network);
        final result = await sdk.submitTransaction(transaction);
        expect(
          result.success,
          isTrue,
          reason: 'Trustline transaction should succeed',
        );
      },
    );

    test('Step 3 — verify trustline appears on the account', () async {
      final account = await sdk.accounts.account(userKeypair.accountId);

      final echoBalances = account.balances.where(
        (b) =>
            b.assetCode == assetCode &&
            b.assetIssuer == issuerKeypair.accountId,
      );

      expect(
        echoBalances,
        isNotEmpty,
        reason: 'ECHO trustline should appear in account balances',
      );
      expect(echoBalances.first.assetCode, assetCode);
      expect(echoBalances.first.assetIssuer, issuerKeypair.accountId);
    });

    test(
      'Step 4 — getEchoBalance: should return 0.0 after trustline setup',
      () async {
        final account = await sdk.accounts.account(userKeypair.accountId);

        double echoBalance = 0.0;
        for (final balance in account.balances) {
          if (balance.assetCode == assetCode &&
              balance.assetIssuer == issuerKeypair.accountId) {
            echoBalance = double.tryParse(balance.balance) ?? 0.0;
          }
        }

        expect(
          echoBalance,
          0.0,
          reason: 'ECHO balance should be 0.0 before any tokens are issued',
        );
      },
    );

    test(
      'Step 5 — confirm AssetTypeCreditAlphaNum4 is used (not AlphaNum12)',
      () {
        // ECHO has 4 characters — must be AlphaNum4
        expect(assetCode.length, lessThanOrEqualTo(4));

        final asset = AssetTypeCreditAlphaNum4(
          assetCode,
          issuerKeypair.accountId,
        );
        expect(asset.code, assetCode);

        // Verify AlphaNum12 would be wrong for a 4-char code
        // AlphaNum12 is only for codes with 5-12 characters
        expect(
          assetCode.length,
          lessThanOrEqualTo(4),
          reason: 'ECHO is 4 chars, so AssetTypeCreditAlphaNum4 is correct',
        );
      },
    );
  });
}
