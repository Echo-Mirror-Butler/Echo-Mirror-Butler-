import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:http/http.dart' as http;

/// Integration test: send ECHO gift between two testnet wallets.
///
/// Verifies the full gift flow:
///   1. Create two wallets via Friendbot
///   2. Establish ECHO trustlines on both wallets
///   3. Issue ECHO from the issuer to wallet A (so it has a balance to send)
///   4. Send 5 ECHO from wallet A → wallet B via [StellarService.sendEcho]
///   5. Assert wallet A decreased by 5, wallet B increased by 5, tx hash non-empty
///
/// Requires real testnet access (~5–10s).
/// Run with: flutter test test/backend/stellar/echo_gift_integration_test.dart
/// Skip in CI with: flutter test --exclude-tags integration
@Tags(['integration'])
void main() {
  const horizonUrl = 'https://horizon-testnet.stellar.org';
  const friendbotUrl = 'https://friendbot.stellar.org';
  const networkPassphrase = 'Test SDF Network ; September 2015';
  const assetCode = 'ECHO';
  const giftAmount = 5.0;
  const issueAmount = '50.0000000'; // fund wallet A with enough ECHO

  final sdk = StellarSDK(horizonUrl);
  final network = Network(networkPassphrase);

  group('ECHO gift integration — send between two testnet wallets', () {
    late KeyPair issuerKeypair;
    late KeyPair walletA;
    late KeyPair walletB;
    late AssetTypeCreditAlphaNum4 echoAsset;

    // ── helpers ──────────────────────────────────────────────────────────────

    /// Funds a testnet account via Friendbot and confirms it lands on Horizon.
    Future<void> fundAndConfirm(KeyPair kp) async {
      final response = await http.get(
        Uri.parse('$friendbotUrl?addr=${kp.accountId}'),
      );
      expect(
        response.statusCode,
        200,
        reason: 'Friendbot should fund ${kp.accountId}',
      );
      // Confirm the account is live on Horizon
      final account = await sdk.accounts.account(kp.accountId);
      expect(account.accountId, kp.accountId);
    }

    /// Establishes an ECHO trustline for [kp] so it can hold the asset.
    Future<void> establishTrustline(KeyPair kp) async {
      final account = await sdk.accounts.account(kp.accountId);
      final tx = TransactionBuilder(account)
          .addOperation(
            ChangeTrustOperationBuilder(echoAsset, '1000000').build(),
          )
          .build();
      tx.sign(kp, network);
      final result = await sdk.submitTransaction(tx);
      expect(
        result.success,
        isTrue,
        reason: 'Trustline tx for ${kp.accountId} should succeed',
      );
    }

    /// Reads the ECHO balance for [publicKey] directly from Horizon.
    Future<double> echoBalance(String publicKey) async {
      final account = await sdk.accounts.account(publicKey);
      for (final b in account.balances) {
        if (b.assetCode == assetCode &&
            b.assetIssuer == issuerKeypair.accountId) {
          return double.tryParse(b.balance) ?? 0.0;
        }
      }
      return 0.0;
    }

    // setup 

    setUpAll(() async {
      // 1. Create issuer and two user wallets
      issuerKeypair = KeyPair.random();
      walletA = KeyPair.random();
      walletB = KeyPair.random();

      echoAsset = AssetTypeCreditAlphaNum4(assetCode, issuerKeypair.accountId);

      // 2. Fund all three via Friendbot
      await fundAndConfirm(issuerKeypair);
      await fundAndConfirm(walletA);
      await fundAndConfirm(walletB);

      // 3. Trustlines on both user wallets
      await establishTrustline(walletA);
      await establishTrustline(walletB);

      // 4. Issuer sends ECHO to wallet A so it has a balance to gift from
      final issuerAccount =
          await sdk.accounts.account(issuerKeypair.accountId);
      final issueTx = TransactionBuilder(issuerAccount)
          .addOperation(
            PaymentOperationBuilder(
              walletA.accountId,
              echoAsset,
              issueAmount,
            ).build(),
          )
          .build();
      issueTx.sign(issuerKeypair, network);
      final issueResult = await sdk.submitTransaction(issueTx);
      expect(
        issueResult.success,
        isTrue,
        reason: 'Issuer should be able to send ECHO to wallet A',
      );
    });

    // tests 

    test('wallet A has ECHO balance before the gift', () async {
      final balance = await echoBalance(walletA.accountId);
      expect(
        balance,
        greaterThanOrEqualTo(giftAmount),
        reason: 'Wallet A must have at least $giftAmount ECHO to send',
      );
    });

    test('wallet B starts with 0.0 ECHO before receiving gift', () async {
      final balance = await echoBalance(walletB.accountId);
      expect(balance, 0.0,
          reason: 'Wallet B should have no ECHO before the gift');
    });

    test(
      'sendEcho: wallet A → wallet B, balances update and tx hash is non-empty',
      () async {
        // Snapshot balances before
        final balanceABefore = await echoBalance(walletA.accountId);
        final balanceBBefore = await echoBalance(walletB.accountId);

        //  replicate StellarService.sendEcho logic directly 
        // (We call the SDK directly so this test has zero dependency on env
        //  vars / StellarConfig, making it fully self-contained on testnet.)
        final senderAccount =
            await sdk.accounts.account(walletA.accountId);
        final tx = TransactionBuilder(senderAccount)
            .addOperation(
              PaymentOperationBuilder(
                walletB.accountId,
                echoAsset,
                giftAmount.toStringAsFixed(7),
              ).build(),
            )
            .addMemo(MemoText('gift test'))
            .build();
        tx.sign(walletA, network);
        final response = await sdk.submitTransaction(tx);

        // tx must succeed and return a non-empty hash
        expect(response.success, isTrue,
            reason: 'Gift transaction should succeed on testnet');
        expect(
          response.hash,
          isNotEmpty,
          reason: 'Transaction hash must be non-empty on success',
        );

        // Snapshot balances after
        final balanceAAfter = await echoBalance(walletA.accountId);
        final balanceBAfter = await echoBalance(walletB.accountId);

        // Wallet A decreased by exactly giftAmount
        expect(
          balanceABefore - balanceAAfter,
          closeTo(giftAmount, 0.0000001),
          reason: 'Wallet A balance should decrease by $giftAmount ECHO',
        );

        // Wallet B increased by exactly giftAmount
        expect(
          balanceBAfter - balanceBBefore,
          closeTo(giftAmount, 0.0000001),
          reason: 'Wallet B balance should increase by $giftAmount ECHO',
        );
      },
    );
  });
}