import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletState {
  const WalletState({this.publicKey, this.isLoading = false, this.error});

  final String? publicKey;
  final bool isLoading;
  final String? error;

  WalletState copyWith({
    String? publicKey,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearPublicKey = false,
  }) {
    return WalletState(
      publicKey: clearPublicKey ? null : publicKey ?? this.publicKey,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState()) {
    loadPublicKey();
  }

  Future<void> loadPublicKey() async {
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
          .select('public_key')
          .eq('user_id', userId)
          .maybeSingle();

      if (wallet == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No wallet found for this account.',
        );
        return;
      }

      state = state.copyWith(
        publicKey: wallet['public_key'] as String,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      debugPrint('[WalletNotifier] loadPublicKey error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to load your wallet.',
      );
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});