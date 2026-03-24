import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Stellar testnet configuration — mirrors backend/stellar/stellar_config.dart
/// but safe for use in a Dart server (no Flutter imports).
class _StellarConfig {
  static const String horizonUrl = 'https://horizon-testnet.stellar.org';
  static const String networkPassphrase = 'Test SDF Network ; September 2015';
  static const String assetCode = 'ECHO';
  static const String friendbotUrl = 'https://friendbot.stellar.org';
  static String get issuerPublicKey =>
      const String.fromEnvironment('STELLAR_ISSUER_PUBLIC', defaultValue: '');
}

/// Server-side service for Stellar testnet ECHO token operations.
///
/// This is the Serverpod-compatible counterpart of the Flutter-side
/// [StellarService] in `backend/stellar/stellar_service.dart`.
/// It uses the same `stellar_flutter_sdk` operations but replaces
/// Flutter's `debugPrint` with standard `print` so it runs safely on the
/// Dart VM without a Flutter engine.
///
/// Secret key handling:
///   - Secret keys are NEVER stored in the database.
///   - On creation, the secret key must be stored in a secrets manager
///     (e.g. AWS Secrets Manager, HashiCorp Vault) keyed by the user's ID.
///   - For testnet development, set STELLAR_USER_SECRET_<userId> env vars
///     or replace [_getSecretKey] with your chosen secrets-manager client.
class StellarService {
  StellarService._();

  static final StellarSDK _sdk = StellarSDK(_StellarConfig.horizonUrl);
  static final Network _network = Network(_StellarConfig.networkPassphrase);

  /// Generates a new Stellar keypair and funds it via Friendbot.
  /// Returns the [KeyPair] with public + secret keys.
  /// The caller is responsible for storing the secret key in a secrets manager.
  static Future<KeyPair> createWallet() async {
    final keypair = KeyPair.random();
    await _fundViaFriendbot(keypair.accountId);
    print('[StellarService] Created wallet: ${keypair.accountId}');
    return keypair;
  }

  /// Funds a testnet account with XLM via Stellar Friendbot.
  static Future<void> _fundViaFriendbot(String publicKey) async {
    final url = '${_StellarConfig.friendbotUrl}?addr=$publicKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Friendbot funding failed: ${response.body}');
    }
    print('[StellarService] Funded $publicKey via Friendbot');
  }

  /// Establishes a trustline from [userSecret] wallet to the ECHO issuer,
  /// allowing the wallet to hold ECHO tokens.
  static Future<bool> establishTrustline(String userSecret) async {
    if (_StellarConfig.issuerPublicKey.isEmpty) {
      print('[StellarService] No issuer configured — skipping trustline');
      return false;
    }
    try {
      final userKeypair = KeyPair.fromSecretSeed(userSecret);
      final account = await _sdk.accounts.account(userKeypair.accountId);

      final echoAsset = AssetTypeCreditAlphaNum4(
        _StellarConfig.assetCode,
        _StellarConfig.issuerPublicKey,
      );

      final transaction = TransactionBuilder(account)
          .addOperation(
            ChangeTrustOperationBuilder(echoAsset, '1000000').build(),
          )
          .build();

      transaction.sign(userKeypair, _network);
      final response = await _sdk.submitTransaction(transaction);
      print('[StellarService] Trustline established: ${response.success}');
      return response.success;
    } catch (e) {
      print('[StellarService] Trustline error: $e');
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
    if (_StellarConfig.issuerPublicKey.isEmpty) {
      print('[StellarService] No issuer configured — cannot send ECHO');
      return null;
    }
    try {
      final senderKeypair = KeyPair.fromSecretSeed(senderSecret);
      final account = await _sdk.accounts.account(senderKeypair.accountId);

      final echoAsset = AssetTypeCreditAlphaNum4(
        _StellarConfig.assetCode,
        _StellarConfig.issuerPublicKey,
      );

      final builder = TransactionBuilder(account).addOperation(
        PaymentOperationBuilder(
          recipientPublicKey,
          echoAsset,
          amount.toStringAsFixed(7),
        ).build(),
      );

      if (memo != null && memo.isNotEmpty) {
        builder.addMemo(
          MemoText(memo.length > 28 ? memo.substring(0, 28) : memo),
        );
      }

      final transaction = builder.build();
      transaction.sign(senderKeypair, _network);

      final response = await _sdk.submitTransaction(transaction);
      if (response.success) {
        final hash = response.hash;
        print('[StellarService] Sent $amount ECHO — tx: $hash');
        return hash;
      }
      print('[StellarService] Send failed: ${response.extras?.resultCodes}');
      return null;
    } catch (e) {
      print('[StellarService] Send ECHO error: $e');
      return null;
    }
  }

  /// Retrieves the stored secret key for [userId] from the secrets manager.
  ///
  /// In production, replace this with a call to your secrets manager
  /// (e.g. AWS Secrets Manager, HashiCorp Vault).
  /// For local testnet development, set env var STELLAR_USER_SECRET_<userId>.
  static String? getSecretKey(int userId) {
    return String.fromEnvironment(
      'STELLAR_USER_SECRET_$userId',
      defaultValue: '',
    ).isEmpty
        ? null
        : String.fromEnvironment('STELLAR_USER_SECRET_$userId');
  }
}
