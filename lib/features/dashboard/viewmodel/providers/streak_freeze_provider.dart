import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StreakFreezeState {
  const StreakFreezeState({
    this.hasActiveFreeze = false,
    this.freezeDate,
    this.isLoading = false,
    this.isPurchasing = false,
    this.error,
    this.purchaseError,
  });

  final bool hasActiveFreeze;
  final String? freezeDate;
  final bool isLoading;
  final bool isPurchasing;
  final String? error;
  final String? purchaseError;

  StreakFreezeState copyWith({
    bool? hasActiveFreeze,
    String? freezeDate,
    bool? isLoading,
    bool? isPurchasing,
    String? error,
    String? purchaseError,
    bool clearError = false,
    bool clearPurchaseError = false,
  }) {
    return StreakFreezeState(
      hasActiveFreeze: hasActiveFreeze ?? this.hasActiveFreeze,
      freezeDate: freezeDate ?? this.freezeDate,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      error: clearError ? null : error ?? this.error,
      purchaseError: clearPurchaseError ? null : purchaseError ?? this.purchaseError,
    );
  }
}

class StreakFreezeNotifier extends StateNotifier<StreakFreezeState> {
  StreakFreezeNotifier() : super(const StreakFreezeState());

  final _supabase = Supabase.instance.client;

  Future<void> loadFreezeStatus(String userId) async {
    if (userId.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);

      final res = await _supabase
          .from('streak_freezes')
          .select('id, used_on_date')
          .eq('user_id', userId)
          .or('used_on_date.eq.$today,used_on_date.eq.$tomorrow')
          .maybeSingle();

      state = StreakFreezeState(
        hasActiveFreeze: res != null,
        freezeDate: res?['used_on_date']?.toString(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check freeze status.',
      );
    }
  }

  Future<bool> purchaseFreeze(String userId) async {
    if (userId.isEmpty) return false;

    state = state.copyWith(isPurchasing: true, clearPurchaseError: true);

    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);

      await _supabase
          .from('streak_freezes')
          .insert({
        'user_id': userId,
        'used_on_date': tomorrow,
        'echo_cost': 5,
      });

      state = StreakFreezeState(
        hasActiveFreeze: true,
        freezeDate: tomorrow,
        isPurchasing: false,
      );
      return true;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('insufficient') || msg.contains('balance')) {
        state = state.copyWith(
          isPurchasing: false,
          purchaseError: 'Insufficient ECHO balance. You need at least 5 ECHO.',
        );
      } else if (msg.contains('duplicate') || msg.contains('already') || msg.contains('unique')) {
        state = state.copyWith(
          isPurchasing: false,
          purchaseError: 'Streak is already frozen for tomorrow.',
        );
      } else if (msg.contains('rate') || msg.contains('7-day')) {
        state = state.copyWith(
          isPurchasing: false,
          purchaseError: 'Maximum 1 freeze per 7-day window.',
        );
      } else {
        state = state.copyWith(
          isPurchasing: false,
          purchaseError: 'Failed to purchase freeze: ${e.message}',
        );
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isPurchasing: false,
        purchaseError: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final streakFreezeProvider =
    StateNotifierProvider<StreakFreezeNotifier, StreakFreezeState>((ref) {
  return StreakFreezeNotifier();
});
