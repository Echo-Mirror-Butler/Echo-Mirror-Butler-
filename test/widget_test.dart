import 'package:echomirror/core/services/mood_sync_service.dart';
import 'package:echomirror/core/viewmodel/providers/notification_provider.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/features/auth/view/screens/login_screen.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// App-level smoke test.
///
/// This pumps [EchoMirrorApp] — the real widget tree, real router, real
/// redirect logic — rather than calling `main()`. `main()` is not testable
/// under `flutter test`: it awaits `SentryService.init()`, whose native
/// channel calls never resolve in the test environment (so the future never
/// completes and `pumpAndSettle` spins until its 10-minute default timeout),
/// and then `SupabaseClientService.ensureInitialized()`, which throws
/// `StateError` because `SUPABASE_URL`/`SUPABASE_ANON_KEY` are compile-time
/// `String.fromEnvironment` values that CI does not pass via `--dart-define`.
/// Both are bootstrap concerns that belong to a real device run, not to a
/// widget test — so the test covers everything from `runApp` inwards.
void main() {
  setUpAll(() async {
    // Onboarding done + unauthenticated is the state the router redirects
    // to /login from, which is what this smoke test asserts on.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_completed': true,
      'echo_remember_me': true,
    });

    // AuthRepository (and anything else reaching for Supabase.instance.client)
    // needs an initialized instance. Nothing here issues a real query — the
    // repository is overridden with a mock below.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('boots to the login screen when unauthenticated', (
    WidgetTester tester,
  ) async {
    final mockAuthRepository = MockAuthRepository();
    when(
      () => mockAuthRepository.isAuthenticated(),
    ).thenAnswer((_) async => false);
    when(
      () => mockAuthRepository.getCurrentUser(),
    ).thenAnswer((_) async => null);
    when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          // EchoMirrorApp kicks both of these off in a post-frame callback.
          // They drive flutter_local_notifications and connectivity_plus over
          // platform channels that have no implementation under `flutter test`.
          notificationInitProvider.overrideWith((_) async {}),
          moodSyncInitProvider.overrideWith((_) async {}),
        ],
        child: const EchoMirrorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });
}
