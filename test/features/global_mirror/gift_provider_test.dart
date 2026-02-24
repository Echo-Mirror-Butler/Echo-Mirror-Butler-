import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/gift_provider.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';

/// Mock implementation of GiftRepository for testing
class MockGiftRepository implements GiftRepository {
  double _mockBalance = 0.0;
  List<GiftTransactionModel> _mockHistory = [];
  bool _shouldFailGetBalance = false;
  bool _shouldFailSendGift = false;

  MockGiftRepository({
    double initialBalance = 0.0,
    List<GiftTransactionModel>? initialHistory,
  })  : _mockBalance = initialBalance,
        _mockHistory = initialHistory ?? [];

  void setBalance(double balance) => _mockBalance = balance;

  void setHistory(List<GiftTransactionModel> history) => _mockHistory = history;

  void setFailGetBalance(bool fail) => _shouldFailGetBalance = fail;

  void setFailSendGift(bool fail) => _shouldFailSendGift = fail;

  @override
  Future<double> getEchoBalance() async {
    if (_shouldFailGetBalance) {
      throw Exception('Failed to fetch balance');
    }
    return _mockBalance;
  }

  @override
  Future<GiftTransactionModel?> sendGift({
    required int recipientUserId,
    required double amount,
    String? message,
  }) async {
    if (_shouldFailSendGift) {
      throw Exception('Failed to send gift');
    }

    // Check balance constraint
    if (amount > _mockBalance) {
      return null;
    }

    final tx = GiftTransactionModel(
      id: 1,
      senderUserId: 0,
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      stellarTxHash: null,
      message: message,
    );

    _mockBalance -= amount;
    return tx;
  }

  @override
  Future<List<GiftTransactionModel>> getGiftHistory() async {
    if (_shouldFailGetBalance) {
      throw Exception('Failed to fetch history');
    }
    return _mockHistory;
  }
}

