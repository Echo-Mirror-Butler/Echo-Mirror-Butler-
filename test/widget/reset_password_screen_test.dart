import 'package:echomirror/core/widgets/shimmer_loading.dart';
import 'package:echomirror/features/auth/view/screens/reset_password_screen.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ],
      child: MaterialApp(
        home: const ResetPasswordScreen(
          email: 'test@example.com',
          token: 'valid-token',
        ),
      ),
    );
  }

  group('ResetPasswordScreen Widget Tests', () {
    testWidgets('renders password fields', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets('shows "passwords do not match" error', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final newPasswordField = find.byType(TextField).first;
      await tester.enterText(newPasswordField, 'password123');

      final confirmPasswordField = find.byType(TextField).last;
      await tester.enterText(confirmPasswordField, 'password456');

      final resetButton = find.widgetWithText(ElevatedButton, 'Reset Password');
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows password min-length error', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final newPasswordField = find.byType(TextField).first;
      await tester.enterText(newPasswordField, 'short');

      final resetButton = find.widgetWithText(ElevatedButton, 'Reset Password');
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('calls authRepository.resetPassword with correct args', (WidgetTester tester) async {
      when(() => mockAuthRepository.resetPassword(any(), any(), any()))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final newPasswordField = find.byType(TextField).first;
      await tester.enterText(newPasswordField, 'newpassword123');

      final confirmPasswordField = find.byType(TextField).last;
      await tester.enterText(confirmPasswordField, 'newpassword123');

      final resetButton = find.widgetWithText(ElevatedButton, 'Reset Password');
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      verify(() => mockAuthRepository.resetPassword(
            'test@example.com',
            'valid-token',
            'newpassword123',
          )).called(1);
    });

    testWidgets('shows success message and navigates on success', (WidgetTester tester) async {
      when(() => mockAuthRepository.resetPassword(any(), any(), any()))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final newPasswordField = find.byType(TextField).first;
      await tester.enterText(newPasswordField, 'newpassword123');

      final confirmPasswordField = find.byType(TextField).last;
      await tester.enterText(confirmPasswordField, 'newpassword123');

      final resetButton = find.widgetWithText(ElevatedButton, 'Reset Password');
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Password reset successfully! Please log in with your new password.'),
        findsOneWidget,
      );
    });

    testWidgets('shows expired link view on token expiration', (WidgetTester tester) async {
      when(() => mockAuthRepository.resetPassword(any(), any(), any()))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final newPasswordField = find.byType(TextField).first;
      await tester.enterText(newPasswordField, 'newpassword123');

      final confirmPasswordField = find.byType(TextField).last;
      await tester.enterText(confirmPasswordField, 'newpassword123');

      final resetButton = find.widgetWithText(ElevatedButton, 'Reset Password');
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(find.text('Link expired'), findsOneWidget);
      expect(find.text('Request new link'), findsOneWidget);
    });

    testWidgets('password fields toggle visibility', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final newPasswordField = find.byType(TextField).first;
      final textField = tester.widget<TextField>(newPasswordField);
      expect(textField.obscureText, isTrue);

      final visibilityToggles = find.byIcon(FontAwesomeIcons.eye.data);
      await tester.tap(visibilityToggles.first);
      await tester.pumpAndSettle();

      final updatedTextField = tester.widget<TextField>(newPasswordField);
      expect(updatedTextField.obscureText, isFalse);
    });

    testWidgets('shows loading indicator while resetting', (WidgetTester tester) async {
      when(() => mockAuthRepository.resetPassword(any(), any(), any()))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final newPasswordField = find.byType(TextField).first;
      await tester.enterText(newPasswordField, 'newpassword123');

      final confirmPasswordField = find.byType(TextField).last;
      await tester.enterText(confirmPasswordField, 'newpassword123');

      final resetButton = find.widgetWithText(ElevatedButton, 'Reset Password');
      await tester.tap(resetButton);
      await tester.pump();

      // CustomButton shows ShimmerLoading (not CircularProgressIndicator)
      expect(find.byType(ShimmerLoading), findsOneWidget);

      // Let the mocked reset's 100ms delay finish so its Timer doesn't
      // outlive the widget tree's disposal at test teardown.
      await tester.pumpAndSettle();
    });
  });
}
