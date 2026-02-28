import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/gift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockGiftRepository implements GiftRepository {
  double _balance = 100.0;
  final List<GiftTransactionModel> _history = [];
  bool _shouldFailSendGift = false;
  double _failSendGiftWhenAmountGreaterThan = double.infinity;

  void setBalance(double balance) {
    _balance = balance;
  }

  void setHistory(List<GiftTransactionModel> history) {
    _history.clear();
    _history.addAll(history);
  }

  void setSendGiftFailure(
    bool shouldFail, {
    double? failWhenAmountGreaterThan,
  }) {
    _shouldFailSendGift = shouldFail;
    _failSendGiftWhenAmountGreaterThan =
        failWhenAmountGreaterThan ?? double.infinity;
  }

  @override
  Future<double> getEchoBalance() async {
    return _balance;
  }

  @override
  Future<GiftTransactionModel?> sendGift({
    required int recipientUserId,
    required double amount,
    String? message,
  }) async {
    if (_shouldFailSendGift || amount > _failSendGiftWhenAmountGreaterThan) {
      return null;
    }

    if (amount > _balance) {
      return null;
    }

    _balance -= amount;

    final transaction = GiftTransactionModel(
      id: _history.length + 1,
      senderUserId: 1, // Mock sender ID
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      stellarTxHash: 'mock_tx_hash_${_history.length + 1}',
      message: message,
    );

    _history.add(transaction);
    return transaction;
  }

  @override
  Future<List<GiftTransactionModel>> getGiftHistory() async {
    return List.unmodifiable(_history);
  }
}

