import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/environment_config.dart';
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
    this.isFunding = false,
    this.isLiveBalancesLoading = false,
    this.error,
    this.fundingError,
    this.funded = false,
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

  /// True while a Friendbot funding request is in flight.
  final bool isFunding;

  /// True while the background Horizon balance refresh is in flight.
  final bool isLiveBalancesLoading;

  final String? error;
  final String? fundingError;

  /// True when Horizon reports a positive XLM balance for this account.
  final bool funded;
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
    bool? isFunding,
    bool? isLiveBalancesLoading,
    String? error,
    String? fundingError,
    bool? funded,
    DateTime? lastUpdated,
    String? stellarError,
    bool? isFunding,
    bool clearError = false,
    bool clearFundingError = false,
  }) {
    return WalletState(
      exists: exists ?? this.exists,
      publicKey: publicKey ?? this.publicKey,
      balance: balance ?? this.balance,
      xlmBalance: xlmBalance ?? this.xlmBalance,
      echoBalance: echoBalance ?? this.echoBalance,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isFunding: isFunding ?? this.isFunding,
      isLiveBalancesLoading:
          isLiveBalancesLoading ?? this.isLiveBalancesLoading,
      error: clearError ? null : error ?? this.error,
      fundingError: clearFundingError ? null : fundingError ?? this.fundingError,
      funded: funded ?? this.funded,
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
    // Only auto-refresh the live balances on testnet, where activation
    // can change rapidly. Mainnet users don't see live balances in this UI.
    if (EnvironmentConfig.isTestnet) {
      _liveBalanceTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _safeRefreshLiveBalances(),
      );
    }
  }

  /// Auto-refresh interval for live Horizon balances on testnet.
  @visibleForTesting
  static const Duration liveRefreshInterval = Duration(seconds: 30);

  Timer? _liveBalanceTimer;

  @override
  void dispose() {
    _liveBalanceTimer?.cancel();
    _liveBalanceTimer = null;
    super.dispose();
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

      final balance =
          double.tryParse(wallet['balance']?.toString() ?? '') ?? 0.0;

      final publicKey = wallet['public_key'] as String?;

      state = WalletState(
        exists: true,
        publicKey: publicKey,
        balance:
            double.tryParse(wallet['balance']?.toString() ?? '') ?? 0.0,
        history: history,
        isLoading: false,
        // Treat a wallet that already has ECHO balance as likely funded —
        // this avoids flashing the Activation Required card on cached
        // sessions before Horizon responds. The next refresh will flip
        // funded back to `false` if the account is genuinely inactive.
        funded: balance > 0,
      );

      // Pull live balances right after the wallet hydrates so the UI can
      // show XLM and the funded/unfunded state without an extra tap.
      unawaited(refreshLiveBalances());
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
        body: {},
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

  /// Fetches live XLM + ECHO balances from Horizon for the current wallet.
  ///
  /// Sets [WalletState.funded] to `true` when Horizon reports a non-zero
  /// XLM balance. When Horizon returns 404 (account not yet activated),
  /// [WalletState.funded] is set to `false` and the UI can render the
  /// "not funded" state with the Friendbot CTA.
  Future<void> refreshLiveBalances() async {
    final publicKey = state.publicKey;
    if (publicKey == null || publicKey.isEmpty) return;

    state = state.copyWith(isLiveBalancesLoading: true, clearFundingError: true);

    try {
      final balances = await StellarService.getLiveBalances(publicKey);
      state = state.copyWith(
        xlmBalance: balances.xlm,
        // Prefer the live ECHO balance when present; fall back to Supabase
        // value if Horizon hasn't yet indexed the trustline.
        balance: balances.echo > 0 ? balances.echo : state.balance,
        isLiveBalancesLoading: false,
        funded: balances.isFunded,
        clearFundingError: true,
      );
    } on AccountNotFoundException catch (e) {
      debugPrint('[WalletNotifier] refreshLiveBalances not found: $e');
      state = state.copyWith(
        isLiveBalancesLoading: false,
        funded: false,
        xlmBalance: 0.0,
        clearFundingError: true,
      );
    } catch (e) {
      debugPrint('[WalletNotifier] refreshLiveBalances error: $e');
      // Don't overwrite the primary error state — live balances are
      // best-effort and will refresh again in 30s.
      state = state.copyWith(isLiveBalancesLoading: false);
    }
  }

  Future<void> _safeRefreshLiveBalances() async {
    try {
      await refreshLiveBalances();
    } catch (_) {
      // Swallow — refreshLiveBalances already records state.
    }
  }

  /// Funds the current wallet using Stellar Friendbot (testnet only).
  ///
  /// On success the live XLM + ECHO balances are refreshed. On failure a
  /// user-facing message is stored in [WalletState.fundingError] so the UI
  /// can surface it as a toast.
  Future<bool> fundWithFriendbot() async {
    final publicKey = state.publicKey;
    if (publicKey == null || publicKey.isEmpty) {
      state = state.copyWith(
        fundingError: 'No wallet to fund yet.',
      );
      return false;
    }

    state = state.copyWith(
      isFunding: true,
      clearFundingError: true,
    );

    try {
      await StellarService.fundWithFriendbot(publicKey);
      debugPrint('[WalletNotifier] Friendbot funded $publicKey');
      state = state.copyWith(
        isFunding: false,
        funded: true,
        clearFundingError: true,
      );
      // Refresh right away so the user sees the new XLM balance without
      // waiting for the next periodic tick.
      await refreshLiveBalances();
      return true;
    } catch (e) {
      debugPrint('[WalletNotifier] fundWithFriendbot error: $e');
      state = state.copyWith(
        isFunding: false,
        fundingError: 'Friendbot unavailable — try again later',
      );
      return false;
    }
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});
