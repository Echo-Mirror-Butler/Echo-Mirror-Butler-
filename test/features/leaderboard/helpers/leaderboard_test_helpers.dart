import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:echomirror/features/leaderboard/viewmodel/providers/leaderboard_provider.dart';
import 'package:mocktail/mocktail.dart';

/// Shared test helpers for the leaderboard feature.
///
/// Introduced with issue #598 (auth wiring for `currentUserIdProvider`) and
/// reused by the broader issue #599 suite (model + provider + widget tests).

/// The user id returned by [buildMockAuthRepository] when authenticated.
const String kTestUserId = 'test_user_id';

/// Mocktail mock for [AuthRepository], mirroring the pattern used in
/// `test/features/dashboard/dashboard_screen_test.dart`.
class MockAuthRepository extends Mock implements AuthRepository {}

/// Builds an [AuthRepository] mock wired for a logged-in or logged-out user.
///
/// When [authenticated] is true, `isAuthenticated()` resolves true and
/// `getCurrentUser()` returns a stable user map whose id is [kTestUserId], so
/// the real [AuthNotifier] settles into an authenticated [AuthState]. When
/// false, the notifier settles into an empty (unauthenticated) state.
MockAuthRepository buildMockAuthRepository({bool authenticated = true}) {
  final mock = MockAuthRepository();
  when(() => mock.isAuthenticated()).thenAnswer((_) async => authenticated);
  when(() => mock.getCurrentUser()).thenAnswer(
    (_) async => authenticated
        ? <String, dynamic>{
            'id': kTestUserId,
            'email': 'test@example.com',
            'name': 'Test User',
            'createdAt': DateTime.now().toIso8601String(),
          }
        : null,
  );
  when(() => mock.signOut()).thenAnswer((_) async {});
  return mock;
}

/// Drains the microtask queue enough times for the async, constructor-driven
/// `AuthNotifier._checkAuthStatus()` chain (SharedPreferences -> isAuthenticated
/// -> getCurrentUser) to settle before assertions read auth-derived providers.
Future<void> pumpEventQueue([int times = 12]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A [LeaderboardNotifier] that records the `userId` passed to
/// [loadLeaderboard] instead of touching Supabase, and publishes a fixed
/// [result] state. Used to prove `asyncLeaderboardProvider` forwards the real
/// authenticated id resolved by `currentUserIdProvider`.
class RecordingLeaderboardNotifier extends LeaderboardNotifier {
  RecordingLeaderboardNotifier({LeaderboardState? result})
    : result = result ?? const LeaderboardState() {
    state = this.result;
  }

  final LeaderboardState result;
  final List<String?> capturedUserIds = <String?>[];

  @override
  Future<void> loadLeaderboard({String? userId}) async {
    capturedUserIds.add(userId);
    state = result;
  }
}

/// A [LeaderboardNotifier] that records every [loadLeaderboard] call into a
/// shared [calls] list (survives provider invalidation because the list lives
/// outside the notifier) and publishes a fixed [initial] state. Used by widget
/// tests to assert that pull-to-refresh triggers a re-fetch.
class CountingLeaderboardNotifier extends LeaderboardNotifier {
  CountingLeaderboardNotifier(this.calls, this.initial) {
    state = initial;
  }

  final List<String?> calls;
  final LeaderboardState initial;

  @override
  Future<void> loadLeaderboard({String? userId}) async {
    calls.add(userId);
    state = initial;
  }
}

/// Convenience factory for a leaderboard entry in tests.
LeaderboardEntryModel buildEntry({
  required String id,
  String? displayName = 'Jane Doe',
  String? avatarUrl,
  bool anonymous = false,
  int echo = 100,
  int rank = 1,
}) {
  return LeaderboardEntryModel(
    id: id,
    displayName: displayName,
    avatarUrl: avatarUrl,
    leaderboardAnonymous: anonymous,
    echoEarnedThisWeek: echo,
    rank: rank,
  );
}