void main() {
  group('Gift Flow End-to-End Tests', () {
    late MockGiftRepository mockRepo;
    late GiftNotifier giftNotifier;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockGiftRepository();
      container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      giftNotifier = GiftNotifier(mockRepo);
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Initial balance is non-negative', () async {
      mockRepo.setBalance(50.0);

      await giftNotifier.loadBalance();

      expect(giftNotifier.state.echoBalance, 50.0);
      expect(giftNotifier.state.echoBalance, greaterThanOrEqualTo(0));
    });

    test(
      '2. After sendGift(recipientUserId, 5.0), balance decreases by 5.0',
      () async {
      mockRepo.setBalance(100.0);
      await giftNotifier.loadBalance();

      final initialBalance = giftNotifier.state.echoBalance;
      const recipientUserId = 42;
      const amount = 5.0;

      final success = await giftNotifier.sendGift(
        recipientUserId: recipientUserId,
        amount: amount,
        message: 'Test gift',
      );

      expect(success, isTrue);
      expect(giftNotifier.state.echoBalance, initialBalance - amount);
      expect(giftNotifier.state.lastSentTx, isNotNull);
      expect(giftNotifier.state.lastSentTx!.recipientUserId, recipientUserId);
      expect(giftNotifier.state.lastSentTx!.echoAmount, amount);
      expect(giftNotifier.state.error, isNull);
    });

    test('3. getGiftHistory() contains the sent transaction', () async {
      mockRepo.setBalance(100.0);
      await giftNotifier.loadBalance();

      const recipientUserId = 123;
      const amount = 10.0;
      const message = 'History test gift';

      await giftNotifier.sendGift(
        recipientUserId: recipientUserId,
        amount: amount,
        message: message,
      );

      await giftNotifier.loadHistory();

      expect(giftNotifier.state.history, isNotEmpty);
      expect(giftNotifier.state.history.length, 1);

      final transaction = giftNotifier.state.history.first;
      expect(transaction.recipientUserId, recipientUserId);
      expect(transaction.echoAmount, amount);
      expect(transaction.message, message);
      expect(transaction.status, 'completed');
    });

    test('4. Sending more ECHO than balance returns null / error', () async {
      mockRepo.setBalance(25.0);
      await giftNotifier.loadBalance();

      const recipientUserId = 456;
      const amount = 50.0; // More than balance

      final success = await giftNotifier.sendGift(
        recipientUserId: recipientUserId,
        amount: amount,
        message: 'Should fail',
      );

      expect(success, isFalse);
      expect(giftNotifier.state.lastSentTx, isNull);
      expect(giftNotifier.state.error, isNotNull);
      expect(giftNotifier.state.error, contains('Failed to send gift'));

      // Balance should remain unchanged
      expect(giftNotifier.state.echoBalance, 25.0);
    });

    test(
      '5. GiftNotifier state reflects balance changes after sendGift',
      () async {
      mockRepo.setBalance(200.0);
      await giftNotifier.loadBalance();

      const recipientUserId = 789;
      const firstAmount = 30.0;
      const secondAmount = 20.0;

      // Initial state
      expect(giftNotifier.state.isSending, isFalse);
      expect(giftNotifier.state.lastSentTx, isNull);
      expect(giftNotifier.state.error, isNull);

      // First gift
      final firstSuccess = await giftNotifier.sendGift(
        recipientUserId: recipientUserId,
        amount: firstAmount,
        message: 'First gift',
      );

      expect(firstSuccess, isTrue);
      expect(giftNotifier.state.echoBalance, 170.0); // 200 - 30
      expect(giftNotifier.state.lastSentTx, isNotNull);
      expect(giftNotifier.state.lastSentTx!.echoAmount, firstAmount);
      expect(giftNotifier.state.isSending, isFalse);
      expect(giftNotifier.state.error, isNull);

      // Second gift
      final secondSuccess = await giftNotifier.sendGift(
        recipientUserId: recipientUserId,
        amount: secondAmount,
        message: 'Second gift',
      );

      expect(secondSuccess, isTrue);
      expect(giftNotifier.state.echoBalance, 150.0); // 170 - 20
      expect(giftNotifier.state.lastSentTx, isNotNull);
      expect(giftNotifier.state.lastSentTx!.echoAmount, secondAmount);
      expect(giftNotifier.state.isSending, isFalse);
      expect(giftNotifier.state.error, isNull);
    });

    test(
      '6. Multiple transactions appear in history in chronological order',
      () async {
      mockRepo.setBalance(100.0);
      await giftNotifier.loadBalance();

      // Send multiple gifts
      await giftNotifier.sendGift(
        recipientUserId: 1,
        amount: 10.0,
        message: 'First',
      );
      await giftNotifier.sendGift(
        recipientUserId: 2,
        amount: 15.0,
        message: 'Second',
      );
      await giftNotifier.sendGift(
        recipientUserId: 3,
        amount: 5.0,
        message: 'Third',
      ),

      await giftNotifier.loadHistory();

      expect(giftNotifier.state.history.length, 3);

      // Check chronological order (first transaction should be oldest)
      expect(giftNotifier.state.history[0].echoAmount, 10.0);
      expect(giftNotifier.state.history[1].echoAmount, 15.0);
      expect(giftNotifier.state.history[2].echoAmount, 5.0);

      // Check all transactions are completed
      for (final transaction in giftNotifier.state.history) {
        expect(transaction.isCompleted, isTrue);
        expect(transaction.status, 'completed');
      }
    });

    test('7. Loading state updates correctly during operations', () async {
      mockRepo.setBalance(50.0);

      // Test loading state for balance
      expect(giftNotifier.state.isLoading, isFalse);

      final loadBalanceFuture = giftNotifier.loadBalance();
      expect(giftNotifier.state.isLoading, isTrue);

      await loadBalanceFuture;
      expect(giftNotifier.state.isLoading, isFalse);
      expect(giftNotifier.state.echoBalance, 50.0);

      // Test sending state
      expect(giftNotifier.state.isSending, isFalse);

      final sendGiftFuture = giftNotifier.sendGift(
        recipientUserId: 999,
        amount: 5.0,
        message: 'Loading test',
      );
      expect(giftNotifier.state.isSending, isTrue);

      await sendGiftFuture;
      expect(giftNotifier.state.isSending, isFalse);
    });
  });
}
