import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

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

    final wallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );

    if (wallet == null) {
      final newWallet = EchoWallet(
        userId: userId,
        balance: 10.0,
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, newWallet);
      return 10.0;
    }

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

    var senderWallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(senderId),
    );

    if (senderWallet == null) {
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

    var recipientWallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(recipientUserId),
    );

    if (recipientWallet == null) {
      recipientWallet = EchoWallet(
        userId: recipientUserId,
        balance: 10.0,
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, recipientWallet);
    }

    senderWallet = senderWallet.copyWith(balance: senderWallet.balance - amount);
    recipientWallet = recipientWallet.copyWith(balance: recipientWallet.balance + amount);

    await EchoWallet.db.updateRow(session, senderWallet);
    await EchoWallet.db.updateRow(session, recipientWallet);

    final transaction = GiftTransaction(
      senderUserId: senderId,
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      message: message,
    );

    return await GiftTransaction.db.insertRow(session, transaction);
  }

  Future<List<GiftTransaction>> getGiftHistory(Session session) async {
    final userId = _getUserId(session);

    return await GiftTransaction.db.find(
      session,
      where: (t) => t.senderUserId.equals(userId) | t.recipientUserId.equals(userId),
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
      wallet = EchoWallet(
        userId: userId,
        balance: 10.0 + amount,
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, wallet);
      return wallet.balance;
    }

    wallet = wallet.copyWith(balance: wallet.balance + amount);
    await EchoWallet.db.updateRow(session, wallet);

    return wallet.balance;
  }
}
