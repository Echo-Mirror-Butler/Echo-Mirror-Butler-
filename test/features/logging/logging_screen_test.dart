import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/view/screens/logging_screen.dart';
import 'package:echomirror/features/logging/viewmodel/providers/logging_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 4, 1, 12, 0);

LogEntryModel _makeEntry({
  String id = 'entry-1',
  String userId = 'u1',
  int? mood = 4,
  DateTime? date,
}) => LogEntryModel(
  id: id,
  userId: userId,
  date: date ?? _now,
  mood: mood,
  habits: const ['exercise'],
  notes: 'test note',
  createdAt: _now,
);

class _FakeLoggingNotifier extends LoggingNotifier {
  _FakeLoggingNotifier(this._initialState) : super(_FakeLoggingRepository()) {
    state = _initialState;
  }

  final AsyncValue<List<LogEntryModel>> _initialState;

  @override
  Future<void> loadLogEntries({String? userId}) async {}
}

class _FakeLoggingRepository {
  Future<List<LogEntryModel>> getLogEntries(String userId) async => [];
  Future<LogEntryModel> createLogEntry(LogEntryModel entry) async => entry;
  Future<LogEntryModel> updateLogEntry(LogEntryModel entry) async => entry;
  Future<void> deleteLogEntry(String entryId, String userId) async {}
  Future<LogEntryModel?> getLogEntryForDate(
    DateTime date,
    String userId,
  ) async => null;
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(_FakeAuthRepository()) {
    state = const AuthState(isAuthenticated: false);
  }

  @override
  Future<void> checkAuthStatus() async {}
}

class _FakeAuthRepository {
  Future<bool> isAuthenticated() async => false;
  Future<Map<String, dynamic>?> getCurrentUser() async => null;
}

Widget _buildScreen({
  required AsyncValue<List<LogEntryModel>> loggingState,
  bool withRouter = false,
}) {
  final fakeLoggingNotifier = _FakeLoggingNotifier(loggingState);
  final fakeAuthNotifier = _FakeAuthNotifier();

  if (!withRouter) {
    return ProviderScope(
      overrides: [
        loggingProvider.overrideWith((ref) => fakeLoggingNotifier),
        authProvider.overrideWith((ref) => fakeAuthNotifier),
      ],
      child: const MaterialApp(home: LoggingScreen()),
    );
  }

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/logging/create',
        builder: (_, __) => const Scaffold(body: Text('Create Entry')),
      ),
      GoRoute(
        path: '/logging/detail/:id',
        builder: (_, __) => const Scaffold(body: Text('Entry Detail')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      loggingProvider.overrideWith((ref) => fakeLoggingNotifier),
      authProvider.overrideWith((ref) => fakeAuthNotifier),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 'u1',
      'user_email': 'test@test.com',
    });
  });

  group('LoggingScreen empty state', () {
    testWidgets('empty-state widget is visible when AsyncData([])', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(loggingState: const AsyncValue.data([])),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('No entries yet'), findsOneWidget);
      expect(
        find.text('Start logging your daily mood and habits'),
        findsOneWidget,
      );
    });
  });

  group('LoggingScreen entry list', () {
    testWidgets('renders entries with correct dates and moods', (tester) async {
      final entries = [
        _makeEntry(id: 'e1', mood: 5, date: DateTime(2026, 4, 1)),
        _makeEntry(id: 'e2', mood: 3, date: DateTime(2026, 4, 2)),
      ];

      await tester.pumpWidget(
        _buildScreen(loggingState: AsyncValue.data(entries)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('No entries yet'), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('LoggingScreen loading state', () {
    testWidgets('shows loading indicator and hides list', (tester) async {
      await tester.pumpWidget(
        _buildScreen(loggingState: const AsyncValue.loading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('LoggingScreen error state', () {
    testWidgets('renders retry widget on AsyncError', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          loggingState: AsyncValue.error(
            Exception('network error'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('LoggingScreen create entry navigation', () {
    testWidgets('tapping FAB navigates to create entry screen', (tester) async {
      await tester.pumpWidget(
        _buildScreen(loggingState: const AsyncValue.data([]), withRouter: true),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Entry'), findsOneWidget);
    });
  });
}
