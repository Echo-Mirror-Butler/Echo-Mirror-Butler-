import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // TODO: replace with mock client when serverpod generate is run
  late GiftRepository repository;

  setUp(() {
    repository = GiftRepository();
  });

  test('getEchoBalance returns a non-negative value', () async {
    final balance = await repository.getEchoBalance();

    expect(balance, greaterThanOrEqualTo(0));
  });

  test('sendGift returns a transaction model', () async {
    const recipientUserId = 42;
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
