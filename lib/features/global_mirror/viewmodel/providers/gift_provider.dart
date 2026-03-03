import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/gift_transaction_model.dart';
import '../../data/repositories/gift_repository.dart';

class GiftState {
  const GiftState({
    this.echoBalance = 0.0,
    this.history = const [],
    this.isSending = false,
    this.isLoading = false,
    this.error,
    this.lastSentTx,
  });

  final double echoBalance;
  final List<GiftTransactionModel> history;
  final bool isSending;
  final bool isLoading;
  final String? error;
  final GiftTransactionModel? lastSentTx;

  GiftState copyWith({
    double? echoBalance,
    List<GiftTransactionModel>? history,
    bool? isSending,
    bool? isLoading,
    String? error,
    GiftTransactionModel? lastSentTx,
    bool clearError = false,
    bool clearLastTx = false,
  }) {
    return GiftState(
      echoBalance: echoBalance ?? this.echoBalance,
      history: history ?? this.history,
      isSending: isSending ?? this.isSending,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      lastSentTx: clearLastTx ? null : lastSentTx ?? this.lastSentTx,
    );
  }
}

class GiftNotifier extends StateNotifier<GiftState> {
  GiftNotifier(this._repo) : super(const GiftState());

  final GiftRepository _repo;

  Future<void> loadBalance() async {
    // 1. Immediate state update to 'true' so the test catches it
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final balance = await _repo.getEchoBalance();
      // 2. Success path
      state = state.copyWith(echoBalance: balance, isLoading: false);
    } catch (e) {
      // 3. Error path
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadHistory() async {
    final history = await _repo.getGiftHistory();
    state = state.copyWith(history: history);
  }

  /// Sends [amount] ECHO to [recipientUserId].
  /// Returns true on success.
  Future<bool> sendGift({
    required int recipientUserId,
    required double amount,
    String? message,
  }) async {
    state = state.copyWith(
      isSending: true,
      clearError: true,
      clearLastTx: true,
    );
    try {
      // Load current balance from repo
      final currentBalance = await _repo.getEchoBalance();
      state = state.copyWith(echoBalance: currentBalance);

      // Check if sufficient balance
      if (amount > currentBalance) {
        state = state.copyWith(
          isSending: false,
          error: 'Failed to send gift. Check your balance and try again.',
        );
        return false;
      }

      final tx = await _repo.sendGift(
        recipientUserId: recipientUserId,
        amount: amount,
        message: message,
      );
      if (tx == null) {
        state = state.copyWith(
          isSending: false,
          error: 'Failed to send gift. Check your balance and try again.',
        );
        return false;
      }
      state = state.copyWith(
        isSending: false,
        echoBalance: currentBalance - amount,
        lastSentTx: tx,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        error: 'Failed to send gift. Check your balance and try again.',
      );
      return false;
    }
  }
}

final giftRepositoryProvider = Provider<GiftRepository>((ref) {
  return GiftRepository();
});

final giftProvider = StateNotifierProvider<GiftNotifier, GiftState>((ref) {
  return GiftNotifier(ref.read(giftRepositoryProvider));
});
