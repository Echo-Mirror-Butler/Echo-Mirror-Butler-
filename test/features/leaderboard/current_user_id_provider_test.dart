import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/leaderboard/viewmodel/providers/leaderboard_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/leaderboard_test_helpers.dart';

/// Issue #598 — `currentUserIdProvider` must resolve to the real authenticated
/// user's id (previously hardcoded to `null`), and `asyncLeaderboardProvider`
/// must forward that id to the current-user rank/highlight lookup while still
/// degrading gracefully (no crash, no highlight) when unauthenticated.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // AuthNotifier._checkAuthStatus reads SharedPreferences on construction.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'echo_remember_me': true,
    });
  });

  group('currentUserIdProvider', () {
    test('resolves to the authenticated user id from authProvider', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            buildMockAuthRepository(authenticated: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Let the constructor-driven auth check settle.
      await pumpEventQueue();

      expect(container.read(authProvider).user?.id, kTestUserId);
      expect(container.read(currentUserIdProvider), kTestUserId);
    });

    test('resolves to null when no user is authenticated', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            buildMockAuthRepository(authenticated: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await pumpEventQueue();

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(currentUserIdProvider), isNull);
    });
  });

  group('asyncLeaderboardProvider current-user highlight wiring', () {
    test('forwards the real authenticated id to loadLeaderboard', () async {
      final recording = RecordingLeaderboardNotifier(
        result: LeaderboardState(
          entries: [buildEntry(id: kTestUserId, rank: 5)],
          currentUserRank: 5,
          currentUserEntry: buildEntry(id: kTestUserId, rank: 5),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            buildMockAuthRepository(authenticated: true),
          ),
          leaderboardProvider.overrideWith((ref) => recording),
        ],
      );
      addTearDown(container.dispose);

      await pumpEventQueue();

      final state = await container.read(asyncLeaderboardProvider.future);

      // The provider passed the real id, activating current-user highlight.
      expect(recording.capturedUserIds, contains(kTestUserId));
      expect(state.currentUserRank, 5);
      expect(state.currentUserEntry?.id, kTestUserId);
    });

    test(
      'degrades gracefully with a null id when unauthenticated (no crash)',
      () async {
        final recording = RecordingLeaderboardNotifier(
          result: const LeaderboardState(entries: []),
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              buildMockAuthRepository(authenticated: false),
            ),
            leaderboardProvider.overrideWith((ref) => recording),
          ],
        );
        addTearDown(container.dispose);

        await pumpEventQueue();

        final state = await container.read(asyncLeaderboardProvider.future);

        expect(recording.capturedUserIds, contains(null));
        expect(state.currentUserRank, isNull);
        expect(state.currentUserEntry, isNull);
      },
    );
  });
}
