import 'package:echomirror/core/routing/app_router.dart';
import 'package:echomirror/features/auth/view/screens/login_screen.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  Widget createTestWidget(WidgetRef? ref) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ],
      child: MaterialApp(
        home: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('renders email and password fields', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(null));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows validation error when submitted empty', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(null));
      await tester.pumpAndSettle();

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email format', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(null));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextField, 'Email');
      await tester.enterText(emailField, 'invalid-email');
      
      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('shows loading indicator while signing in', (WidgetTester tester) async {
      when(() => mockAuthRepository.signIn(any(), any()))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'user-id-123';
      });

      await tester.pumpWidget(createTestWidget(null));
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'password123');

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.tap(loginButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on failed login', (WidgetTester tester) async {
      when(() => mockAuthRepository.signIn(any(), any()))
          .thenThrow(Exception('Invalid credentials'));

      await tester.pumpWidget(createTestWidget(null));
      await tester.pumpAndSettle();

      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'wrongpassword');

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('password field toggles visibility', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(null));
      await tester.pumpAndSettle();

      final passwordField = find.byType(TextField).last;
      final textField = tester.widget<TextField>(passwordField);
      expect(textField.obscureText, isTrue);

      final visibilityToggle = find.byIcon(Icons.visibility);
      await tester.tap(visibilityToggle);
      await tester.pumpAndSettle();

      final updatedTextField = tester.widget<TextField>(passwordField);
      expect(updatedTextField.obscureText, isFalse);
    });
  });
}
