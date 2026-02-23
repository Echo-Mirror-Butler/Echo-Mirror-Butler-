import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Configuration for Stellar testnet
class StellarConfig {
  StellarConfig._();

  /// Horizon API endpoint (testnet)
  static const String horizonUrl = 'https://horizon-testnet.stellar.org';

  /// Stellar testnet network passphrase
  static const String networkPassphrase = 'Test SDF Network ; September 2015';

  /// ECHO token asset code
  static const String assetCode = 'ECHO';

  /// Friendbot URL — funds new testnet accounts with XLM
  static const String friendbotUrl = 'https://friendbot.stellar.org';

  /// Issuer public key — loaded from environment variable
  static String get issuerPublicKey => const String.fromEnvironment(
    'STELLAR_ISSUER_PUBLIC',
    defaultValue: '',
  );

  /// Distributor public key (optional, for issuing ECHO)
  static String get distributorPublicKey => const String.fromEnvironment(
    'STELLAR_DISTRIBUTOR_PUBLIC',
    defaultValue: '',
  );
}

/// ECHO token asset definition
class EchoToken {
  EchoToken._();

  static const String code = StellarConfig.assetCode;
  static String get issuer => StellarConfig.issuerPublicKey;

  static const double minGiftAmount = 1.0;
  static const double maxGiftAmount = 100.0;
  static const double moodPinReward = 2.0;
  static const double videoPostReward = 5.0;
  static const double commentReceivedReward = 1.0;
  static const double welcomeBonus = 10.0;
}

/// Serverpod-compatible Stellar service integration wrapper.
/// 
/// This bridges the Stellar Flutter SDK with Serverpod endpoints,
/// providing a clean API for wallet creation, trustlines, and payments.
/// 
/// Usage flow:
/// 1. Call [createWallet] to generate a keypair and fund via Friendbot
/// 2. Call [establishTrustline] so the wallet can hold ECHO
/// 3. The distributor/server issues ECHO to the user wallet
/// 4. Call [sendEcho] to gift ECHO to another user
class StellarServiceIntegration {
  StellarServiceIntegration._();

  static final StellarSDK _sdk = StellarSDK(StellarConfig.horizonUrl);
  static final Network _network = Network(StellarConfig.networkPassphrase);

  /// Generates a new Stellar keypair and funds it via Friendbot (testnet only).
  /// 
  /// Returns the [KeyPair] containing both public and secret keys.
  /// 
  /// SECURITY: The caller MUST store the secret key securely (never in database).
  static Future<KeyPair> createWallet() async {
    if (StellarConfig.issuerPublicKey.isEmpty) {
      throw Exception(
        'STELLAR_ISSUER_PUBLIC environment variable not set. '
        'See backend/.env.example for setup.',
      );
    }

    try {
      final keypair = KeyPair.random();
      await _fundViafriendbot(keypair.accountId);
      debugPrint('[StellarServiceIntegration] Created wallet: ${keypair.accountId}');
      return keypair;
    } catch (e) {
      debugPrint('[StellarServiceIntegration] Wallet creation error: $e');
      rethrow;
    }
  }

  /// Funds a testnet account with XLM via Stellar Friendbot.
  static Future<void> _fundViafriendbot(String publicKey) async {
    final url = '${StellarConfig.friendbotUrl}?addr=$publicKey';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Friendbot funding failed: ${response.body}');
    }
    
    debugPrint('[StellarServiceIntegration] Funded $publicKey via Friendbot');
  }

  /// Establishes a trustline from [userSecret] wallet to the ECHO issuer,
  /// allowing the wallet to hold ECHO tokens.
  /// 
  /// Returns `true` if successful, `false` if the issuer is not configured
  /// (graceful degradation for DB-only mode).
  static Future<bool> establishTrustline(String userSecret) async {
    if (StellarConfig.issuerPublicKey.isEmpty) {
      debugPrint(
        '[StellarServiceIntegration] No issuer configured — skipping trustline',
      );
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
      
      debugPrint(
        '[StellarServiceIntegration] Trustline established: ${response.success}',
      );
      
      return response.success;
    } catch (e) {
      debugPrint('[StellarServiceIntegration] Trustline error: $e');
      return false;
    }
  }

  /// Sends [amount] ECHO tokens from [senderSecret] to [recipientPublicKey].
  /// 
  /// Returns the Stellar transaction hash on success, null on failure.
  /// 
  /// Throws an exception if the issuer is not configured.
  static Future<String?> sendEcho({
    required String senderSecret,
    required String recipientPublicKey,
    required double amount,
    String? memo,
  }) async {
    if (StellarConfig.issuerPublicKey.isEmpty) {
      throw Exception(
        'STELLAR_ISSUER_PUBLIC not configured — cannot send ECHO',
      );
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
        // Stellar memo max length is 28 characters
        builder.addMemo(
          MemoText(memo.length > 28 ? memo.substring(0, 28) : memo),
        );
      }

      final transaction = builder.build();
      transaction.sign(senderKeypair, _network);

      final response = await _sdk.submitTransaction(transaction);
      
      if (response.success) {
        final hash = response.hash;
        debugPrint(
          '[StellarServiceIntegration] Sent $amount ECHO — tx: $hash',
        );
        return hash;
      }
      
      debugPrint(
        '[StellarServiceIntegration] Send failed: ${response.extras?.resultCodes}',
      );
      return null;
    } catch (e) {
      debugPrint('[StellarServiceIntegration] Send ECHO error: $e');
      return null;
    }
  }

  /// Returns the ECHO balance for [publicKey], or 0.0 if none.
  /// 
  /// Queries Horizon for real-time balance accuracy.
  static Future<double> getEchoBalance(String publicKey) async {
    if (StellarConfig.issuerPublicKey.isEmpty) {
      return 0.0;
    }

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
      debugPrint('[StellarServiceIntegration] Balance check error: $e');
      return 0.0;
    }
  }
}