void main() {
  group('GiftNotifier', () {
    late MockGiftRepository mockRepo;

    setUp(() {
      mockRepo = MockGiftRepository();
    });

    test('Initial state has correct default values', () {
      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final state = container.read(giftProvider);

      expect(state.echoBalance, 0.0);
      expect(state.history, isEmpty);
      expect(state.isSending, false);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.lastSentTx, isNull);
    });

    test('loadBalance() sets isLoading to true then false and updates balance',
        () async {
      mockRepo.setBalance(100.0);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      // Initially isLoading should be false
      expect(container.read(giftProvider).isLoading, false);
      expect(container.read(giftProvider).echoBalance, 0.0);

      // Call loadBalance
      final loadingFuture = notifier.loadBalance();

      // Check isLoading is true during the operation
      await Future.delayed(Duration(milliseconds: 10));
      expect(container.read(giftProvider).isLoading, true);

      // Wait for completion
      await loadingFuture;

      // After completion, isLoading should be false and balance should be updated
      expect(container.read(giftProvider).isLoading, false);
      expect(container.read(giftProvider).echoBalance, 100.0);
    });

    test('sendGift() sets isSending to true then false on success', () async {
      mockRepo.setBalance(50.0);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      // Initially isSending should be false
      expect(container.read(giftProvider).isSending, false);

      // Call sendGift
      final sendingFuture = notifier.sendGift(
        recipientUserId: 123,
        amount: 25.0,
        message: 'Happy birthday!',
      );

      // Check isSending is true during the operation
      await Future.delayed(Duration(milliseconds: 10));
      expect(container.read(giftProvider).isSending, true);

      // Wait for completion
      final success = await sendingFuture;

      // After completion, isSending should be false and result should be true
      expect(container.read(giftProvider).isSending, false);
      expect(success, true);
      expect(container.read(giftProvider).lastSentTx, isNotNull);
    });

    test('sendGift() updates echoBalance after successful send', () async {
      mockRepo.setBalance(50.0);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      expect(container.read(giftProvider).echoBalance, 50.0);

      final success = await notifier.sendGift(
        recipientUserId: 123,
        amount: 20.0,
      );

      expect(success, true);
      expect(container.read(giftProvider).echoBalance, 30.0);
    });

    test('sendGift() with insufficient balance sets error and does not call repo',
        () async {
      mockRepo.setBalance(10.0);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      final success = await notifier.sendGift(
        recipientUserId: 123,
        amount: 50.0, // More than available balance
      );

      // Should fail because balance is insufficient
      expect(success, false);
      expect(container.read(giftProvider).error, isNotNull);
      expect(
        container.read(giftProvider).error,
        'Failed to send gift. Check your balance and try again.',
      );
      // Balance should remain unchanged
      expect(container.read(giftProvider).echoBalance, 10.0);
    });

    test('sendGift() on repository error sets error state', () async {
      mockRepo.setBalance(100.0);
      mockRepo.setFailSendGift(true);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      final success = await notifier.sendGift(
        recipientUserId: 123,
        amount: 25.0,
      );

      expect(success, false);
      expect(container.read(giftProvider).isSending, false);
      expect(container.read(giftProvider).error, isNotNull);
      expect(
        container.read(giftProvider).error,
        'Failed to send gift. Check your balance and try again.',
      );
      // Balance should remain unchanged on error
      expect(container.read(giftProvider).echoBalance, 100.0);
    });

    test('loadHistory() updates the history list', () async {
      final mockTx = GiftTransactionModel(
        id: 1,
        senderUserId: 0,
        recipientUserId: 456,
        echoAmount: 25.0,
        createdAt: DateTime.now(),
        status: 'completed',
        stellarTxHash: null,
        message: null,
      );
      mockRepo.setHistory([mockTx]);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      expect(container.read(giftProvider).history, isEmpty);

      await notifier.loadHistory();

      expect(container.read(giftProvider).history, hasLength(1));
      expect(container.read(giftProvider).history.first.id, 1);
      expect(container.read(giftProvider).history.first.recipientUserId, 456);
    });

    test('sendGift() clears previous error on new attempt', () async {
      mockRepo.setBalance(50.0);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      // First attempt fails with insufficient balance
      await notifier.sendGift(
        recipientUserId: 123,
        amount: 100.0,
      );

      expect(container.read(giftProvider).error, isNotNull);

      // Second attempt succeeds
      final success = await notifier.sendGift(
        recipientUserId: 456,
        amount: 20.0,
      );

      expect(success, true);
      expect(container.read(giftProvider).error, isNull);
    });

    test('sendGift() stores lastSentTx on success', () async {
      mockRepo.setBalance(100.0);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      final success = await notifier.sendGift(
        recipientUserId: 789,
        amount: 35.0,
        message: 'Test gift',
      );

      expect(success, true);
      final lastTx = container.read(giftProvider).lastSentTx;
      expect(lastTx, isNotNull);
      expect(lastTx!.recipientUserId, 789);
      expect(lastTx.echoAmount, 35.0);
      expect(lastTx.message, 'Test gift');
    });

    test('sendGift() clears lastSentTx on new attempt', () async {
      mockRepo.setBalance(100.0);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      // First gift
      await notifier.sendGift(
        recipientUserId: 123,
        amount: 20.0,
      );
      expect(container.read(giftProvider).lastSentTx, isNotNull);

      // Start second gift (which will fail)
      await notifier.sendGift(
        recipientUserId: 456,
        amount: 100.0, // Insufficient balance
      );

      // lastSentTx should be cleared
      expect(container.read(giftProvider).lastSentTx, isNull);
    });

    test('loadBalance() clears previous error', () async {
      mockRepo.setBalance(50.0);
      mockRepo.setFailSendGift(true);

      final container = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(giftProvider.notifier);

      // Create an error state
      await notifier.sendGift(
        recipientUserId: 123,
        amount: 25.0,
      );
      expect(container.read(giftProvider).error, isNotNull);

      // Reset mock to allow success
      mockRepo.setFailSendGift(false);

      // Load balance should clear the error
      await notifier.loadBalance();

      expect(container.read(giftProvider).error, isNull);
      expect(container.read(giftProvider).echoBalance, 50.0);
    });
  });
}
