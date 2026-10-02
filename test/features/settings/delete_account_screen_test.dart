import 'package:echomirror/features/auth/data/models/user_model.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/settings/data/repositories/account_deletion_repository.dart';
import 'package:echomirror/features/settings/view/screens/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountDeletionRepository extends Mock
    implements AccountDeletionRepository {}

/// Auth notifier with a fixed initial state; signOut clears state without
/// touching a real Supabase backend.
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier._(
    MockAuthRepository repo,
    Ref ref,
    AuthState initialState,
  ) : super(repo, ref) {
    state = initialState;
  }

  factory _FakeAuthNotifier(Ref ref, AuthState initialState) {
    final repo = MockAuthRepository();
    final user = initialState.user;
    final isSignedIn = user != null;
    // Stub a real session check. AuthNotifier's constructor runs
    // _checkAuthStatus() async; stubbing isAuthenticated() => false for a
    // signed-in state would let that continuation wipe the user from state.
    when(() => repo.isAuthenticated()).thenAnswer((_) async => isSignedIn);
    when(() => repo.getCurrentUser()).thenAnswer((_) async {
      if (!isSignedIn) return null;
      return {
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'createdAt': user.createdAt.toIso8601String(),
      };
    });
    return _FakeAuthNotifier._(repo, ref, initialState);
  }

  @override
  Future<void> signOut() async {
    state = const AuthState();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final testUser = UserModel(
    id: 'user-123',
    email: 'tester@example.com',
    name: 'Test User',
    createdAt: DateTime(2025),
  );

  AuthState signedInAuthState() => AuthState(user: testUser);

  Widget buildScreen({
    AuthState authState = const AuthState(),
    AccountDeletionRepository? deletionRepo,
  }) {
    final router = GoRouter(
      initialLocation: '/settings/delete-account',
      routes: [
        GoRoute(
          path: '/settings/delete-account',
          builder: (context, state) => const DeleteAccountScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('Settings Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => _FakeAuthNotifier(ref, authState),
        ),
        if (deletionRepo != null)
          accountDeletionRepositoryProvider.overrideWithValue(deletionRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> enterConfirmationPhrase(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField),
      AccountDeletionRepository.confirmationPhrase,
    );
    await tester.pump();
  }

  group('DeleteAccountScreen', () {
    testWidgets('renders confirmation phrase prompt and grace period copy', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(authState: signedInAuthState()));
      await tester.pumpAndSettle();

      expect(find.text('Type DELETE MY ACCOUNT to confirm'), findsOneWidget);
      expect(find.text('Changed your mind?'), findsOneWidget);
      expect(find.textContaining('14-day waiting period'), findsOneWidget);
      expect(find.textContaining('tester@example.com'), findsOneWidget);
    });

    testWidgets('delete button is disabled until the phrase is typed', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(authState: signedInAuthState()));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(
        FilledButton,
        'Permanently delete my account',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await enterConfirmationPhrase(tester);

      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('wrong phrase keeps button disabled', (tester) async {
      await tester.pumpWidget(buildScreen(authState: signedInAuthState()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'delete my account please');
      await tester.pump();

      final button = find.widgetWithText(
        FilledButton,
        'Permanently delete my account',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('success calls function, signs out, and shows grace period', (
      tester,
    ) async {
      final deletionRepo = MockAccountDeletionRepository();
      when(
        () => deletionRepo.requestDeletion(userId: 'user-123'),
      ).thenAnswer(
        (_) async => const AccountDeletionResult(
          status: AccountDeletionStatus.success,
          gracePeriodEndsAt: null,
        ),
      );

      await tester.pumpWidget(
        buildScreen(
          authState: AuthState(user: testUser),
          deletionRepo: deletionRepo,
        ),
      );
      await tester.pumpAndSettle();

      await enterConfirmationPhrase(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Permanently delete my account'),
      );
      await tester.pumpAndSettle();

      verify(() => deletionRepo.requestDeletion(userId: 'user-123')).called(1);

      // The success dialog explains the grace period and recovery while the
      // user is still signed in.
      expect(
        find.textContaining('permanently deleted in 14 days'),
        findsOneWidget,
      );
      expect(find.textContaining('sign back in'), findsOneWidget);

      // Acknowledging the dialog signs the user out locally (clears caches
      // via AuthNotifier) — auth state becomes unauthenticated.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(DeleteAccountScreen));
      expect(
        ProviderScope.containerOf(context).read(authProvider).user,
        isNull,
      );
    });

    testWidgets('success dialog shows the returned grace period end date', (
      tester,
    ) async {
      final deletionRepo = MockAccountDeletionRepository();
      when(
        () => deletionRepo.requestDeletion(userId: 'user-123'),
      ).thenAnswer(
        (_) async => AccountDeletionResult(
          status: AccountDeletionStatus.success,
          // Local date so formatDate output is timezone-independent.
          gracePeriodEndsAt: DateTime(2026, 10, 14),
        ),
      );

      await tester.pumpWidget(
        buildScreen(
          authState: AuthState(user: testUser),
          deletionRepo: deletionRepo,
        ),
      );
      await tester.pumpAndSettle();

      await enterConfirmationPhrase(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Permanently delete my account'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Oct 14, 2026'), findsOneWidget);
    });

    testWidgets('shows friendly rate-limit message without raw errors', (
      tester,
    ) async {
      final deletionRepo = MockAccountDeletionRepository();
      when(
        () => deletionRepo.requestDeletion(userId: 'user-123'),
      ).thenAnswer(
        (_) async => throw const AccountDeletionException(
          AccountDeletionFailure.rateLimited,
        ),
      );

      await tester.pumpWidget(
        buildScreen(
          authState: AuthState(user: testUser),
          deletionRepo: deletionRepo,
        ),
      );
      await tester.pumpAndSettle();

      await enterConfirmationPhrase(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Permanently delete my account'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Too many attempts. Please wait a few minutes before trying again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('AccountDeletionException'), findsNothing);
      expect(find.textContaining('Exception:'), findsNothing);
    });

    testWidgets('shows friendly network message and stays on the screen', (
      tester,
    ) async {
      final deletionRepo = MockAccountDeletionRepository();
      when(
        () => deletionRepo.requestDeletion(userId: 'user-123'),
      ).thenAnswer(
        (_) async => throw const AccountDeletionException(
          AccountDeletionFailure.network,
        ),
      );

      await tester.pumpWidget(
        buildScreen(
          authState: AuthState(user: testUser),
          deletionRepo: deletionRepo,
        ),
      );
      await tester.pumpAndSettle();

      await enterConfirmationPhrase(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Permanently delete my account'),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Check your internet connection'),
        findsOneWidget,
      );
      // Screen stays mounted so the user can retry.
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });

    testWidgets('cancel returns to the previous screen', (tester) async {
      await tester.pumpWidget(buildScreen(authState: signedInAuthState()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Screen'), findsOneWidget);
    });
  });
}
