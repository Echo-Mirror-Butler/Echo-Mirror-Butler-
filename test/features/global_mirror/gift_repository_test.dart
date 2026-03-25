import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGiftRepository implements GiftRepository {
  @override
  SupabaseClient? get client => null;

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
}
