@Tags(['integration'])
library echo_gift_integration_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:echomirror/features/global_mirror/data/services/stellar/echo_token.dart';
import 'package:echomirror/features/global_mirror/data/services/stellar/stellar_service.dart';

/// Integration test for the ECHO gift flow on Stellar testnet.
///
/// Hits the real testnet - takes ~30s.
/// Requires the issuer's credentials to be provided for initial funding.
void main() {
  const horizonUrl = 'https://horizon-testnet.stellar.org';
  const networkPassphrase = 'Test SDF Network ; September 2015';

  final sdk = StellarSDK(horizonUrl);
  final network = Network(networkPassphrase);

  // Load the issuer secret from the environment used to fund wallet A
  const issuerSecret = String.fromEnvironment('STELLAR_ISSUER_SECRET');

  group('ECHO Gift Integration Test', () {
    test(
      'Send 5 ECHO gift between two testnet wallets',
      () async {
        // 1. Create two freshly funded wallets via Friendbot
        final walletA = await StellarService.createWallet();
        final walletB = await StellarService.createWallet();

        expect(walletA.accountId, isNotEmpty);
        expect(walletB.accountId, isNotEmpty);

        // 2. Establish trustlines for ECHO on both wallets
        final trustA = await StellarService.establishTrustline(
          walletA.secretSeed,
        );
        final trustB = await StellarService.establishTrustline(
          walletB.secretSeed,
        );

        expect(
          trustA,
          isTrue,
          reason: 'Trustline creation for wallet A failed',
        );
        expect(
          trustB,
          isTrue,
          reason: 'Trustline creation for wallet B failed',
        );

        // 3. Setup: Issue 10 ECHO tokens to wallet A so it can send a gift
        // We must issue directly via the SDK using the ISSUER secret
        if (issuerSecret.isEmpty) {
          fail(
            'STELLAR_ISSUER_SECRET must be provided via --dart-define '
            'to run this integration test.',
          );
        }

        final issuerKp = KeyPair.fromSecretSeed(issuerSecret);
        final echoAsset = AssetTypeCreditAlphaNum4(
          EchoToken.code,
          issuerKp.accountId,
        );

        // Issue 10.0 ECHO
        final issuerAccount = await sdk.accounts.account(issuerKp.accountId);
        final txIssue = TransactionBuilder(issuerAccount)
            .addOperation(
              PaymentOperationBuilder(
                walletA.accountId,
                echoAsset,
                '10.0000000',
              ).build(),
            )
            .build();

        txIssue.sign(issuerKp, network);
        final responseIssue = await sdk.submitTransaction(txIssue);
        expect(
          responseIssue.success,
          isTrue,
          reason: 'Initial ECHO issuance from issuer to wallet A failed',
        );

        // Wait for ledger settle
        await Future.delayed(const Duration(seconds: 5));

        // 4. Record initial balances
        final initialBalA = await StellarService.getEchoBalance(
          walletA.accountId,
        );
        final initialBalB = await StellarService.getEchoBalance(
          walletB.accountId,
        );

        expect(
          initialBalA,
          10.0,
          reason: 'Wallet A should start with 10.0 initial ECHO',
        );
        expect(
          initialBalB,
          0.0,
          reason: 'Wallet B should start with 0.0 initial ECHO',
        );

        // 5. Send 5 ECHO gift from wallet A to wallet B using StellarService
        final txHash = await StellarService.sendEcho(
          senderSecret: walletA.secretSeed,
          recipientPublicKey: walletB.accountId,
          amount: 5.0,
          memo: 'Test gift',
        );

        // 6. Assertions
        expect(
          txHash,
          isNotNull,
          reason: 'Transaction failed - check SDK logs',
        );
        expect(txHash, isNotEmpty);

        // Wait for ledger settle
        await Future.delayed(const Duration(seconds: 5));

        final finalBalA = await StellarService.getEchoBalance(
          walletA.accountId,
        );
        final finalBalB = await StellarService.getEchoBalance(
          walletB.accountId,
        );

        // Verify the math: 10 - 5 = 5
        expect(finalBalA, 5.0, reason: 'Wallet A balance failed to decrease');
        expect(finalBalB, 5.0, reason: 'Wallet B balance failed to increase');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
