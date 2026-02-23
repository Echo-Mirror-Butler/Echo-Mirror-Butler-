import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'stellar_config.dart';
import 'echo_token.dart';

/// Service for interacting with Stellar testnet for ECHO token operations.
///
/// Usage flow:
/// 1. Call [createWallet] to generate a keypair and fund via Friendbot
/// 2. Call [establishTrustline] so the wallet can hold ECHO
/// 3. The server issues ECHO to the user wallet
/// 4. Call [sendEcho] to gift ECHO to another user
class StellarService {
  StellarService._();

  static final StellarSDK _sdk = StellarSDK(StellarConfig.horizonUrl);
  static final Network _network = Network(StellarConfig.networkPassphrase);

  /// Generates a new Stellar keypair and funds it via Friendbot (testnet only).
  /// Returns the [KeyPair] containing both public and secret keys.
  static Future<KeyPair> createWallet() async {
    final keypair = KeyPair.random();
    await _fundViafriendbot(keypair.accountId);
    debugPrint('[StellarService] Created wallet: ${keypair.accountId}');
    return keypair;
  }

  /// Funds a testnet account with XLM via Stellar Friendbot.
  static Future<void> _fundViafriendbot(String publicKey) async {
    final url = '${StellarConfig.friendbotUrl}?addr=$publicKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Friendbot funding failed: ${response.body}');
    }
    debugPrint('[StellarService] Funded $publicKey via Friendbot');
  }

  /// Establishes a trustline from [userSecret] wallet to the ECHO issuer,
  /// allowing the wallet to hold ECHO tokens.
  static Future<bool> establishTrustline(String userSecret) async {
    if (StellarConfig.issuerPublicKey.isEmpty) {
      debugPrint('[StellarService] No issuer configured — skipping trustline');
      return false;
    }
    try {
      final userKeypair = KeyPair.fromSecretSeed(userSecret);
      final account = await _sdk.accounts.account(userKeypair.accountId);

      final echoAsset = AssetTypeCreditAlphaNum4(
        EchoToken.code,
        StellarConfig.issuerPublicKey,
      );

      final transaction = TransactionBuilder(account)
          .addOperation(
            ChangeTrustOperationBuilder(echoAsset, '1000000').build(),
          )
          .build();

      transaction.sign(userKeypair, _network);
      final response = await _sdk.submitTransaction(transaction);
      debugPrint('[StellarService] Trustline established: ${response.success}');
      return response.success;
    } catch (e) {
      debugPrint('[StellarService] Trustline error: $e');
      return false;
    }
  }

  /// Sends [amount] ECHO tokens from [senderSecret] to [recipientPublicKey].
  /// Returns the Stellar transaction hash on success, null on failure.
  static Future<String?> sendEcho({
    required String senderSecret,
    required String recipientPublicKey,
    required double amount,
    String? memo,
  }) async {
    if (StellarConfig.issuerPublicKey.isEmpty) {
      debugPrint('[StellarService] No issuer configured — cannot send ECHO');
      return null;
    }
    try {
      final senderKeypair = KeyPair.fromSecretSeed(senderSecret);
      final account = await _sdk.accounts.account(senderKeypair.accountId);

      final echoAsset = AssetTypeCreditAlphaNum4(
        EchoToken.code,
        StellarConfig.issuerPublicKey,
      );

      final builder = TransactionBuilder(account)
          .addOperation(
            PaymentOperationBuilder(
              recipientPublicKey,
              echoAsset,
              amount.toStringAsFixed(7),
            ).build(),
          );

      if (memo != null && memo.isNotEmpty) {
        builder.addMemo(MemoText(memo.length > 28 ? memo.substring(0, 28) : memo));
      }

      final transaction = builder.build();
      transaction.sign(senderKeypair, _network);

      final response = await _sdk.submitTransaction(transaction);
      if (response.success) {
        final hash = response.hash;
        debugPrint('[StellarService] Sent $amount ECHO — tx: $hash');
        return hash;
      }
      debugPrint('[StellarService] Send failed: ${response.extras?.resultCodes}');
      return null;
    } catch (e) {
      debugPrint('[StellarService] Send ECHO error: $e');
      return null;
    }
  }

  /// Returns the ECHO balance for [publicKey], or 0.0 if none.
  static Future<double> getEchoBalance(String publicKey) async {
    if (StellarConfig.issuerPublicKey.isEmpty) return 0.0;
    try {
      final account = await _sdk.accounts.account(publicKey);
      for (final balance in account.balances) {
        if (balance.assetCode == EchoToken.code &&
            balance.assetIssuer == StellarConfig.issuerPublicKey) {
          return double.tryParse(balance.balance) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('[StellarService] Balance check error: $e');
      return 0.0;
    }
  }
}
