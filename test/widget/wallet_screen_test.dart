import 'package:echomirror/features/global_mirror/view/screens/wallet_screen.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletNotifier extends Mock implements WalletNotifier {}

void main() {
  late MockWalletNotifier mockWalletNotifier;

  setUp(() {
    mockWalletNotifier = MockWalletNotifier();
  });

  Widget createTestWidget({
    required double balance,
    required String publicKey,
    required String network,
  }) {
    return ProviderScope(
      overrides: [
        walletProvider.overrideWith((ref) {
          return AsyncValue.data({
            'balance': balance,
            'public_key': publicKey,
            'network': network,
          });
        }),
      ],
      child: const MaterialApp(
        home: WalletScreen(),
      ),
    );
  }

  group('WalletScreen Widget Tests', () {
    testWidgets('renders balance and public key', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 100.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      expect(find.text('100.0'), findsOneWidget);
      expect(
        find.textContaining('GABCDEFGHIJKLMNOPQRSTUVWXYZ'),
        findsOneWidget,
      );
    });

    testWidgets('shows testnet badge when STELLAR_NETWORK=testnet', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 50.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'testnet',
      ));
      await tester.pumpAndSettle();

      expect(find.text('TESTNET'), findsOneWidget);
    });

    testWidgets('send modal opens when send button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 100.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(ElevatedButton, 'Send');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.text('Send ECHO'), findsOneWidget);
      expect(find.text('Recipient'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('validates recipient field in send modal', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 100.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(ElevatedButton, 'Send');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      final confirmButton = find.text('Confirm Send');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('Recipient address is required'), findsOneWidget);
    });

    testWidgets('shows error for invalid recipient format', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 100.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(ElevatedButton, 'Send');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      final recipientField = find.byType(TextField).first;
      await tester.enterText(recipientField, 'invalid-format');

      final amountField = find.byType(TextField).last;
      await tester.enterText(amountField, '10');

      final confirmButton = find.text('Confirm Send');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('valid recipient'),
        findsOneWidget,
      );
    });

    testWidgets('validates amount field in send modal', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 100.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(ElevatedButton, 'Send');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      final recipientField = find.byType(TextField).first;
      await tester.enterText(recipientField, 'test@example.com');

      final confirmButton = find.text('Confirm Send');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
    });

    testWidgets('shows insufficient balance error', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 10.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(ElevatedButton, 'Send');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      final recipientField = find.byType(TextField).first;
      await tester.enterText(recipientField, 'test@example.com');

      final amountField = find.byType(TextField).last;
      await tester.enterText(amountField, '100');

      final confirmButton = find.text('Confirm Send');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('Insufficient balance'), findsOneWidget);
    });

    testWidgets('copies public key to clipboard', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 100.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      final copyButton = find.byIcon(Icons.copy);
      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Public key copied to clipboard'), findsOneWidget);
    });

    testWidgets('preset amount buttons populate amount field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        balance: 100.0,
        publicKey: 'GABCDEFGHIJKLMNOPQRSTUVWXYZ123456789ABCDEFGHIJKLMNOPQ',
        network: 'public',
      ));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(ElevatedButton, 'Send');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      final preset25Button = find.text('25');
      await tester.tap(preset25Button);
      await tester.pumpAndSettle();

      final amountField = find.byType(TextField).last;
      final textField = tester.widget<TextField>(amountField);
      expect(textField.controller?.text, '25');
    });
  });
}
