import 'package:echomirror/features/socials/data/models/scheduled_session_model.dart';
import 'package:echomirror/features/socials/data/models/story_model.dart';
import 'package:echomirror/features/socials/data/models/video_session_model.dart';
import 'package:echomirror/features/socials/data/repositories/socials_repository.dart';
import 'package:echomirror/features/socials/viewmodel/providers/socials_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 4, 1, 12, 0);
final _expires = _now.add(const Duration(hours: 24));

VideoSessionModel _makeSession({String id = 'session-1'}) => VideoSessionModel(
  id: id,
  hostId: 'host-1',
  hostName: 'Alice',
  title: 'Test Session',
  createdAt: _now,
  participantCount: 1,
  isActive: true,
);

StoryModel _makeStory({int id = 1}) => StoryModel(
  id: id,
  userId: 'user-1',
  userName: 'Alice',
  imageUrls: const ['https://example.com/img.jpg'],
  createdAt: _now,
  expiresAt: _expires,
  viewCount: 0,
  viewedBy: const [],
  isActive: true,
);

ScheduledSession _makeScheduledSession({int id = 1}) => ScheduledSession(
  id: id,
  hostId: 'host-1',
  hostName: 'Alice',
  title: 'Upcoming Session',
  scheduledTime: _now.add(const Duration(hours: 2)),
  createdAt: _now,
);

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class _FakeSocialsRepository extends SocialsRepository {
  _FakeSocialsRepository({
    this.sessions = const [],
    this.stories = const [],
    this.scheduledSessions = const [],
    this.createdSession,
    this.createdScheduledSession,
    this.failSessions = false,
    this.failStories = false,
    this.failScheduled = false,
    this.failCreateSession = false,
    this.failScheduleSession = false,
  });

  final List<VideoSessionModel> sessions;
  final List<StoryModel> stories;
  final List<ScheduledSession> scheduledSessions;
  final VideoSessionModel? createdSession;
  final ScheduledSession? createdScheduledSession;
  final bool failSessions;
  final bool failStories;
  final bool failScheduled;
  final bool failCreateSession;
  final bool failScheduleSession;

  @override
  Future<List<VideoSessionModel>> getActiveSessions() async {
    if (failSessions) throw Exception('sessions error');
    return sessions;
  }

  @override
  Future<List<StoryModel>> getActiveStories() async {
    if (failStories) throw Exception('stories error');
    return stories;
  }

  @override
  Future<List<ScheduledSession>> getUpcomingScheduledSessions() async {
    if (failScheduled) throw Exception('scheduled error');
    return scheduledSessions;
  }

  @override
  Future<VideoSessionModel> createSession({
    required String title,
    bool isVoiceOnly = false,
  }) async {
    if (failCreateSession) throw Exception('create session error');
    return createdSession!;
  }

  @override
  Future<ScheduledSession> createScheduledSession({
    required String title,
    required DateTime scheduledTime,
    bool isVoiceOnly = false,
    String? description,
  }) async {
    if (failScheduleSession) throw Exception('schedule session error');
    return createdScheduledSession!;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  // -------------------------------------------------------------------------
  // loadActiveSessions
  // -------------------------------------------------------------------------

  group('SocialsNotifier.loadActiveSessions', () {
    test('populates activeSessions on success', () async {
      final session = _makeSession();
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(sessions: [session]),
      );

      await notifier.loadActiveSessions();
      await pumpEventQueue();

      expect(notifier.state.activeSessions, [session]);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('sets error when all fetches fail', () async {
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(
          failSessions: true,
          failStories: true,
          failScheduled: true,
        ),
      );

      await notifier.loadActiveSessions();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.activeSessions, isEmpty);
    });

    test('does not set error in silent mode when all fail', () async {
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(
          failSessions: true,
          failStories: true,
          failScheduled: true,
        ),
      );

      await notifier.loadActiveSessions(silent: true);

      expect(notifier.state.error, isNull);
    });

    test('populates all three lists when all fetches succeed', () async {
      final session = _makeSession();
      final story = _makeStory();
      final scheduled = _makeScheduledSession();
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(
          sessions: [session],
          stories: [story],
          scheduledSessions: [scheduled],
        ),
      );

      await notifier.loadActiveSessions();
      await pumpEventQueue();

      expect(notifier.state.activeSessions, [session]);
      expect(notifier.state.stories, [story]);
      expect(notifier.state.scheduledSessions, [scheduled]);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // loadStories
  // -------------------------------------------------------------------------

  group('SocialsNotifier.loadStories', () {
    test('populates stories on success', () async {
      final story = _makeStory();
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(stories: [story]),
      );

      await notifier.loadStories();

      expect(notifier.state.stories, [story]);
      expect(notifier.state.error, isNull);
    });

    test('sets error state when repository throws', () async {
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(failStories: true),
      );

      await notifier.loadStories();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.stories, isEmpty);
    });

    test('does not set error in silent mode when repository throws', () async {
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(failStories: true),
      );

      await notifier.loadStories(silent: true);

      expect(notifier.state.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // createSession
  // -------------------------------------------------------------------------

  group('SocialsNotifier.createSession', () {
    test('returns created session and reloads active sessions', () async {
      final created = _makeSession(id: 'new-1');
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(createdSession: created, sessions: [created]),
      );

      final result = await notifier.createSession(title: 'New Session');
      await pumpEventQueue();

      expect(result, created);
      expect(notifier.state.activeSessions, [created]);
      expect(notifier.state.error, isNull);
    });

    test('returns null and sets error when repository throws', () async {
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(failCreateSession: true),
      );

      final result = await notifier.createSession(title: 'Fail');

      expect(result, isNull);
      expect(notifier.state.error, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // scheduleSession
  // -------------------------------------------------------------------------

  group('SocialsNotifier.scheduleSession', () {
    test('adds to scheduledSessions on success', () async {
      final scheduled = _makeScheduledSession();
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(
          createdScheduledSession: scheduled,
          scheduledSessions: [scheduled],
        ),
      );

      final result = await notifier.scheduleSession(
        title: 'Upcoming',
        scheduledTime: _now.add(const Duration(hours: 2)),
      );

      expect(result, scheduled);
      expect(notifier.state.scheduledSessions, [scheduled]);
      expect(notifier.state.error, isNull);
    });

    test('returns null and sets error when repository throws', () async {
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(failScheduleSession: true),
      );

      final result = await notifier.scheduleSession(
        title: 'Fail',
        scheduledTime: _now.add(const Duration(hours: 1)),
      );

      expect(result, isNull);
      expect(notifier.state.error, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // startAutoRefresh / stopAutoRefresh
  // -------------------------------------------------------------------------

  group('SocialsNotifier auto-refresh', () {
    test('startAutoRefresh triggers session load after 15 s interval', () {
      fakeAsync((async) {
        final session = _makeSession();
        final notifier = SocialsNotifier(
          _FakeSocialsRepository(sessions: [session]),
        );

        notifier.startAutoRefresh();
        async.elapse(const Duration(seconds: 16));
        async.flushMicrotasks();
        notifier.stopAutoRefresh();

        expect(notifier.state.activeSessions, [session]);
      });
    });

    test('stopAutoRefresh prevents further loads after cancellation', () {
      fakeAsync((async) {
        final session = _makeSession();
        final notifier = SocialsNotifier(
          _FakeSocialsRepository(sessions: [session]),
        );

        notifier.startAutoRefresh();
        notifier.stopAutoRefresh();

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(notifier.state.activeSessions, isEmpty);
      });
    });

    test('startAutoRefresh replaces existing timer without error', () {
      fakeAsync((async) {
        final notifier = SocialsNotifier(_FakeSocialsRepository());

        notifier.startAutoRefresh();
        notifier.startAutoRefresh();
        notifier.stopAutoRefresh();

        async.elapse(const Duration(seconds: 30));
      });
    });
  });
}
