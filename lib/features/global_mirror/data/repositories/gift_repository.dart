import 'package:flutter/foundation.dart';
import 'package:echomirror_server_client/echomirror_server_client.dart';
import '../../../../core/services/serverpod_client_service.dart';
import '../models/gift_transaction_model.dart';

/// Repository for ECHO token gifting operations.
class GiftRepository {
  Client get _client => ServerpodClientService.instance.client;

  /// Returns the current user's ECHO balance.
  Future<double> getEchoBalance() async {
    try {
      return await _client.gift.getEchoBalance();
    } catch (e) {
      debugPrint('[GiftRepository] getEchoBalance error: $e');
      return 0.0;
    }
  }

  /// Sends [amount] ECHO to [recipientUserId] with an optional [message].
  /// Returns the created transaction on success, null on failure.
  Future<GiftTransactionModel?> sendGift({
    required int recipientUserId,
    required double amount,
    String? message,
  }) async {
    try {
      final tx = await _client.gift.sendGift(recipientUserId, amount, message);
      if (tx == null) return null;
      return _mapTransaction(tx);
    } catch (e) {
      debugPrint('[GiftRepository] sendGift error: $e');
      return null;
    }
  }

  /// Returns the current user's gift history (sent + received).
  Future<List<GiftTransactionModel>> getGiftHistory() async {
    try {
      final txs = await _client.gift.getGiftHistory();
      return txs.map(_mapTransaction).toList();
    } catch (e) {
      debugPrint('[GiftRepository] getGiftHistory error: $e');
      return [];
    }
  }

  GiftTransactionModel _mapTransaction(GiftTransaction tx) {
    return GiftTransactionModel(
      id: tx.id!,
      senderUserId: tx.senderUserId,
      recipientUserId: tx.recipientUserId,
      echoAmount: tx.echoAmount,
      createdAt: tx.createdAt,
      status: tx.status,
      stellarTxHash: tx.stellarTxHash,
      message: tx.message,
    );
  }
}
