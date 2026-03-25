import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/global_mirror/data/models/gift_transaction_model.dart';
import 'supabase_client_service.dart';

typedef GiftRowsStreamFactory =
    Stream<List<Map<String, dynamic>>> Function(String userId);

class GiftNotificationService {
  GiftNotificationService({
    SupabaseClient? supabaseClient,
    GiftRowsStreamFactory? streamFactory,
  }) : _supabase = supabaseClient ?? SupabaseClientService.instance.client,
       _streamFactory = streamFactory;

  final SupabaseClient _supabase;
  final GiftRowsStreamFactory? _streamFactory;

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  final Set<int> _seenTransactionIds = <int>{};
  bool _primed = false;

  void startListening(
    String userId,
    void Function(GiftTransactionModel gift) onGift,
  ) {
    stopListening();
    _primed = false;
    _seenTransactionIds.clear();

    final stream =
        _streamFactory?.call(userId) ??
        _supabase
            .from('gift_transactions')
            .stream(primaryKey: ['id'])
            .eq('recipient_user_id', userId);

    _subscription = stream.listen((rows) {
      final transactions = rows
          .map((row) => GiftTransactionModel.fromJson(row))
          .toList();

      if (!_primed) {
        for (final transaction in transactions) {
          _seenTransactionIds.add(transaction.id);
        }
        _primed = true;
        return;
      }

      for (final transaction in transactions) {
        if (_seenTransactionIds.add(transaction.id)) {
          onGift(transaction);
        }
      }
    }, onError: (error, stackTrace) {
      debugPrint('[GiftNotificationService] Realtime stream error: $error');
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _seenTransactionIds.clear();
    _primed = false;
  }
}
