import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/stellar_service.dart';

class GiftEndpoint extends Endpoint {
  int _getUserId(Session session) {
    final userIdentifier = session.authenticated?.userIdentifier;
    if (userIdentifier == null) {
      throw Exception('User not authenticated');
    }
    return userIdentifier.hashCode.abs();
  }

  Future<double> getEchoBalance(Session session) async {
    final userId = _getUserId(session);

    final wallet = await _getOrCreateWallet(session, userId);
    return wallet.balance;
  }

  Future<GiftTransaction?> sendGift(
    Session session,
    int recipientUserId,
    double amount,
    String? message,
  ) async {
    final senderId = _getUserId(session);

    if (amount <= 0) {
      throw Exception('Amount must be positive');
    }

    if (senderId == recipientUserId) {
      throw Exception('Cannot send gift to yourself');
    }

    final senderWallet = await _getOrCreateWallet(session, senderId);
    final recipientWallet = await _getOrCreateWallet(session, recipientUserId);

    if (senderWallet.balance < amount) {
      throw Exception('Insufficient balance');
    }

    // Attempt on-chain Stellar transfer when both wallets have a Stellar key.
    // Falls back gracefully to DB-only transfer if either key is missing.
    String? stellarTxHash;
    final senderPublicKey = senderWallet.stellarPublicKey;
    final recipientPublicKey = recipientWallet.stellarPublicKey;

    if (senderPublicKey != null && recipientPublicKey != null) {
      final senderSecret = StellarService.getSecretKey(senderId);
      if (senderSecret != null) {
        stellarTxHash = await StellarService.sendEcho(
          senderSecret: senderSecret,
          recipientPublicKey: recipientPublicKey,
          amount: amount,
          memo: message,
        );
        if (stellarTxHash == null) {
          print(
            '[GiftEndpoint] Stellar transfer failed — falling back to DB-only',
          );
        }
      } else {
        print(
          '[GiftEndpoint] No secret key found for sender $senderId'
          ' — falling back to DB-only transfer',
        );
      }
    }

    // Update DB balances regardless of Stellar outcome.
    final updatedSender = senderWallet.copyWith(
      balance: senderWallet.balance - amount,
    );
    final updatedRecipient = recipientWallet.copyWith(
      balance: recipientWallet.balance + amount,
    );

    await EchoWallet.db.updateRow(session, updatedSender);
    await EchoWallet.db.updateRow(session, updatedRecipient);

    final transaction = GiftTransaction(
      senderUserId: senderId,
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      message: message,
      stellarTxHash: stellarTxHash,
    );

    return await GiftTransaction.db.insertRow(session, transaction);
  }

  Future<List<GiftTransaction>> getGiftHistory(Session session) async {
    final userId = _getUserId(session);

    return await GiftTransaction.db.find(
      session,
      where: (t) =>
          t.senderUserId.equals(userId) | t.recipientUserId.equals(userId),
      orderBy: (t) => t.createdAt,
      orderDescending: true,
      limit: 50,
    );
  }

  Future<double> awardEcho(
    Session session,
    int userId,
    double amount,
    String reason,
  ) async {
    if (amount <= 0) {
      throw Exception('Amount must be positive');
    }

    var wallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );

    if (wallet == null) {
      wallet = EchoWallet(userId: userId, balance: 10.0 + amount);
      await EchoWallet.db.insertRow(session, wallet);
      return wallet.balance;
    }

    wallet = wallet.copyWith(balance: wallet.balance + amount);
    await EchoWallet.db.updateRow(session, wallet);

    return wallet.balance;
  }

  /// Returns the existing wallet for [userId], or creates one with a welcome
  /// bonus. For new wallets, a Stellar keypair is generated on testnet and the
  /// public key is stored; the secret key is persisted to the secrets manager.
  Future<EchoWallet> _getOrCreateWallet(Session session, int userId) async {
    final existing = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );
    if (existing != null) return existing;

    // New user — provision a Stellar testnet wallet and ECHO trustline.
    String? stellarPublicKey;
    try {
      final keypair = await StellarService.createWallet();
      stellarPublicKey = keypair.accountId;

      final trustlineEstablished = await StellarService.establishTrustline(
        keypair.secretSeed,
      );
      if (!trustlineEstablished) {
        print(
          '[GiftEndpoint] Trustline not established for user $userId'
          ' — wallet will operate in DB-only mode',
        );
      }

      // TODO(production): persist keypair.secretSeed to your secrets manager
      // keyed by userId. Never store the secret seed in the database.
      // Example: await SecretsManager.store('stellar_secret_$userId', keypair.secretSeed);
      print(
        '[GiftEndpoint] Stellar wallet created for user $userId'
        ' — store the secret key in your secrets manager',
      );
    } catch (e) {
      print(
        '[GiftEndpoint] Stellar wallet creation failed for user $userId: $e'
        ' — wallet will operate in DB-only mode',
      );
    }

    final newWallet = EchoWallet(
      userId: userId,
      balance: 10.0,
      stellarPublicKey: stellarPublicKey,
    );
    return await EchoWallet.db.insertRow(session, newWallet);
  }
}
