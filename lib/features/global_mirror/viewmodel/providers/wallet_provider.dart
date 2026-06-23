import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletReward {
  const WalletReward({
    required this.reason,
    required this.amount,
    required this.createdAt,
  });

  final String reason;
  final double amount;
  final DateTime createdAt;
}

class WalletState {
  const WalletState({
    this.exists = false,
    this.publicKey,
    this.balance = 0.0,
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  final bool exists;
  final String? publicKey;
  final double balance;
  final List<WalletReward> history;
  final bool isLoading;
  final String? error;

  bool get hasStreakBonus {
    return history.any(
      (reward) =>
          reward.reason.contains('streak') || reward.reason.contains('bonus'),
    );
  }

  WalletState copyWith({
    bool? exists,
    String? publicKey,
    double? balance,
    List<WalletReward>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WalletState(
      exists: exists ?? this.exists,
      publicKey: publicKey ?? this.publicKey,
      balance: balance ?? this.balance,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState()) {
    loadWallet();
  }

  Future<void> loadWallet() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated.');
        return;
      }

      final wallet = await supabase
          .from('user_wallets')
          .select('public_key, balance')
          .eq('user_id', userId)
          .maybeSingle();

      if (wallet == null) {
        state = const WalletState(exists: false, isLoading: false);
        return;
      }

      final historyData = await supabase
          .from('echo_rewards')
          .select('reason, amount, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final history =
          (historyData as List<dynamic>?)?.map((item) {
            return WalletReward(
              reason: item['reason'] as String? ?? 'Unknown',
              amount: double.tryParse(item['amount']?.toString() ?? '') ?? 0.0,
              createdAt: DateTime.parse(item['created_at'] as String),
            );
          }).toList() ??
          [];

      state = WalletState(
        exists: true,
        publicKey: wallet['public_key'] as String?,
        balance: double.tryParse(wallet['balance']?.toString() ?? '') ?? 0.0,
        history: history,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[WalletNotifier] loadWallet error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load your wallet.',
      );
    }
  }

  Future<void> createWallet() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated.');
        return;
      }

      final response = await supabase.functions.invoke(
        'create-stellar-wallet',
        body: {
          'type': 'INSERT',
          'schema': 'auth',
          'table': 'users',
          'record': {'id': userId},
        },
      );

      if (response.error != null) {
        throw response.error!;
      }

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      await loadWallet();
    } catch (e) {
      debugPrint('[WalletNotifier] createWallet error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to create wallet.',
      );
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((
  ref,
) {
  return WalletNotifier();
});
