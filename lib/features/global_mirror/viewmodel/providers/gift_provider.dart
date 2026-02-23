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
    state = state.copyWith(isLoading: true, clearError: true);
    final balance = await _repo.getEchoBalance();
    state = state.copyWith(echoBalance: balance, isLoading: false);
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
    state = state.copyWith(isSending: true, clearError: true, clearLastTx: true);
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
      echoBalance: state.echoBalance - amount,
      lastSentTx: tx,
    );
    return true;
  }
}

final giftRepositoryProvider = Provider<GiftRepository>((ref) {
  return GiftRepository();
});

final giftProvider = StateNotifierProvider<GiftNotifier, GiftState>((ref) {
  return GiftNotifier(ref.read(giftRepositoryProvider));
});
