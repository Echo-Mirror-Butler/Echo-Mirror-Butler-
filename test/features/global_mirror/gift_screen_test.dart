import 'package:confetti/confetti.dart';
import 'package:echomirror/features/auth/data/models/user_model.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:echomirror/features/global_mirror/view/screens/gift_screen.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/gift_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — controls balance and failure mode per test
// ---------------------------------------------------------------------------

class FakeGiftRepository implements GiftRepository {
  FakeGiftRepository({this.balance = 100.0, this.shouldThrow = false});

  final double balance;
  final bool shouldThrow;

  // Track calls for verification tests
  double? lastSentAmount;
  int? lastSentRecipient;

  @override
  Future<double> getEchoBalance() async => balance;

  @override
  Future<GiftTransactionModel?> sendGift({
    required int recipientUserId,
    required double amount,
    String? message,
  }) async {
    if (shouldThrow) throw Exception('Insufficient funds');
    lastSentAmount = amount;
    lastSentRecipient = recipientUserId;
    return GiftTransactionModel(
      id: 1,
      senderUserId: 0,
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      stellarTxHash: null,
      message: message,
    );
  }

  @override
  Future<List<GiftTransactionModel>> getGiftHistory() async => [];
}

// ---------------------------------------------------------------------------
// Fake auth notifier — returns a no-op authenticated user so the history
// section in GiftScreen can resolve ref.watch(authProvider).user?.id
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends StateNotifier<AuthState> {
  _FakeAuthNotifier()
    : super(
        AuthState(
          user: UserModel(
            id: 'test-user',
            email: 'test@example.com',
            createdAt: DateTime(2024),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds GiftScreen wrapped in ProviderScope with fakes injected.
Widget buildSubject({
  double balance = 100.0,
  bool shouldThrow = false,
  FakeGiftRepository? repo,
}) {
  final fakeRepo =
      repo ?? FakeGiftRepository(balance: balance, shouldThrow: shouldThrow);
  return ProviderScope(
    overrides: [
      giftRepositoryProvider.overrideWithValue(fakeRepo),
      // Override authProvider so no real auth/network calls happen
      authProvider.overrideWith((_) => _FakeAuthNotifier()),
    ],
    child: MaterialApp(home: GiftScreen(recipientUserId: 99)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GiftScreen', () {
    // -----------------------------------------------------------------------
    // Test 1 — Balance display
    // -----------------------------------------------------------------------
    testWidgets('shows ECHO balance', (tester) async {
      // Arrange
      await tester.pumpWidget(buildSubject(balance: 42.0));

      // Act — let async loadBalance() complete
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('42 ECHO'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Test 2 — Send button disabled at default state (amount=5, balance=0)
    // -----------------------------------------------------------------------
    testWidgets('send button is disabled when amount exceeds balance', (
      tester,
    ) async {
      // Arrange — balance 0 so default selected amount (5 ECHO) exceeds it
      await tester.pumpWidget(buildSubject(balance: 0.0));
      await tester.pumpAndSettle();

      // Act — find the FilledButton.icon used as the send button
      final sendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send 5 ECHO'),
      );

      // Assert — onPressed must be null when disabled
      expect(sendButton.onPressed, isNull);
    });

    // -----------------------------------------------------------------------
    // Test 3 — Send button enabled when valid amount is selected
    // -----------------------------------------------------------------------
    testWidgets('send button is enabled when valid amount is selected', (
      tester,
    ) async {
      // Arrange — balance 100, default selected amount is 5 ECHO
      await tester.pumpWidget(buildSubject(balance: 100.0));
      await tester.pumpAndSettle();

      // Act — find the send button
      final sendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send 5 ECHO'),
      );

      // Assert — onPressed should not be null
      expect(sendButton.onPressed, isNotNull);
    });

    // -----------------------------------------------------------------------
    // Test 4 — Success: confetti plays after a successful send
    // -----------------------------------------------------------------------
    testWidgets('shows confetti after successful send', (tester) async {
      // Arrange
      await tester.pumpWidget(buildSubject(balance: 100.0));
      await tester.pumpAndSettle();

      // Assert ConfettiWidget is in the tree before sending
      expect(find.byType(ConfettiWidget), findsOneWidget);

      // Act — tap the send button
      await tester.tap(find.widgetWithText(FilledButton, 'Send 5 ECHO'));

      // Pump enough for the async sendGift to complete and confetti to start.
      // We avoid pumpAndSettle here because _handleSend contains a
      // Future.delayed(3s) before context.pop(), which would time out.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert — ConfettiWidget is still mounted and the screen has not
      // been popped yet (the 3-second delay hasn't elapsed)
      expect(find.byType(ConfettiWidget), findsOneWidget);
      expect(find.text('Send ECHO Gift'), findsOneWidget);

      // The send button label reverts from 'Sending...' back to 'Send 5 ECHO',
      // confirming the async operation completed successfully
      expect(find.widgetWithText(FilledButton, 'Send 5 ECHO'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Test 5 (bonus) — Validation error when amount exceeds balance
    // -----------------------------------------------------------------------
    testWidgets('shows insufficient balance text when amount exceeds balance', (
      tester,
    ) async {
      // Arrange — balance 3, default selected amount is 5 ECHO
      await tester.pumpWidget(buildSubject(balance: 3.0));
      await tester.pumpAndSettle();

      // Assert — inline error text is visible
      expect(find.text('Insufficient ECHO balance'), findsOneWidget);

      // And the send button is disabled
      final sendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send 5 ECHO'),
      );
      expect(sendButton.onPressed, isNull);
    });

    // -----------------------------------------------------------------------
    // Test 6 (bonus) — Custom amount dialog opens
    // -----------------------------------------------------------------------
    testWidgets('custom amount dialog opens on picker interaction', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(buildSubject(balance: 100.0));
      await tester.pumpAndSettle();

      // Act — tap the "Custom" chip
      await tester.tap(find.widgetWithText(ActionChip, 'Custom'));
      await tester.pumpAndSettle();

      // Assert — dialog is shown
      expect(find.text('Custom Amount'), findsOneWidget);
      expect(find.text('Set'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Test 7 (bonus) — sendGift is called with the correct amount
    // -----------------------------------------------------------------------
    testWidgets(
      'send button triggers sendGift on repository with correct amount',
      (tester) async {
        // Arrange
        final fakeRepo = FakeGiftRepository(balance: 100.0);
        await tester.pumpWidget(buildSubject(repo: fakeRepo));
        await tester.pumpAndSettle();

        // Act — tap the send button (default 5 ECHO selected)
        await tester.tap(find.widgetWithText(FilledButton, 'Send 5 ECHO'));

        // Pump enough to let the async sendGift call complete
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Assert — repository received the correct amount
        expect(fakeRepo.lastSentAmount, 5.0);
        expect(fakeRepo.lastSentRecipient, 99);
      },
    );
  });
}
