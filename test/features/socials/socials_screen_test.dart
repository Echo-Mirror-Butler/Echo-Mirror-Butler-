import 'package:echomirror/core/viewmodel/providers/main_tab_index_provider.dart';
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
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pipChannel, null);
  });

  Widget buildScreen(
    SocialsState state, {
    NavigatorObserver? navigatorObserver,
  }) {
    return ProviderScope(
      overrides: [
        mainTabIndexProvider.overrideWith((ref) => 2),
        socialsProvider.overrideWith((ref) => _FakeSocialsNotifier(state)),
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

  testWidgets('renders empty state when sessions list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(const SocialsState()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No Active Sessions'), findsOneWidget);
    expect(find.text('Your Story'), findsOneWidget);
  });

  testWidgets('renders session cards when sessions are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        SocialsState(activeSessions: [buildSession()]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ada (LIVE)'), findsOneWidget);
    expect(find.text('Evening Check-in'), findsOneWidget);
  });

  testWidgets('renders stories bar items', (tester) async {
    await tester.pumpWidget(
      buildScreen(
        SocialsState(stories: [buildStory()]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your Story'), findsOneWidget);
    expect(find.text('Bella'), findsOneWidget);
  });

  testWidgets('tapping a session card pushes a new route', (tester) async {
    final observer = MockNavigatorObserver();

    await tester.pumpWidget(
      buildScreen(
        SocialsState(activeSessions: [buildSession()]),
        navigatorObserver: observer,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    clearInteractions(observer);

    await tester.tap(find.text('Ada (LIVE)'));
    await tester.pump();

    verify(() => observer.didPush(any(), any())).called(1);
  });

  testWidgets('notification icon is visible in the app bar', (tester) async {
    await tester.pumpWidget(buildScreen(const SocialsState()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(FontAwesomeIcons.bell), findsOneWidget);
  });
}
