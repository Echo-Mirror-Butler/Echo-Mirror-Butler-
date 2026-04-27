import 'package:echomirror/core/viewmodel/providers/main_tab_index_provider.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/mood_comment_notification_provider.dart';
import 'package:echomirror/features/socials/data/models/story_model.dart';
import 'package:echomirror/features/socials/data/models/video_session_model.dart';
import 'package:echomirror/features/socials/data/repositories/socials_repository.dart';
import 'package:echomirror/features/socials/view/screens/socials_screen.dart';
import 'package:echomirror/features/socials/viewmodel/providers/socials_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class _FakeMoodCommentNotifier extends MoodCommentNotificationNotifier {
  _FakeMoodCommentNotifier() : super.forTesting();
}

class _FakeSocialsNotifier extends SocialsNotifier {
  _FakeSocialsNotifier(this._initialState) : super(SocialsRepository()) {
    state = _initialState;
  }

  final SocialsState _initialState;

  @override
  void startAutoRefresh() {}

  @override
  void stopAutoRefresh() {}

  @override
  Future<void> loadActiveSessions({bool silent = false}) async {}

  @override
  Future<void> loadStories({bool silent = false}) async {}
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel wakelockChannel = MethodChannel('wakelock_plus');
  const MethodChannel pipChannel = MethodChannel('com.echomirror.app/pip');
  const MethodChannel agoraChannel = MethodChannel('agora_rtc_ng');

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_id': 'user-1',
      'user_email': 'tester@example.com',
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, (call) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pipChannel, (call) async {
          if (call.method == 'isPipSupported' || call.method == 'isInPipMode') {
            return false;
          }
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agoraChannel, (call) async => null);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pipChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(agoraChannel, null);
    // Drain any pending microtasks
    await Future<void>.delayed(Duration.zero);
  });

  Widget buildScreen(
    SocialsState state, {
    NavigatorObserver? navigatorObserver,
  }) {
    return ProviderScope(
      overrides: [
        mainTabIndexProvider.overrideWith((ref) => 2),
        socialsProvider.overrideWith((ref) => _FakeSocialsNotifier(state)),
        moodCommentNotificationProvider.overrideWith(
          (ref) => _FakeMoodCommentNotifier(),
        ),
      ],
      child: MaterialApp(
        home: const SocialsScreen(),
        navigatorObservers: navigatorObserver == null
            ? const []
            : [navigatorObserver],
      ),
    );
  }

  VideoSessionModel buildSession() {
    return VideoSessionModel(
      id: 'session-1',
      hostId: 'host-1',
      hostName: 'Ada',
      title: 'Evening Check-in',
      createdAt: DateTime(2026, 3, 27, 10),
      participantCount: 3,
      isActive: true,
    );
  }

  StoryModel buildStory() {
    return StoryModel(
      id: 1,
      userId: 'user-2',
      userName: 'Bella',
      imageUrls: const ['https://example.com/story.jpg'],
      createdAt: DateTime(2026, 3, 27, 9),
      expiresAt: DateTime(2026, 3, 28, 9),
      viewCount: 0,
      viewedBy: const [],
      isActive: true,
    );
  }

  // Pump enough time to drain animate_do timers (FadeInUp uses ~800ms delays)
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 2));

  testWidgets('renders empty state when sessions list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(const SocialsState()));
    await settle(tester);

    expect(find.text('No Active Sessions'), findsOneWidget);
    expect(find.text('Your Story'), findsOneWidget);
  });

  testWidgets('renders session cards when sessions are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(SocialsState(activeSessions: [buildSession()])),
    );
    await settle(tester);

    expect(find.text('Ada (LIVE)'), findsOneWidget);
    expect(find.text('Evening Check-in'), findsOneWidget);
  });

  testWidgets('renders stories bar items', (tester) async {
    await tester.pumpWidget(buildScreen(SocialsState(stories: [buildStory()])));
    await settle(tester);

    expect(find.text('Your Story'), findsOneWidget);
    expect(find.text('Bella'), findsOneWidget);
  });

  testWidgets('renders stories skeleton while stories are loading', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(const SocialsState(isLoading: true)));
    await settle(tester);

    expect(find.byType(Shimmer), findsWidgets);
    expect(find.text('Your Story'), findsNothing);
  });

  testWidgets('renders retryable no connection state for socials errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(const SocialsState(error: 'Unable to load socials')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('tapping a session card pushes a new route', (tester) async {
    final observer = MockNavigatorObserver();

    await tester.pumpWidget(
      buildScreen(
        SocialsState(activeSessions: [buildSession()]),
        navigatorObserver: observer,
      ),
    );
    await settle(tester);

    // Verify the session card is in the tree before tapping
    expect(find.text('Evening Check-in'), findsOneWidget);
    clearInteractions(observer);

    // Pump enough time for FadeInUp animations to complete
    await tester.pump(const Duration(seconds: 3));

    // Tap the InkWell that wraps the session card content
    final inkWell = find
        .ancestor(
          of: find.text('Evening Check-in'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(inkWell, warnIfMissed: false);
    await tester.pump();

    verify(
      () => observer.didPush(any(), any()),
    ).called(greaterThanOrEqualTo(1));

    // Pop back so SocialsScreen (and its StoriesBar pulse animation) disposes
    // before the test framework checks for pending timers.
    final NavigatorState nav = tester.state(find.byType(Navigator));
    nav.pop();
    await tester.pump();
    await settle(tester);
  });

  testWidgets('notification icon is visible in the app bar', (tester) async {
    await tester.pumpWidget(buildScreen(const SocialsState()));
    await settle(tester);

    expect(find.byIcon(FontAwesomeIcons.bell), findsOneWidget);
  });
}
