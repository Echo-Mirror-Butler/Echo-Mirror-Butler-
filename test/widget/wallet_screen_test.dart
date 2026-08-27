import 'package:echomirror/features/global_mirror/view/screens/wallet_screen.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeWalletNotifier extends WalletNotifier {
  _FakeWalletNotifier({required WalletState initialState}) {
    state = initialState;
  }

  @override
  Future<void> loadWallet() async {}

  @override
  Future<void> refreshLiveBalances() async {}
}

void main() {
  setUpAll(() async {
    // Supabase's internal auth storage reaches for SharedPreferences during
    // initialize(), so the mock must be in place before that call.
    SharedPreferences.setMockInitialValues({});

    // _showSendEchoSheet reaches for Supabase.instance.client as soon as the
    // send modal opens. The tests below never take a path that issues a real
    // query (see the recipient-format notes on each test), so a local,
    // never-contacted project is enough to satisfy the client's assertion
    // that it's been initialized.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required double balance,
    required String publicKey,
  }) {
    return ProviderScope(
      overrides: [
        walletProvider.overrideWith((ref) {
          return _FakeWalletNotifier(
            initialState: WalletState(
              exists: true,
              publicKey: publicKey,
              balance: balance,
              echoBalance: balance,
              funded: true,
            ),
          );
        }),
      ],
      child: const MaterialApp(home: WalletScreen()),
    );
  }

  const testPublicKey =
      'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ';

  group('WalletScreen Widget Tests', () {
    testWidgets('renders balance and public key', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(balance: 100.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      expect(find.text('100.0 ECHO'), findsOneWidget);
      expect(
        find.textContaining('GABCDEFGHIJKLMNOPQRSTUVWXYZ'),
        findsOneWidget,
      );
    });

    testWidgets('shows testnet banner (defaults to testnet when '
        'STELLAR_NETWORK is unset)', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(balance: 50.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Testnet'), findsWidgets);
    });

    testWidgets('send modal opens when send button is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(balance: 100.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send ECHO').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a recipient and the amount of ECHO to send.'),
        findsOneWidget,
      );
      expect(find.text('Recipient'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('send button in modal is disabled until a recipient '
        'resolves', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(balance: 100.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send ECHO').first);
      await tester.pumpAndSettle();

      final modalSendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send ECHO').last,
      );
      expect(modalSendButton.onPressed, isNull);
    });

    testWidgets('shows error for invalid recipient format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(balance: 100.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send ECHO').first);
      await tester.pumpAndSettle();

      // Not a UUID, not a 56-char Stellar key, and no '@' — this fails
      // _resolveRecipientId's format check synchronously, without ever
      // reaching Supabase.
      await tester.enterText(
        find.byType(TextField).first,
        'not-a-valid-recipient',
      );
      // Let the 500ms debounce in validateRecipient fire.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Recipient not found'), findsOneWidget);
    });

    testWidgets('validates amount field in send modal', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(balance: 100.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send ECHO').first);
      await tester.pumpAndSettle();

      final amountField = find.byType(TextField).last;
      await tester.enterText(amountField, 'abc');
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid number'), findsOneWidget);
    });

    testWidgets('shows insufficient balance error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(balance: 10.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send ECHO').first);
      await tester.pumpAndSettle();

      final amountField = find.byType(TextField).last;
      await tester.enterText(amountField, '100');
      await tester.pumpAndSettle();

      expect(find.text('Insufficient ECHO balance'), findsOneWidget);
    });

    testWidgets('copies public key to clipboard', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(balance: 100.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.copy));
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Public key copied to clipboard'), findsOneWidget);
    });

    testWidgets('preset amount buttons populate amount field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(balance: 100.0, publicKey: testPublicKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send ECHO').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('25 ECHO'));
      await tester.pumpAndSettle();

      final amountField = find.byType(TextField).last;
      final textField = tester.widget<TextField>(amountField);
      expect(textField.controller?.text, '25');
    });
  });
}
