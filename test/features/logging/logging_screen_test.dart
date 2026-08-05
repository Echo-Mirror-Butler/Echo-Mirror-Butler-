import 'package:echomirror/features/auth/data/models/user_model.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/view/screens/logging_screen.dart';
import 'package:echomirror/features/logging/viewmodel/providers/logging_provider.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/core/widgets/shimmer_loading.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingRepository extends Mock implements LoggingRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class _FakeLoggingNotifier extends LoggingNotifier {
  _FakeLoggingNotifier(AsyncValue<List<LogEntryModel>> initialState)
    : super(MockLoggingRepository()) {
    state = initialState;
  }

  @override
  Future<void> loadLogEntries({String? userId}) async {
    // Do nothing in tests to prevent state changes unless intended
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier._(MockAuthRepository repo, Ref ref, AuthState initialState)
    : super(repo, ref) {
    state = initialState;
  }

  factory _FakeAuthNotifier(Ref ref, AuthState initialState) {
    final repo = MockAuthRepository();
    when(() => repo.isAuthenticated()).thenAnswer((_) async => false);
    return _FakeAuthNotifier._(repo, ref, initialState);
  }
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  Widget buildScreen({
    AsyncValue<List<LogEntryModel>> loggingState = const AsyncValue.data([]),
    AuthState authState = const AuthState(),
    NavigatorObserver? navigatorObserver,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      observers: navigatorObserver != null ? [navigatorObserver] : [],
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoggingScreen()),
        GoRoute(
          path: '/logging/create',
          builder: (context, state) =>
              const Scaffold(body: Text('Target: /logging/create')),
        ),
        GoRoute(
          path: '/logging/detail/:id',
          builder: (context, state) => Scaffold(
            body: Text('Target: /logging/detail/${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        loggingProvider.overrideWith(
          (ref) => _FakeLoggingNotifier(loggingState),
        ),
        authProvider.overrideWith((ref) => _FakeAuthNotifier(ref, authState)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  final testUser = UserModel(
    id: 'user-123',
    email: 'test@example.com',
    name: 'Test User',
    createdAt: DateTime.now(),
  );

  final testEntry = LogEntryModel(
    id: 'entry-1',
    userId: 'user-123',
    date: DateTime(2026, 4, 24),
    mood: 4,
    notes: 'Feeling great!',
    createdAt: DateTime.now(),
  );

  group('LoggingScreen Widget Tests', () {
    testWidgets('Empty state is shown when there are no log entries', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildScreen(
          loggingState: const AsyncValue.data([]),
          authState: AuthState(user: testUser),
        ),
      );

      expect(find.text('No entries yet'), findsOneWidget);
      expect(
        find.text('Start logging your daily mood and habits'),
        findsOneWidget,
      );
      expect(find.byIcon(FontAwesomeIcons.book.data), findsOneWidget);
    });

    testWidgets('Entry cards are rendered when entries exist', (tester) async {
      final entries = [
        testEntry,
        testEntry.copyWith(id: 'entry-2', date: DateTime(2026, 4, 23), mood: 3),
      ];

      await tester.pumpWidget(
        buildScreen(
          loggingState: AsyncValue.data(entries),
          authState: AuthState(user: testUser),
        ),
      );

      // AnimatedCard takes some time, pump enough
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('Apr 24, 2026'), findsOneWidget);
      expect(find.text('Apr 23, 2026'), findsOneWidget);
      expect(find.text('Mood: 4/5'), findsOneWidget);
      expect(find.text('Mood: 3/5'), findsOneWidget);
    });

    testWidgets('Loading spinner shown while entries are loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildScreen(
          loggingState: const AsyncValue.loading(),
          authState: AuthState(user: testUser),
        ),
      );

      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('Tapping the FAB navigates to CreateEntryScreen', (
      tester,
    ) async {
      final observer = MockNavigatorObserver();
      await tester.pumpWidget(
        buildScreen(
          loggingState: const AsyncValue.data([]),
          authState: AuthState(user: testUser),
          navigatorObserver: observer,
        ),
      );

      await tester.tap(find.text('New Entry'));
      await tester.pumpAndSettle();

      // go_router uses Navigator under the hood.
      // Tapping 'New Entry' calls context.push('/logging/create')
      verify(() => observer.didPush(any(), any())).called(greaterThan(0));
      expect(find.text('Target: /logging/create'), findsOneWidget);
    });

    testWidgets('Tapping an entry card navigates to EntryDetailScreen', (
      tester,
    ) async {
      final observer = MockNavigatorObserver();
      await tester.pumpWidget(
        buildScreen(
          loggingState: AsyncValue.data([testEntry]),
          authState: AuthState(user: testUser),
          navigatorObserver: observer,
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('Target: /logging/detail/entry-1'), findsOneWidget);
    });
  });
}
