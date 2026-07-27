import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/leaderboard_entry_model.dart';

/// Leaderboard state
class LeaderboardState {
  const LeaderboardState({
    this.entries = const [],
    this.currentUserRank,
    this.currentUserEntry,
    this.isLoading = false,
    this.error,
  });

  final List<LeaderboardEntryModel> entries;
  final int? currentUserRank;
  final LeaderboardEntryModel? currentUserEntry;
  final bool isLoading;
  final String? error;

  LeaderboardState copyWith({
    List<LeaderboardEntryModel>? entries,
    int? currentUserRank,
    LeaderboardEntryModel? currentUserEntry,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      currentUserRank: currentUserRank ?? this.currentUserRank,
      currentUserEntry: currentUserEntry ?? this.currentUserEntry,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Leaderboard notifier
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier() : super(const LeaderboardState());

  /// Hard cap for the weekly board (Issue #637 audit — already bounded).
  static const int pageSize = 20;

  Future<void> loadLeaderboard({String? userId}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;

      // Bounded fetch — never load the full leaderboard_weekly set
      final response = await supabase
          .from('leaderboard_weekly')
          .select('*')
          .order('rank', ascending: true)
          .limit(pageSize);

      final entries = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((json) => LeaderboardEntryModel.fromJson(json))
          .toList();

      // Fetch current user's rank if userId is provided
      int? currentUserRank;
      LeaderboardEntryModel? currentUserEntry;

      if (userId != null && userId.isNotEmpty) {
        final userResponse = await supabase
            .from('leaderboard_weekly')
            .select('*')
            .eq('id', userId)
            .maybeSingle();

        if (userResponse != null) {
          currentUserRank = userResponse['rank'] as int?;
          currentUserEntry = LeaderboardEntryModel.fromJson(
              userResponse as Map<String, dynamic>);
        }
      }

      state = LeaderboardState(
        entries: entries,
        currentUserRank: currentUserRank,
        currentUserEntry: currentUserEntry,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load leaderboard',
        isLoading: false,
      );
    }
  }

  /// Refresh leaderboard data
  Future<void> refresh({String? userId}) async {
    await loadLeaderboard(userId: userId);
  }
}

/// Leaderboard provider
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier();
});

/// Current user ID provider (from auth)
final currentUserIdProvider = Provider<String?>((ref) {
  // This will be provided by the auth provider when used
  return null;
});

/// Async leaderboard provider that auto-loads with user ID
final asyncLeaderboardProvider = FutureProvider<LeaderboardState>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final notifier = ref.watch(leaderboardProvider.notifier);
  
  await notifier.loadLeaderboard(userId: userId);
  return ref.watch(leaderboardProvider);
});
