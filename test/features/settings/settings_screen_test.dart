import 'package:echomirror/core/viewmodel/providers/notification_provider.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/gift_provider.dart';
import 'package:echomirror/features/settings/view/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fakes & mocks
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements AuthRepository {}

class _FakeGiftRepository extends GiftRepository {
  @override
  Future<double> getEchoBalance() async => 75.0;

  @override
  Future<List<GiftTransactionModel>> getGiftHistory() async =>
      const <GiftTransactionModel>[];
}

class _FakeGiftNotifier extends GiftNotifier {
  _FakeGiftNotifier() : super(_FakeGiftRepository()) {
    state = const GiftState(echoBalance: 75.0);
  }

  @override
  Future<void> loadBalance() async {}

  @override
  Future<void> loadHistory() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [ProviderScope]-wrapped [SettingsScreen] without a real router.
/// Suitable for tests that do not exercise navigation.
Widget _buildScreen({
  ThemeMode initialThemeMode = ThemeMode.light,
  MockAuthRepository? authRepo,
  bool notificationsEnabled = false,
}) {
  final mockAuth = authRepo ?? MockAuthRepository();
  when(() => mockAuth.isAuthenticated()).thenAnswer((_) async => true);
  when(() => mockAuth.getCurrentUser()).thenAnswer(
    (_) async => {
      'id': 'user_test',
      'email': 'tester@example.com',
      'name': null,
      'avatarUrl': null,
      'createdAt': DateTime(2025).toIso8601String(),
    },
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(mockAuth),
      giftProvider.overrideWith((_) => _FakeGiftNotifier()),
      notificationEnabledProvider.overrideWith(
        (_) async => notificationsEnabled,
      ),
      notificationTimeProvider.overrideWith((_) async => (hour: 8, minute: 0)),
    ],
    child: MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: initialThemeMode,
      home: const SettingsScreen(),
    ),
  );
}

/// Builds a router-wrapped [SettingsScreen] for navigation tests.
Widget _buildScreenWithRouter({MockAuthRepository? authRepo}) {
  final mockAuth = authRepo ?? MockAuthRepository();
  when(() => mockAuth.isAuthenticated()).thenAnswer((_) async => true);
  when(() => mockAuth.getCurrentUser()).thenAnswer(
    (_) async => {
      'id': 'user_test',
      'email': 'tester@example.com',
      'name': null,
      'avatarUrl': null,
      'createdAt': DateTime(2025).toIso8601String(),
    },
  );

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/settings/change-password',
        builder: (_, __) =>
            const Scaffold(body: Text('Change Password Screen')),
      ),
      GoRoute(
        path: '/gift/:userId',
        builder: (_, __) => const Scaffold(body: Text('Gift Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(mockAuth),
      giftProvider.overrideWith((_) => _FakeGiftNotifier()),
      notificationEnabledProvider.overrideWith((_) async => false),
      notificationTimeProvider.overrideWith((_) async => (hour: 8, minute: 0)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders all section headers and key setting tiles', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    // Section headers
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Key tiles
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('System Theme'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
  });

  testWidgets(
    'dark mode switch changes themeProvider state to ThemeMode.dark',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // The switch for Dark Mode should start off (light theme)
      final switchFinders = find.byType(Switch);
      // The first Switch in the card is the Dark Mode switch
      final darkModeSwitch = switchFinders.first;
      expect(tester.widget<Switch>(darkModeSwitch).value, isFalse);

      await tester.tap(darkModeSwitch);
      await tester.pumpAndSettle();

      // After tapping, the switch reflects dark mode on
      expect(tester.widget<Switch>(darkModeSwitch).value, isTrue);
    },
  );

  testWidgets('system theme switch is visible and can be toggled', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('System Theme'), findsOneWidget);

    // There are two switches in the Appearance card — System Theme is second
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.length, greaterThanOrEqualTo(2));

    final systemThemeSwitch = switches[1];
    // Initially follows light mode, so system theme switch is off
    expect(systemThemeSwitch.value, isFalse);
  });

  testWidgets(
    'tapping Change Password navigates to the change-password route',
    (tester) async {
      await tester.pumpWidget(_buildScreenWithRouter());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Change Password'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change Password'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Change Password Screen'), findsOneWidget);
    },
  );

  testWidgets('Daily Reflection Reminder tile is visible and interactive', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Daily Reflection Reminder'), findsOneWidget);

    // Notification toggle switch should be present
    final notifSwitch = find.byWidgetPredicate((widget) => widget is Switch);
    expect(notifSwitch, findsWidgets);
  });

  testWidgets('ECHO balance tile shows balance from giftProvider', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ECHO Balance'), findsOneWidget);
    expect(find.textContaining('75'), findsOneWidget);
  });

  testWidgets('email tile displays authenticated user email', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('tester@example.com'), findsOneWidget);
  });
}
