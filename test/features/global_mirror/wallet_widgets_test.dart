import 'package:echomirror/features/global_mirror/data/models/on_chain_transaction_model.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/echo_balance_card.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/send_echo_sheet.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/wallet_empty_state.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/wallet_history_section.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/wallet_public_key_card.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/wallet_qr_sheet.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/wallet_status_cards.dart';
import 'package:echomirror/features/global_mirror/view/widgets/wallet/wallet_testnet_banner.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _publicKey = 'GABCDEFGHIJKLMNOPQRSTUVWXYZ234567ABCDEFGHIJKLMNOPQRSTUVW';

class _FakeWalletNotifier extends WalletNotifier {
  _FakeWalletNotifier(WalletState initialState) {
    state = initialState;
  }

  @override
  Future<void> loadWallet() async {}

  @override
  Future<void> refreshLiveBalances() async {}
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

OnChainTransactionModel _tx({required String from, required String to}) {
  return OnChainTransactionModel(
    id: '1',
    type: 'payment',
    transactionHash: 'hash',
    sourceAccount: from,
    amount: '12.5',
    asset: 'XLM',
    from: from,
    to: to,
    timestamp: DateTime(2026, 3, 4, 12),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('formatRewardReason', () {
    test('maps known reason codes to labels', () {
      expect(formatRewardReason('daily_mood_log'), 'Daily log');
      expect(formatRewardReason('7_day_streak_bonus'), '7-day streak bonus');
      expect(formatRewardReason('gift_received'), 'Gift received');
    });

    test('title-cases unknown reason codes', () {
      expect(formatRewardReason('weekly-challenge_win'), 'Weekly Challenge Win');
    });
  });

  group('formatWalletLastUpdated', () {
    final now = DateTime(2026, 1, 1, 12);

    test('formats relative durations', () {
      expect(formatWalletLastUpdated(now, now: now), 'just now');
      expect(
        formatWalletLastUpdated(now.subtract(const Duration(seconds: 42)), now: now),
        '42s ago',
      );
      expect(
        formatWalletLastUpdated(now.subtract(const Duration(minutes: 7)), now: now),
        '7m ago',
      );
      expect(
        formatWalletLastUpdated(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
    });
  });

  group('RewardHistorySection', () {
    testWidgets('shows empty message when there is no history', (tester) async {
      await tester.pumpWidget(_wrap(const RewardHistorySection(history: [])));

      expect(find.text('Transaction History'), findsOneWidget);
      expect(find.text('No transaction history yet.'), findsOneWidget);
    });

    testWidgets('renders rewards with formatted reason and signed amount', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RewardHistorySection(
            history: [
              WalletReward(
                reason: 'daily_mood_log',
                amount: 5,
                createdAt: DateTime(2026, 2, 1, 12),
              ),
              WalletReward(
                reason: 'gift_sent',
                amount: 2.5,
                createdAt: DateTime(2026, 2, 2, 12),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Daily log'), findsOneWidget);
      expect(find.text('+5 ECHO'), findsOneWidget);
      expect(find.text('Gift Sent'), findsOneWidget);
      expect(find.text('+2.50 ECHO'), findsOneWidget);
      expect(find.text('2026-02-01'), findsOneWidget);
    });
  });

  group('OnChainActivitySection', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OnChainActivitySection(
            transactions: [],
            publicKey: _publicKey,
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No on-chain activity yet.'), findsNothing);
    });

    testWidgets('shows empty message when there are no transactions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const OnChainActivitySection(
            transactions: [],
            publicKey: _publicKey,
            isLoading: false,
          ),
        ),
      );

      expect(find.text('No on-chain activity yet.'), findsOneWidget);
    });

    testWidgets('signs amounts by direction relative to the wallet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OnChainActivitySection(
            transactions: [
              _tx(from: 'GOTHER', to: _publicKey),
              _tx(from: _publicKey, to: 'GOTHER'),
            ],
            publicKey: _publicKey,
            isLoading: false,
          ),
        ),
      );

