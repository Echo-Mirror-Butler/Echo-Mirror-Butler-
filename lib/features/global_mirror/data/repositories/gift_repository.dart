import 'package:flutter/foundation.dart';
import '../models/gift_transaction_model.dart';

/// Repository for ECHO token gifting operations.
///
/// Currently uses local stubs. Calls will be wired to the live
/// Serverpod `client.gift.*` endpoint once `serverpod generate`
/// has been run in the echomirror_server repo and the generated
/// client code is available.
class GiftRepository {
  /// Returns the current user's ECHO balance.
  Future<double> getEchoBalance() async {
    try {
      // TODO: replace with `await _client.gift.getEchoBalance()`
      // once serverpod generate has been run.
      return 0.0;
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
      // TODO: replace with `await _client.gift.sendGift(...)` once
      // serverpod generate has been run.
      return GiftTransactionModel(
        id: 0,
        senderUserId: 0,
        recipientUserId: recipientUserId,
        echoAmount: amount,
        createdAt: DateTime.now(),
        status: 'completed',
        stellarTxHash: null,
        message: message,
      );
    } catch (e) {
      debugPrint('[GiftRepository] sendGift error: $e');
      return null;
    }
  }

  /// Returns the current user's gift history (sent + received).
  Future<List<GiftTransactionModel>> getGiftHistory() async {
    try {
      // TODO: replace with `await _client.gift.getGiftHistory()` once
      // serverpod generate has been run.
      return [];
    } catch (e) {
      debugPrint('[GiftRepository] getGiftHistory error: $e');
      return [];
    }
  }
}
