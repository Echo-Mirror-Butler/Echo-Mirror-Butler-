import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:echomirror/features/leaderboard/view/screens/leaderboard_screen.dart';
import 'package:echomirror/features/leaderboard/viewmodel/providers/leaderboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/leaderboard_test_helpers.dart';

/// Issue #599 — widget coverage for [LeaderboardScreen]: loading indicator,
/// empty state, populated list, and pull-to-refresh triggering a re-fetch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'echo_remember_me': true,
    });
  });

  Widget buildScreen(
    LeaderboardState state, {
    List<String?>? loadCalls,
    bool authenticated = false,
  }) {
    final calls = loadCalls ?? <String?>[];
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          buildMockAuthRepository(authenticated: authenticated),
        ),
        leaderboardProvider.overrideWith(
          (ref) => CountingLeaderboardNotifier(calls, state),
        ),
      ],
      child: const MaterialApp(home: LeaderboardScreen()),
    );
  }

  testWidgets('shows a loading indicator while loading', (tester) async {
    await tester.pumpWidget(
      buildScreen(const LeaderboardState(isLoading: true)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('shows the empty state when there are no entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        const LeaderboardState(entries: <LeaderboardEntryModel>[]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No one has earned ECHO this week yet.'),
      findsOneWidget,
    );
  });

  testWidgets('renders the populated leaderboard list', (tester) async {
    await tester.pumpWidget(
      buildScreen(
        LeaderboardState(
          entries: [
            buildEntry(id: 'a', displayName: 'Jane Doe', rank: 1, echo: 300),
            buildEntry(id: 'b', displayName: 'John Roe', rank: 2, echo: 200),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('John Roe'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
  });

  testWidgets('highlights the current user with a "You" badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        LeaderboardState(
          entries: [
            buildEntry(id: kTestUserId, displayName: 'Me', rank: 1, echo: 500),
            buildEntry(id: 'b', displayName: 'Someone', rank: 2, echo: 200),
          ],
        ),
        authenticated: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('pull-to-refresh triggers a re-fetch', (tester) async {
    final calls = <String?>[];
    await tester.pumpWidget(
      buildScreen(
        LeaderboardState(
          entries: [
            buildEntry(id: 'a', displayName: 'Jane Doe', rank: 1, echo: 300),
          ],
        ),
        loadCalls: calls,
      ),
    );
    await tester.pumpAndSettle();

    // initState performs the first load.
    final callsAfterInit = calls.length;
    expect(callsAfterInit, greaterThanOrEqualTo(1));

    // Drag the list down to trigger RefreshIndicator.onRefresh.
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(calls.length, greaterThan(callsAfterInit));
  });
}
