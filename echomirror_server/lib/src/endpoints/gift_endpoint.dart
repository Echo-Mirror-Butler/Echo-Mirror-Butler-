import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

/// Endpoint for ECHO token gifting operations
class GiftEndpoint extends Endpoint {
  /// Returns the current user's ECHO balance
  Future<double> getEchoBalance(Session session) async {
    final userId = await session.auth.authenticatedUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get user's wallet from database
    final wallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );

    if (wallet == null) {
      // Create wallet with welcome bonus for new users
      final newWallet = EchoWallet(
        userId: userId,
        balance: 10.0, // Welcome bonus
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, newWallet);
      return 10.0;
    }

    return wallet.balance;
  }

  /// Sends ECHO from the authenticated user to another user
  Future<GiftTransaction?> sendGift(
    Session session,
    int recipientUserId,
    double amount,
    String? message,
  ) async {
    final senderId = await session.auth.authenticatedUserId;
    if (senderId == null) {
      throw Exception('User not authenticated');
    }

    if (amount <= 0) {
      throw Exception('Amount must be positive');
    }

    if (senderId == recipientUserId) {
      throw Exception('Cannot send gift to yourself');
    }

    // Get sender's wallet
    var senderWallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(senderId),
    );

    if (senderWallet == null) {
      // Create wallet with welcome bonus
      senderWallet = EchoWallet(
        userId: senderId,
        balance: 10.0,
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, senderWallet);
    }

    if (senderWallet.balance < amount) {
      throw Exception('Insufficient balance');
    }

    // Get or create recipient's wallet
    var recipientWallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(recipientUserId),
    );

    if (recipientWallet == null) {
      recipientWallet = EchoWallet(
        userId: recipientUserId,
        balance: 10.0, // Welcome bonus
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, recipientWallet);
    }

    // Update balances
    senderWallet.balance -= amount;
    recipientWallet.balance += amount;

    await EchoWallet.db.updateRow(session, senderWallet);
    await EchoWallet.db.updateRow(session, recipientWallet);

    // Create transaction record
    final transaction = GiftTransaction(
      senderUserId: senderId,
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      message: message,
    );

    final insertedTx = await GiftTransaction.db.insertRow(session, transaction);
    return insertedTx;
  }

  /// Returns the current user's gift history (sent and received)
  Future<List<GiftTransaction>> getGiftHistory(Session session) async {
    final userId = await session.auth.authenticatedUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get all transactions where user is sender or recipient
    final transactions = await GiftTransaction.db.find(
      session,
      where: (t) => t.senderUserId.equals(userId) | t.recipientUserId.equals(userId),
      orderBy: (t) => t.createdAt,
      orderDescending: true,
      limit: 50,
    );

    return transactions;
  }

  /// Awards ECHO to a user (server-side only, for mood pins, videos, etc.)
  Future<double> awardEcho(
    Session session,
    int userId,
    double amount,
    String reason,
  ) async {
    if (amount <= 0) {
      throw Exception('Amount must be positive');
    }

    // Get or create user's wallet
    var wallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );

    if (wallet == null) {
      wallet = EchoWallet(
        userId: userId,
        balance: 10.0 + amount, // Welcome bonus + award
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, wallet);
      return wallet.balance;
    }

    wallet.balance += amount;
    await EchoWallet.db.updateRow(session, wallet);

    return wallet.balance;
  }
}
