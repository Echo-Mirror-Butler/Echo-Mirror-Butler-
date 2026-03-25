import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gift_transaction_model.dart';
import '../services/stellar/stellar_service.dart';

/// Repository for ECHO token gifting operations backed by Supabase.
class GiftRepository {
  final SupabaseClient? client;
  GiftRepository([this.client]);

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  String get _currentUserId =>
      _supabase.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';

  /// Returns the current user's ECHO balance.
  Future<double> getEchoBalance() async {
    try {
      final userId = _currentUserId;
      final wallet = await _supabase
          .from('user_wallets')
          .select('public_key')
          .eq('user_id', userId)
          .maybeSingle();

      if (wallet == null) return 0.0;
      return await StellarService.getEchoBalance(
        wallet['public_key'] as String,
      );
    } catch (e) {
      debugPrint('[GiftRepository] getEchoBalance error: $e');
      return 0.0;
    }
  }

  /// Sends [amount] ECHO to [recipientUserId] with an optional [message].
  /// On success, inserts a row into the gift_transactions table and returns
  /// the created transaction model.
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

      // 1. Fetch sender's secret key from user_wallets (encrypted field)
      final senderWallet = await _supabase
          .from('user_wallets')
          .select('encrypted_secret')
          .eq('user_id', senderId)
          .maybeSingle();
      if (senderWallet == null) {
        debugPrint('[GiftRepository] sendGift: sender wallet not found');
        return null;
      }

      // 2. Fetch recipient's public key from user_wallets using recipientUserId
      final recipientWallet = await _supabase
          .from('user_wallets')
          .select('public_key')
          .eq('user_id', recipientUserId)
          .maybeSingle();
      if (recipientWallet == null) {
        debugPrint('[GiftRepository] sendGift: recipient wallet not found');
        return null;
      }

      // 3. Call StellarService.sendEcho(...) to execute the Stellar transaction
      final txHash = await StellarService.sendEcho(
        senderSecret: senderWallet['encrypted_secret'] as String,
        recipientPublicKey: recipientWallet['public_key'] as String,
        amount: amount,
        memo: message,
      );

      if (txHash == null) {
        debugPrint('[GiftRepository] sendGift: stellar transaction failed');
        return null;
      }

      // 4. On success, insert a row into gift_transactions table with the tx hash
      final row = await _supabase
          .from('gift_transactions')
          .insert({
            'sender_user_id': senderId,
            'recipient_user_id': recipientUserId,
            'echo_amount': amount,
            'stellar_tx_hash': txHash,
            'message': message,
            'status': 'completed',
          })
          .select()
          .single();

      // 5. Return a populated GiftTransactionModel
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
      final results = await _supabase
          .from('gift_transactions')
          .select()
          .or('sender_user_id.eq.$userId,recipient_user_id.eq.$userId')
          .order('created_at', ascending: false);

      return (results as List)
          .map(
            (r) => GiftTransactionModel.fromSupabase(r as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('[GiftRepository] getGiftHistory error: $e');
      return [];
    }
  }
}
