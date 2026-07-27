import 'package:echomirror/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:echomirror/features/leaderboard/viewmodel/providers/leaderboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/leaderboard_test_helpers.dart';

/// Issue #599 — provider/state coverage for the leaderboard feature: the
/// loading, error, success and empty states, plus the current-user highlight
/// state produced when a real id is supplied (wired in #598).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LeaderboardState', () {
    test('has sensible defaults', () {
      const state = LeaderboardState();
      expect(state.entries, isEmpty);
      expect(state.currentUserRank, isNull);
      expect(state.currentUserEntry, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith produces a loading state', () {
      const state = LeaderboardState();
      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);
      expect(loading.error, isNull);
    });

    test('copyWith produces an error state', () {
      const state = LeaderboardState(isLoading: true);
      final errored = state.copyWith(
        isLoading: false,
        error: 'Failed to load leaderboard',
      );
      expect(errored.isLoading, isFalse);
      expect(errored.error, 'Failed to load leaderboard');
    });

    test('copyWith clearError wipes a previous error', () {
      const state = LeaderboardState(error: 'boom');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('represents a successful populated state', () {
      final entries = [
        buildEntry(id: 'a', rank: 1, echo: 300),
        buildEntry(id: 'b', rank: 2, echo: 200),
      ];
      final state = LeaderboardState(entries: entries, isLoading: false);
      expect(state.entries, hasLength(2));
      expect(state.entries.first.rank, 1);
      expect(state.isLoading, isFalse);
    });

    test('represents an empty (no entries this week) state', () {
      const state = LeaderboardState(entries: <LeaderboardEntryModel>[]);
      expect(state.entries, isEmpty);
      expect(state.error, isNull);
    });

    test('carries current-user rank/entry for the highlight', () {
      final entry = buildEntry(id: kTestUserId, rank: 12, echo: 40);
      final state = LeaderboardState(
        entries: [buildEntry(id: 'a', rank: 1)],
        currentUserRank: 12,
        currentUserEntry: entry,
      );
      expect(state.currentUserRank, 12);
      expect(state.currentUserEntry?.id, kTestUserId);
    });
  });

  group('LeaderboardNotifier', () {
    test('starts in an empty, non-loading state', () {
      final notifier = LeaderboardNotifier();
      addTearDown(notifier.dispose);
      expect(notifier.state.entries, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test(
      'loadLeaderboard sets an error state when the backend is unavailable',
      () async {
        // Supabase is not initialized in the test environment, so the fetch
        // throws and is caught into the error branch. This exercises the
        // loading -> error transition end-to-end.
        final notifier = LeaderboardNotifier();
        addTearDown(notifier.dispose);

        await notifier.loadLeaderboard(userId: 'user-1');

        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, 'Failed to load leaderboard');
        expect(notifier.state.entries, isEmpty);
      },
    );

    test('refresh delegates to loadLeaderboard', () async {
      final notifier = LeaderboardNotifier();
      addTearDown(notifier.dispose);

      await notifier.refresh(userId: 'user-1');

      // Same error branch as above, confirming refresh runs the same path.
      expect(notifier.state.error, 'Failed to load leaderboard');
    });
  });
}
