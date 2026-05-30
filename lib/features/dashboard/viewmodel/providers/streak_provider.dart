import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StreakState {
  const StreakState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLogDate,
    this.isLoading = false,
    this.error,
  });

  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLogDate;
  final bool isLoading;
  final String? error;

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastLogDate,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLogDate: lastLogDate ?? this.lastLogDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class StreakNotifier extends StateNotifier<StreakState> {
  StreakNotifier() : super(const StreakState());

  Future<void> loadStreak(String userId) async {
    if (userId.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.rpc(
        'calculate_streak',
        params: {'p_user_id': userId},
      );

      if (res == null) {
        state = state.copyWith(
          currentStreak: 0,
          longestStreak: 0,
          isLoading: false,
        );
        return;
      }

      final data = res as Map<String, dynamic>;
      state = StreakState(
        currentStreak: (data['current_streak'] as int?) ?? 0,
        longestStreak: (data['longest_streak'] as int?) ?? 0,
        lastLogDate: data['last_log_date'] != null
            ? DateTime.tryParse(data['last_log_date'] as String)
            : null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load streak data.',
        isLoading: false,
      );
    }
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>((
  ref,
) {
  return StreakNotifier();
});
