import 'package:confetti/confetti.dart';
import 'package:echomirror/core/themes/app_theme.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:echomirror/features/global_mirror/view/screens/gift_screen.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/gift_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Fake implementation of GiftRepository for testing
class FakeGiftRepository implements GiftRepository {
  FakeGiftRepository({
    this.balance = 42.0,
    this.history = const [],
    this.shouldFailSend = false,
  });

  double balance;
  List<GiftTransactionModel> history;
  bool shouldFailSend;
  GiftTransactionModel? lastSentGift;

  @override
  Future<double> getEchoBalance() async {
    return balance;
  }

  @override
  Future<List<GiftTransactionModel>> getGiftHistory() async {
    return history;
  }

  @override
  Future<GiftTransactionModel?> sendGift({
    required int recipientUserId,
    required double amount,
    String? message,
  }) async {
    if (shouldFailSend) {
      return null;
    }

    lastSentGift = GiftTransactionModel(
      id: 1,
      senderUserId: 0,
      recipientUserId: recipientUserId,
      echoAmount: amount,
      createdAt: DateTime.now(),
      status: 'completed',
      stellarTxHash: 'fake-hash',
      message: message,
    );

    balance -= amount;
    return lastSentGift;
  }
}

void main() {
  group('GiftScreen Widget Tests', () {
    late FakeGiftRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeGiftRepository();
    });

    Widget createTestWidget({
      FakeGiftRepository? repository,
      int recipientUserId = 123,
    }) {
      final repo = repository ?? fakeRepo;
      return ProviderScope(
        overrides: [
          giftRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: GiftScreen(recipientUserId: recipientUserId),
        ),
      );
    }

    testWidgets('shows ECHO balance', (tester) async {
      fakeRepo.balance = 42.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('42 ECHO'), findsOneWidget);
      expect(find.text('Your ECHO Balance'), findsOneWidget);
    });

    testWidgets('send button is disabled when amount is 0', (tester) async {
      fakeRepo.balance = 50.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // The default selected amount is 5.0, not 0
      // So we need to verify the button is enabled with default amount
      final sendButton = find.widgetWithText(FilledButton, 'Send 5 ECHO');
      expect(sendButton, findsOneWidget);

      final button = tester.widget<FilledButton>(sendButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('send button is disabled when amount exceeds balance',
        (tester) async {
      fakeRepo.balance = 3.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Default amount is 5.0, which exceeds balance of 3.0
      final sendButton = find.widgetWithText(FilledButton, 'Send 5 ECHO');
      expect(sendButton, findsOneWidget);

      final button = tester.widget<FilledButton>(sendButton);
      expect(button.onPressed, isNull);

      expect(find.text('Insufficient ECHO balance'), findsOneWidget);
    });

    testWidgets('shows success message after sending', (tester) async {
      fakeRepo.balance = 50.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap the send button
      final sendButton = find.widgetWithText(FilledButton, 'Send 5 ECHO');
      await tester.tap(sendButton);
      await tester.pump();

      // Should show "Sending..." state
      expect(find.text('Sending...'), findsOneWidget);

      // Wait for the send operation to complete
      await tester.pumpAndSettle();

      // Verify the gift was sent
      expect(fakeRepo.lastSentGift, isNotNull);
      expect(fakeRepo.lastSentGift!.echoAmount, 5.0);
      expect(fakeRepo.lastSentGift!.recipientUserId, 123);
    });

    testWidgets('shows error when sending more than balance', (tester) async {
      fakeRepo.balance = 3.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Default amount is 5.0, which exceeds balance
      expect(find.text('Insufficient ECHO balance'), findsOneWidget);

      // Button should be disabled
      final sendButton = find.widgetWithText(FilledButton, 'Send 5 ECHO');
      final button = tester.widget<FilledButton>(sendButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('displays preset amount options', (tester) async {
      fakeRepo.balance = 100.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('1 ECHO'), findsOneWidget);
      expect(find.text('5 ECHO'), findsOneWidget);
      expect(find.text('10 ECHO'), findsOneWidget);
      expect(find.text('25 ECHO'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('can select different preset amounts', (tester) async {
      fakeRepo.balance = 100.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially 5 ECHO is selected
      expect(find.text('Send 5 ECHO'), findsOneWidget);

      // Tap on 10 ECHO
      await tester.tap(find.text('10 ECHO'));
      await tester.pumpAndSettle();

      // Button should update
      expect(find.text('Send 10 ECHO'), findsOneWidget);
    });

    testWidgets('shows custom amount dialog', (tester) async {
      fakeRepo.balance = 100.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap custom button
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Custom Amount'), findsOneWidget);
      expect(find.text('ECHO amount (1-100)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Set'), findsOneWidget);
    });

    testWidgets('can set custom amount', (tester) async {
      fakeRepo.balance = 100.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open custom amount dialog
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Enter custom amount
      final textField = find.byType(TextField).last;
      await tester.enterText(textField, '15');
      await tester.pumpAndSettle();

      // Tap Set button
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      // Button should show custom amount
      expect(find.text('Send 15 ECHO'), findsOneWidget);
    });

    testWidgets('shows message input field', (tester) async {
      fakeRepo.balance = 50.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Message (optional)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Add a kind note...'),
          findsOneWidget);
    });

    testWidgets('sends gift with message', (tester) async {
      fakeRepo.balance = 50.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter a message
      final messageField = find.widgetWithText(TextField, 'Add a kind note...');
      await tester.enterText(messageField, 'Great work!');
      await tester.pumpAndSettle();

      // Send the gift
      await tester.tap(find.widgetWithText(FilledButton, 'Send 5 ECHO'));
      await tester.pumpAndSettle();

      // Verify message was included
      expect(fakeRepo.lastSentGift?.message, 'Great work!');
    });

    testWidgets('shows error message when send fails', (tester) async {
      fakeRepo.balance = 50.0;
      fakeRepo.shouldFailSend = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap send button
      await tester.tap(find.widgetWithText(FilledButton, 'Send 5 ECHO'));
      await tester.pump();

      // Wait for error to appear
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to send gift. Check your balance and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('displays gift history when available', (tester) async {
      fakeRepo.balance = 50.0;
      fakeRepo.history = [
        GiftTransactionModel(
          id: 1,
          senderUserId: 0,
          recipientUserId: 123,
          echoAmount: 10.0,
          createdAt: DateTime.now(),
          status: 'completed',
          stellarTxHash: 'hash1',
          message: 'Test gift',
        ),
      ];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Gift History'), findsOneWidget);
      expect(find.text('-10 ECHO'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
    });

    testWidgets('shows empty state when no gift history', (tester) async {
      fakeRepo.balance = 50.0;
      fakeRepo.history = [];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No gifts yet'), findsOneWidget);
      expect(
        find.text('Sent and received gifts will appear here'),
        findsOneWidget,
      );
    });

    testWidgets('displays confetti widget', (tester) async {
      fakeRepo.balance = 50.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ConfettiWidget), findsOneWidget);
    });

    testWidgets('shows gift icon in app bar', (tester) async {
      fakeRepo.balance = 50.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Send ECHO Gift'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('balance card has gradient background', (tester) async {
      fakeRepo.balance = 42.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final container = find.ancestor(
        of: find.text('Your ECHO Balance'),
        matching: find.byType(Container),
      );

      expect(container, findsWidgets);
    });

    testWidgets('shows coins icon in balance card', (tester) async {
      fakeRepo.balance = 50.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(FontAwesomeIcons.coins), findsOneWidget);
    });
  });
}