      expect(find.text('Payment'), findsNWidgets(2));
      expect(find.text('+12.5 XLM'), findsOneWidget);
      expect(find.text('-12.5 XLM'), findsOneWidget);
    });
  });

  group('WalletPublicKeyCard', () {
    testWidgets('shows the key and fires copy / QR callbacks', (tester) async {
      var copied = 0;
      var qr = 0;
      await tester.pumpWidget(
        _wrap(
          WalletPublicKeyCard(
            publicKey: _publicKey,
            onCopy: () => copied++,
            onShowQr: () => qr++,
          ),
        ),
      );

      expect(find.text(_publicKey), findsOneWidget);
      await tester.tap(find.text('Copy Key'));
      await tester.tap(find.text('Show QR'));
      expect(copied, 1);
      expect(qr, 1);
    });
  });

  group('FundedBalanceCard', () {
    testWidgets('renders XLM and ECHO headline and fires actions', (
      tester,
    ) async {
      var sent = 0;
      var copied = 0;
      await tester.pumpWidget(
        _wrap(
          FundedBalanceCard(
            walletState: const WalletState(
              exists: true,
              funded: true,
              publicKey: _publicKey,
              balance: 42,
              xlmBalance: 10000,
            ),
            onSend: () => sent++,
            onCopy: () => copied++,
          ),
        ),
      );

      expect(find.text('Wallet Balance'), findsOneWidget);
      expect(find.text('10000.00 XLM · 42 ECHO'), findsOneWidget);
      expect(find.text('Streak bonus active'), findsNothing);

      await tester.tap(find.text('Send ECHO'));
      await tester.tap(find.text('Copy address'));
      expect(sent, 1);
      expect(copied, 1);
    });

    testWidgets('shows streak pill when history has a bonus', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FundedBalanceCard(
            walletState: WalletState(
              funded: true,
              history: [
                WalletReward(
                  reason: 'streak_bonus',
                  amount: 10,
                  createdAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
            onSend: () {},
            onCopy: () {},
          ),
        ),
      );

      expect(find.text('Streak bonus active'), findsOneWidget);
    });
  });

  group('UnfundedActivationCard', () {
    testWidgets('offers Friendbot on testnet and fires onFund', (tester) async {
      var funded = 0;
      await tester.pumpWidget(
        _wrap(
          UnfundedActivationCard(
            walletState: const WalletState(exists: true, publicKey: _publicKey),
            onFund: () => funded++,
          ),
        ),
      );

      expect(find.text('Activation Required'), findsOneWidget);
      expect(find.text(_publicKey), findsOneWidget);
      await tester.tap(find.text('Fund with Friendbot'));
      expect(funded, 1);
    });

    testWidgets('disables the Friendbot button while funding', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UnfundedActivationCard(
            walletState: const WalletState(isFunding: true),
            onFund: () {},
          ),
        ),
      );

      expect(find.text('Funding…'), findsOneWidget);
    });
  });

  group('EchoBalanceCard', () {
    testWidgets('shows balances, USD conversion and send action', (
      tester,
    ) async {
      var sent = 0;
      await tester.pumpWidget(
        _wrap(
          EchoBalanceCard(
            walletState: const WalletState(
              echoBalance: 12.34,
              xlmBalance: 20,
              xlmPrice: 0.5,
            ),
            onSend: () => sent++,
            onCopy: () {},
            onFund: () {},
          ),
        ),
      );

      expect(find.text('ECHO Balance'), findsOneWidget);
      expect(find.text('12.3 ECHO'), findsOneWidget);
      expect(find.text('20.00 XLM'), findsOneWidget);
      expect(find.text('≈ \$10.00'), findsOneWidget);

      await tester.tap(find.text('Send ECHO'));
      expect(sent, 1);
    });

    testWidgets('replaces actions with Friendbot CTA on Stellar error', (
      tester,
    ) async {
      var funded = 0;
      await tester.pumpWidget(
        _wrap(
          EchoBalanceCard(
            walletState: const WalletState(
              echoBalance: 1,
              stellarError: 'Horizon timed out',
            ),
            onSend: () {},
            onCopy: () {},
            onFund: () => funded++,
          ),
        ),
      );

      expect(find.text('Horizon timed out'), findsOneWidget);
      expect(find.text('Send ECHO'), findsNothing);
      await tester.tap(find.text('Fund with Friendbot'));
      expect(funded, 1);
    });
  });

  group('WalletEmptyState', () {
    testWidgets('fires onCreateWallet', (tester) async {
      var created = 0;
      await tester.pumpWidget(
        _wrap(WalletEmptyState(onCreateWallet: () => created++)),
      );

      expect(find.text('Wallet not set up yet'), findsOneWidget);
      await tester.tap(find.text('Create wallet'));
      expect(created, 1);
    });
  });

  group('WalletQrSheet', () {
    testWidgets('shows the truncated key', (tester) async {
      await tester.pumpWidget(
        _wrap(const WalletQrSheet(publicKey: _publicKey)),
      );

      expect(find.text('Scan to Send ECHO'), findsOneWidget);
      expect(
        find.text(
          '${_publicKey.substring(0, 8)}...'
          '${_publicKey.substring(_publicKey.length - 8)}',
        ),
        findsOneWidget,
      );
    });
  });

  group('WalletTestnetBanner', () {
    testWidgets('hides after dismissal and remembers it', (tester) async {
      await tester.pumpWidget(_wrap(const WalletTestnetBanner()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Testnet'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining('Testnet'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('testnet_banner_dismissed'), isTrue);
    });

    testWidgets('stays hidden when previously dismissed', (tester) async {
      SharedPreferences.setMockInitialValues({
        'testnet_banner_dismissed': true,
      });
      await tester.pumpWidget(_wrap(const WalletTestnetBanner()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Testnet'), findsNothing);
    });
  });

  group('SendEchoSheet', () {
    Widget sheet({double balance = 100}) {
      return ProviderScope(
        overrides: [
          walletProvider.overrideWith(
            (ref) => _FakeWalletNotifier(
              WalletState(exists: true, funded: true, balance: balance),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SendEchoSheet(
                // Never contacted: the tests below only use inputs that fail
                // the recipient format check before any network call.
                client: SupabaseClient('http://localhost:54321', 'test-key'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('defaults to the 10 ECHO preset and updates on chip tap', (
      tester,
    ) async {
      await tester.pumpWidget(sheet());
      await tester.pumpAndSettle();

      TextField amountField() =>
          tester.widget<TextField>(find.byType(TextField).last);
      expect(amountField().controller?.text, '10');

      await tester.tap(find.text('50 ECHO'));
      await tester.pumpAndSettle();
      expect(amountField().controller?.text, '50');
    });

    testWidgets('send is disabled until a recipient resolves', (tester) async {
      await tester.pumpWidget(sheet());
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Send ECHO'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('flags an unresolvable recipient', (tester) async {
      await tester.pumpWidget(sheet());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'nope');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Recipient not found'), findsOneWidget);
    });

    testWidgets('validates amount against the wallet balance', (tester) async {
      await tester.pumpWidget(sheet(balance: 10));
      await tester.pumpAndSettle();

      final amount = find.byType(TextField).last;
      await tester.enterText(amount, 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid number'), findsOneWidget);

      await tester.enterText(amount, '0');
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than 0'), findsOneWidget);

      await tester.enterText(amount, '100');
      await tester.pumpAndSettle();
      expect(find.text('Insufficient ECHO balance'), findsOneWidget);
    });

    testWidgets('cancel closes the sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletProvider.overrideWith(
              (ref) => _FakeWalletNotifier(const WalletState(balance: 100)),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SendEchoSheet(
                      client: SupabaseClient(
                        'http://localhost:54321',
                        'test-key',
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SendEchoSheet), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(SendEchoSheet), findsNothing);
    });
  });
}
