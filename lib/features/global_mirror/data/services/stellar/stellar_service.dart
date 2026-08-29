import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http_client;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'stellar_config.dart';
import 'echo_token.dart';
import '../../models/on_chain_transaction_model.dart';

/// Live balances pulled directly from the Stellar Horizon API for a wallet.
class LiveAccountBalances {
  const LiveAccountBalances({
    required this.publicKey,
    required this.xlm,
    required this.echo,
  });

  /// Public key the balances belong to.
  final String publicKey;

  /// Native (XLM) balance reported by Horizon.
  final double xlm;

  /// ECHO token balance (0.0 when no balance or trustline missing).
  final double echo;

  /// True when the account has any non-zero XLM (i.e. it is funded).
  bool get isFunded => xlm > 0;
}

/// Thrown when a Stellar account has not yet been activated on the network.
class AccountNotFoundException implements Exception {
  const AccountNotFoundException(this.publicKey);

  final String publicKey;

  @override
  String toString() =>
      'AccountNotFoundException: account $publicKey is not activated on '
      'the Stellar network';
}

/// Service for interacting with Stellar testnet for ECHO token operations.
///
/// Usage flow:
/// 1. Call [createWallet] to generate a keypair and fund via Friendbot
/// 2. Call [establishTrustline] so the wallet can hold ECHO
/// 3. The server issues ECHO to the user wallet
/// 4. Call [sendEcho] to gift ECHO to another user
///
/// For UI flows that need to refresh balances without submitting
/// transactions, use [getLiveBalances] instead of [getEchoBalance].
class StellarService {
  StellarService._();

  static final StellarSDK _sdk = StellarSDK(StellarConfig.horizonUrl);
  static final Network _network = Network(StellarConfig.networkPassphrase);

  /// Generates a new Stellar keypair and funds it via Friendbot (testnet only).
  /// Returns the [KeyPair] containing both public and secret keys.
  static Future<KeyPair> createWallet({http_client.Client? httpClient}) async {
    final keypair = KeyPair.random();
    await fundWithFriendbot(keypair.accountId, httpClient: httpClient);
    debugPrint('[StellarService] Created wallet: ${keypair.accountId}');
    return keypair;
  }

  /// Public entrypoint so the UI can fund an already-generated keypair via
  /// Friendbot (testnet only). Throws [Exception] when Friendbot fails.
  static Future<void> fundWithFriendbot(
    String publicKey, {
    http_client.Client? httpClient,
  }) async =>
      _fundViaFriendbot(publicKey, httpClient: httpClient);

