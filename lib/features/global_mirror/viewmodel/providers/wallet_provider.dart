import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/stellar/stellar_service.dart';

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
    this.xlmBalance = 0.0,
    this.echoBalance = 0.0,
    this.history = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.stellarError,
    this.isFunding = false,
  });

  final bool exists;
  final String? publicKey;
  final double balance;
  final double xlmBalance;
  final double echoBalance;
  final List<WalletReward> history;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final String? stellarError;
  final bool isFunding;

  bool get hasStreakBonus {
    return history.any(
      (reward) =>
          reward.reason.contains('streak') ||
          reward.reason.contains('bonus'),
    );
  }

  bool get isUnfunded => stellarError != null;
  bool get isStellarUnreachable => stellarError != null;

  WalletState copyWith({
    bool? exists,
    String? publicKey,
    double? balance,
    double? xlmBalance,
    double? echoBalance,
    List<WalletReward>? history,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    String? stellarError,
    bool? isFunding,
    bool clearError = false,
  }) {
    return WalletState(
      exists: exists ?? this.exists,
      publicKey: publicKey ?? this.publicKey,
      balance: balance ?? this.balance,
      xlmBalance: xlmBalance ?? this.xlmBalance,
      echoBalance: echoBalance ?? this.echoBalance,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      stellarError: stellarError ?? this.stellarError,
      isFunding: isFunding ?? this.isFunding,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  Timer? _refreshTimer;

  WalletNotifier() : super(const WalletState()) {
    loadWallet();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchLiveBalances();
    });
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

      final history = (historyData as List<dynamic>?)
              ?.map((item) {
                return WalletReward(
                  reason: item['reason'] as String? ?? 'Unknown',
                  amount:
                      double.tryParse(item['amount']?.toString() ?? '') ?? 0.0,
                  createdAt: DateTime.parse(item['created_at'] as String),
                );
              })
              .toList() ??
          [];

      final publicKey = wallet['public_key'] as String?;

      state = WalletState(
        exists: true,
        publicKey: publicKey,
        balance:
            double.tryParse(wallet['balance']?.toString() ?? '') ?? 0.0,
        history: history,
        isLoading: false,
      );

      if (publicKey != null) {
        _fetchLiveBalances();
      }
      _startAutoRefresh();
    } catch (e) {
      debugPrint('[WalletNotifier] loadWallet error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load your wallet.',
      );
    }
  }

  Future<void> _fetchLiveBalances() async {
    final publicKey = state.publicKey;
    if (publicKey == null) return;

    try {
      final balances =
          await StellarService.getLiveBalances(publicKey);
      if (balances == null) {
        state = state.copyWith(
          stellarError: 'Activate your wallet — send any XLM to fund it',
          lastUpdated: DateTime.now(),
        );
        return;
      }
      state = state.copyWith(
        xlmBalance: balances['xlm'] ?? 0.0,
        echoBalance: balances['echo'] ?? 0.0,
        stellarError: null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[WalletNotifier] Live balance fetch error: $e');
      state = state.copyWith(
        stellarError: 'Could not reach Stellar network',
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> fundWithFriendbot() async {
    final publicKey = state.publicKey;
    if (publicKey == null) return;

    state = state.copyWith(isFunding: true);

    try {
      final success = await StellarService.fundViaFriendbot(publicKey);
      if (success) {
        await Future.delayed(const Duration(seconds: 5));
        await _fetchLiveBalances();
        state = state.copyWith(isFunding: false, stellarError: null);
      } else {
        state = state.copyWith(
          isFunding: false,
          stellarError: 'Friendbot funding failed. Try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isFunding: false,
        stellarError: 'Funding failed. Please retry.',
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

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});
