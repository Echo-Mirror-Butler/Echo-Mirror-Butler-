import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gift_transaction_model.dart';

/// Repository for ECHO token gifting operations backed by Supabase.
class GiftRepository {
  final SupabaseClient? client;
  GiftRepository([this.client]);

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  String get _currentUserId =>
      _supabase.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';

  /// Returns the current user's ECHO balance.
  /// Creates a wallet with a 10 ECHO welcome bonus if one does not exist.
  Future<double> getEchoBalance() async {
    try {
      final row = await _supabase
          .from('echo_wallets')
          .select('balance')
          .eq('user_id', _currentUserId)
          .maybeSingle();

      if (row != null) {
        return (row['balance'] as num).toDouble();
      }

      // First access — provision a wallet with the welcome bonus.
      final inserted = await _supabase
          .from('echo_wallets')
          .insert({'user_id': _currentUserId, 'balance': 10.0})
          .select('balance')
          .single();

      return (inserted['balance'] as num).toDouble();
    } catch (e) {
      debugPrint('[GiftRepository] getEchoBalance error: $e');
      return 0.0;
    }
  }

  /// Sends [amount] ECHO to [recipientUserId] with an optional [message].
  /// Deducts from sender's wallet and credits recipient's wallet atomically
  /// by using two sequential updates (best-effort; replace with a Supabase
  /// Edge Function / RPC for true atomicity in production).
  /// Returns the created transaction on success, null on failure.
  Future<GiftTransactionModel?> sendGift({
    required String recipientUserId,
    required double amount,
    String? message,
  }) async {
    try {
      final senderId = _currentUserId;

      if (senderId == recipientUserId) {
        debugPrint('[GiftRepository] sendGift: cannot send to self');
        return null;
      }

      // Verify sender has sufficient balance.
      final senderBalance = await getEchoBalance();
      if (senderBalance < amount) {
        debugPrint('[GiftRepository] sendGift: insufficient balance');
        return null;
      }

      // Deduct from sender.
      await _supabase
          .from('echo_wallets')
          .update({
            'balance': senderBalance - amount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', senderId);

      // Credit recipient — create wallet with welcome bonus if needed.
      final recipientRow = await _supabase
          .from('echo_wallets')
          .select('balance')
          .eq('user_id', recipientUserId)
          .maybeSingle();

      if (recipientRow != null) {
        final recipientBalance = (recipientRow['balance'] as num).toDouble();
        await _supabase
            .from('echo_wallets')
            .update({
              'balance': recipientBalance + amount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', recipientUserId);
      } else {
        await _supabase.from('echo_wallets').insert({
          'user_id': recipientUserId,
          'balance': 10.0 + amount,
        });
      }

      // Record the transaction.
      final row = await _supabase
          .from('gift_transactions')
          .insert({
            'sender_user_id': senderId,
            'recipient_user_id': recipientUserId,
            'echo_amount': amount,
            'status': 'completed',
            if (message != null && message.isNotEmpty) 'message': message,
          })
          .select()
          .single();

      return GiftTransactionModel.fromSupabase(row);
    } catch (e) {
      debugPrint('[GiftRepository] sendGift error: $e');
      return null;
    }
  }

  /// Returns the current user's gift history (sent + received), newest first.
  Future<List<GiftTransactionModel>> getGiftHistory() async {
    try {
      final userId = _currentUserId;
      final rows = await _supabase
          .from('gift_transactions')
          .select()
          .or('sender_user_id.eq.$userId,recipient_user_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);

      return rows.map(GiftTransactionModel.fromSupabase).toList();
    } catch (e) {
      debugPrint('[GiftRepository] getGiftHistory error: $e');
      return [];
    }
  }
}