  /// Funds a testnet account with XLM via Stellar Friendbot.
  static Future<void> _fundViaFriendbot(
    String publicKey, {
    http_client.Client? httpClient,
  }) async {
    final url = '${StellarConfig.friendbotUrl}?addr=$publicKey';
    final client = httpClient ?? http_client.Client();
    try {
      final response = await client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Friendbot funding failed: ${response.body}');
      }
      debugPrint('[StellarService] Funded $publicKey via Friendbot');
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// Establishes a trustline from [userSecret] wallet to the ECHO issuer,
  /// allowing the wallet to hold ECHO tokens.
  static Future<bool> establishTrustline(
    String userSecret, {
    String? issuerPublicKey,
    StellarSDK? sdk,
    Network? network,
  }) async {
    final issuer = issuerPublicKey ?? StellarConfig.issuerPublicKey;
    if (issuer.isEmpty) {
      debugPrint('[StellarService] No issuer configured — skipping trustline');
      return false;
    }
    try {
      final userKeypair = KeyPair.fromSecretSeed(userSecret);
      final account = await (sdk ?? _sdk).accounts.account(
        userKeypair.accountId,
      );

      final echoAsset = AssetTypeCreditAlphaNum4(EchoToken.code, issuer);

      final transaction = TransactionBuilder(account)
          .addOperation(
            ChangeTrustOperationBuilder(echoAsset, '1000000').build(),
          )
          .build();

      transaction.sign(userKeypair, network ?? _network);
      final response = await (sdk ?? _sdk).submitTransaction(transaction);
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
    String? issuerPublicKey,
    StellarSDK? sdk,
    Network? network,
  }) async {
    final issuer = issuerPublicKey ?? StellarConfig.issuerPublicKey;
    if (issuer.isEmpty) {
      debugPrint('[StellarService] No issuer configured — cannot send ECHO');
      return null;
    }
    try {
      final senderKeypair = KeyPair.fromSecretSeed(senderSecret);
      final account = await (sdk ?? _sdk).accounts.account(
        senderKeypair.accountId,
      );

      final echoAsset = AssetTypeCreditAlphaNum4(EchoToken.code, issuer);

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
      transaction.sign(senderKeypair, network ?? _network);

      final response = await (sdk ?? _sdk).submitTransaction(transaction);
      if (response.success) {
        final hash = response.hash;
        debugPrint('[StellarService] Sent $amount ECHO — tx: $hash');
        return hash;
      }
      debugPrint(
        '[StellarService] Send failed: ${response.extras?.resultCodes}',
      );
      return null;
    } catch (e) {
      debugPrint('[StellarService] Send ECHO error: $e');
      return null;
    }
  }

  /// Returns the ECHO balance for [publicKey], or 0.0 if none.
  static Future<double> getEchoBalance(
    String publicKey, {
    String? issuerPublicKey,
    StellarSDK? sdk,
  }) async {
    final issuer = issuerPublicKey ?? StellarConfig.issuerPublicKey;
    if (issuer.isEmpty) return 0.0;
    try {
      final account = await (sdk ?? _sdk).accounts.account(publicKey);
      for (final balance in account.balances) {
        if (balance.assetCode == EchoToken.code &&
            balance.assetIssuer == issuer) {
          return double.tryParse(balance.balance) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('[StellarService] Balance check error: $e');
      return 0.0;
    }
  }

  /// Fetches live XLM + ECHO balances from Horizon for [publicKey].
  ///
  /// Throws [AccountNotFoundException] when Horizon returns 404 for a
  /// wallet that has not yet been funded. Other errors propagate as
  /// their underlying [Exception] (e.g. network failure).
  static Future<LiveAccountBalances> getLiveBalances(
    String publicKey, {
    String? issuerPublicKey,
    StellarSDK? sdk,
  }) async {
    final issuer = issuerPublicKey ?? StellarConfig.issuerPublicKey;
    try {
      final account = await (sdk ?? _sdk).accounts.account(publicKey);

      double xlm = 0.0;
      double echo = 0.0;
      for (final balance in account.balances) {
        if (balance.assetType == 'native') {
          xlm = double.tryParse(balance.balance) ?? 0.0;
        } else if (issuer.isNotEmpty &&
            balance.assetCode == EchoToken.code &&
            balance.assetIssuer == issuer) {
          echo = double.tryParse(balance.balance) ?? 0.0;
        }
      }
      return LiveAccountBalances(
        publicKey: publicKey,
        xlm: xlm,
        echo: echo,
      );
    } catch (e) {
      if (_isNotFoundError(e)) {
        throw AccountNotFoundException(publicKey);
      }
      debugPrint('[StellarService] getLiveBalances error: $e');
      rethrow;
    }
  }

  /// True when [error] represents a Stellar Horizon 404 (unfunded account).
  static bool _isNotFoundError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('404') ||
        message.contains('not found') ||
        message.contains('accountnotfound');
  }

  /// Fetches payment and account creation operations for [publicKey] from Horizon.
  ///
  /// Returns operations sorted by timestamp (most recent first), excluding
  /// operations that are not payments or account creations.
  /// Limit is capped at 200 operations per Horizon's default.
  static Future<List<OnChainTransactionModel>> getPaymentHistory(
    String publicKey, {
    int limit = 50,
    StellarSDK? sdk,
  }) async {
    try {
      final response = await (sdk ?? _sdk).payments.forAccount(publicKey)
          .limit(limit.clamp(1, 200))
          .order(RequestBuilderOrder.DESC)
          .execute();

      final transactions = <OnChainTransactionModel>[];
      for (final record in response.records) {
        if (record is PaymentOperationResponse) {
          transactions.add(
            OnChainTransactionModel(
              id: record.id,
              type: 'payment',
              transactionHash: record.transactionHash,
              sourceAccount: record.sourceAccount,
              amount: record.amount,
              asset: record.assetCode ?? 'XLM',
              from: record.from,
              to: record.to,
              timestamp: DateTime.parse(record.createdAt),
              memo: null,
            ),
          );
        } else if (record is CreateAccountOperationResponse) {
          transactions.add(
            OnChainTransactionModel(
              id: record.id,
              type: 'create_account',
              transactionHash: record.transactionHash,
              sourceAccount: record.sourceAccount,
              amount: record.startingBalance,
              asset: 'XLM',
              from: record.funder,
              to: record.account,
              timestamp: DateTime.parse(record.createdAt),
              memo: null,
            ),
          );
        }
      }

      debugPrint(
        '[StellarService] Fetched ${transactions.length} payment operations for $publicKey',
      );
      return transactions;
    } catch (e) {
      debugPrint('[StellarService] getPaymentHistory error: $e');
      return [];
    }
  }
}
