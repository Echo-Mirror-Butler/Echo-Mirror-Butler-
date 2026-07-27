import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/leaderboard_entry_model.dart';

/// State for the leaderboard feature.
class LeaderboardState {
  final List<LeaderboardEntryModel> entries;
  final LeaderboardEntryModel? currentUserEntry;
  final bool isLoading;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.currentUserEntry,
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntryModel>? entries,
    LeaderboardEntryModel? currentUserEntry,
    bool? isLoading,
    String? error,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      currentUserEntry: currentUserEntry ?? this.currentUserEntry,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier that fetches leaderboard data from the `leaderboard_weekly` view.
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier() : super(const LeaderboardState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Fetch top 20 entries
      final topResponse = await client
          .from('leaderboard_weekly')
          .select()
          .order('rank', ascending: true)
          .limit(20);

      final entries = (topResponse as List)
          .map((json) => LeaderboardEntryModel.fromJson(
              json as Map<String, dynamic>))
          .toList();

      // Fetch current user's rank if logged in and not in top 20
      LeaderboardEntryModel? currentUserEntry;
      if (userId != null) {
        final isInTop20 = entries.any((e) => e.id == userId);
        if (!isInTop20) {
          final userResponse = await client
              .from('leaderboard_weekly')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (userResponse != null) {
            currentUserEntry = LeaderboardEntryModel.fromJson(
                userResponse as Map<String, dynamic>);
          }
        }
      }

      state = state.copyWith(
        entries: entries,
        currentUserEntry: currentUserEntry,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Provider for the leaderboard state.
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier();
});

/// Provides the current user's Supabase ID for "is this me" highlighting.
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Async provider that auto-loads the leaderboard.
final asyncLeaderboardProvider = FutureProvider<void>((ref) async {
  await ref.read(leaderboardProvider.notifier).load();
});
