import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/gift_repository.dart';
import 'package:echomirror/features/global_mirror/view/screens/gift_screen.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/gift_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeGiftRepository extends GiftRepository {
  _FakeGiftRepository();

  @override
  Future<double> getEchoBalance() async => 0.0;

  @override
  Future<List<GiftTransactionModel>> getGiftHistory() async =>
      const <GiftTransactionModel>[];
}

class _FakeGiftNotifier extends GiftNotifier {
  _FakeGiftNotifier(this._initialState) : super(_FakeGiftRepository()) {
    state = _initialState;
  }

  final GiftState _initialState;
  bool sendGiftCalled = false;
  bool shouldSendSucceed = true;

  @override
  Future<void> loadBalance() async {}

  @override
  Future<void> loadHistory() async {}

  @override
  Future<bool> sendGift({
    required String recipientUserId,
    required double amount,
    String? message,
  }) async {
    sendGiftCalled = true;
    return shouldSendSucceed;
  }
}

void main() {
  Widget buildScreen(
    GiftState giftState, {
    String recipientUserId = 'recipient_1',
    bool sendSucceeds = true,
    bool withRouterPopFlow = false,
    _FakeGiftNotifier? notifier,
  }) {
    final fakeNotifier = notifier ?? _FakeGiftNotifier(giftState);
    fakeNotifier.shouldSendSucceed = sendSucceeds;

    if (!withRouterPopFlow) {
      return ProviderScope(
        overrides: [giftProvider.overrideWith((ref) => fakeNotifier)],
        child: MaterialApp(home: GiftScreen(recipientUserId: recipientUserId)),
      );
    }

    final router = GoRouter(
      initialLocation: '/send',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Root Screen')),
        ),
        GoRoute(
          path: '/send',
          builder: (context, state) =>
              GiftScreen(recipientUserId: recipientUserId),
        ),
      ],
    );

    return ProviderScope(
      overrides: [giftProvider.overrideWith((ref) => fakeNotifier)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('displays balance from giftProvider state', (tester) async {
    await tester.pumpWidget(buildScreen(const GiftState(echoBalance: 125)));
    await tester.pumpAndSettle();

    expect(find.text('Your ECHO Balance'), findsOneWidget);
    expect(find.text('125 ECHO'), findsOneWidget);
  });

  testWidgets('displays balance placeholder when balance loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        const GiftState(balanceError: 'Unable to load your ECHO balance.'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('-- ECHO'), findsOneWidget);
    expect(find.text('Unable to load your ECHO balance.'), findsOneWidget);
  });

  testWidgets('displays retryable gift history error state', (tester) async {
    await tester.pumpWidget(
      buildScreen(
        const GiftState(
          echoBalance: 100,
          historyError: 'Unable to load gift history.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load gift history.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders amount chips and selecting one updates send label', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(const GiftState(echoBalance: 500)));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.text('Send 5 ECHO'), findsOneWidget);

    await tester.tap(find.text('10 ECHO'));
    await tester.pumpAndSettle();

    expect(find.text('Send 10 ECHO'), findsOneWidget);
  });

  testWidgets('send button is disabled when recipient is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(const GiftState(echoBalance: 100), recipientUserId: ''),
    );
    await tester.pumpAndSettle();

    final sendButton = tester.widget<FilledButton>(
      find.byType(FilledButton).first,
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('send button shows loading indicator when isLoading is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(const GiftState(echoBalance: 100, isLoading: true)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Sending...'), findsOneWidget);
  });

  testWidgets('send button shows Sending... text when isSending is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(const GiftState(echoBalance: 100, isSending: true)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Sending...'), findsOneWidget);

    final sendButton = tester.widget<FilledButton>(
      find.byType(FilledButton).first,
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('error state shows a SnackBar with the error message', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        const GiftState(echoBalance: 100, error: 'Failed to send gift'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Failed to send gift'), findsWidgets);
  });

  testWidgets('successful send navigates away from GiftScreen', (tester) async {
    final notifier = _FakeGiftNotifier(const GiftState(echoBalance: 100));
    notifier.shouldSendSucceed = true;

    await tester.pumpWidget(
      buildScreen(
        const GiftState(echoBalance: 100),
        withRouterPopFlow: true,
        notifier: notifier,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send ECHO Gift'), findsOneWidget);

    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(notifier.sendGiftCalled, isTrue);
    expect(find.text('Root Screen'), findsOneWidget);
    expect(find.text('Send ECHO Gift'), findsNothing);
  });
}
