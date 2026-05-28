import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EchoBalanceState {
  const EchoBalanceState({
    this.balance = 0.0,
    this.isLoading = false,
    this.error,
  });

  final double balance;
  final bool isLoading;
  final String? error;

  EchoBalanceState copyWith({
    double? balance,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EchoBalanceState(
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class EchoBalanceNotifier extends StateNotifier<EchoBalanceState> {
  EchoBalanceNotifier() : super(const EchoBalanceState());

  Future<void> loadBalance(String userId) async {
    if (userId.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('user_wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) {
        state = EchoBalanceState(balance: 0.0, isLoading: false);
        return;
      }

      final data = res;
      final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
      state = EchoBalanceState(balance: balance, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Unable to load your ECHO balance.',
        isLoading: false,
      );
    }
  }
}

final echoBalanceProvider =
    StateNotifierProvider<EchoBalanceNotifier, EchoBalanceState>((ref) {
      return EchoBalanceNotifier();
    });
