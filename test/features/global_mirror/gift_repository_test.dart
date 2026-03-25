import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGiftRepository implements GiftRepository {
  @override
  final SupabaseClient? client = null;

  @override
  Future<double> getEchoBalance() async => 10.0;

  @override
  Future<GiftTransactionModel?> sendGift({
    required String recipientUserId,
    required double amount,
    String? message,
  }) async {
    return GiftTransactionModel(
      id: 'mock_tx_1',
      senderUserId: 'sender_1',
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      message: message,
    );
  }

  @override
  Future<List<GiftTransactionModel>> getGiftHistory() async => [];
}

void main() {
  late MockGiftRepository repository;

  setUp(() {
    repository = MockGiftRepository();
  });

  test('getEchoBalance returns a non-negative value', () async {
    final balance = await repository.getEchoBalance();
    expect(balance, greaterThanOrEqualTo(0));
  });

  test('sendGift returns a transaction model', () async {
    const recipientUserId = '42';
    const amount = 10.5;
    const message = 'Thanks for your help';

    final transaction = await repository.sendGift(
      recipientUserId: recipientUserId,
      amount: amount,
      message: message,
    );

    expect(transaction, isNotNull);
    expect(transaction, isA<GiftTransactionModel>());
    expect(transaction!.recipientUserId, recipientUserId);
    expect(transaction.echoAmount, amount);
    expect(transaction.message, message);
  });

  test('getGiftHistory returns a list', () async {
    final history = await repository.getGiftHistory();
    expect(history, isA<List<GiftTransactionModel>>());
  });

  group('GiftTransactionModel', () {
    test('isCompleted returns true when status is completed', () {
      final tx = GiftTransactionModel(
        id: '1',
        senderUserId: 's',
        recipientUserId: 'r',
        echoAmount: 10.0,
        createdAt: DateTime.now(),
        status: 'completed',
      );
      expect(tx.isCompleted, isTrue);
    });

    test('isCompleted returns false when status is not completed', () {
      final tx = GiftTransactionModel(
        id: '1',
        senderUserId: 's',
        recipientUserId: 'r',
        echoAmount: 10.0,
        createdAt: DateTime.now(),
        status: 'pending',
      );
      expect(tx.isCompleted, isFalse);
    });

    test('fromSupabase creates model from row', () {
      final now = DateTime.now();
      final row = {
        'id': 'uuid-1',
        'sender_user_id': 'user-a',
        'recipient_user_id': 'user-b',
        'echo_amount': 25.5,
        'created_at': now.toIso8601String(),
        'status': 'completed',
        'stellar_tx_hash': 'hashxyz',
        'message': 'Hello',
      };

      final model = GiftTransactionModel.fromSupabase(row);

      expect(model.id, 'uuid-1');
      expect(model.senderUserId, 'user-a');
      expect(model.recipientUserId, 'user-b');
      expect(model.echoAmount, 25.5);
      expect(model.status, 'completed');
      expect(model.stellarTxHash, 'hashxyz');
      expect(model.message, 'Hello');
    });
  });
}
