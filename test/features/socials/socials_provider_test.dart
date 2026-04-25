import 'package:echomirror/features/socials/data/models/scheduled_session_model.dart';
import 'package:echomirror/features/socials/data/models/story_model.dart';
import 'package:echomirror/features/socials/data/models/video_session_model.dart';
import 'package:echomirror/features/socials/data/repositories/socials_repository.dart';
import 'package:echomirror/features/socials/viewmodel/providers/socials_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSocialsRepository extends SocialsRepository {
  _FakeSocialsRepository({
    this._sessions = const [],
    this.stories = const [],
    this._scheduledSessions = const [],
    this.failSessions = false,
    this.failStories = false,
    this.failScheduledSessions = false,
  });

  final List<VideoSessionModel> _sessions;
  final List<StoryModel> stories;
  final List<ScheduledSession> _scheduledSessions;
  final bool failSessions;
  final bool failStories;
  final bool failScheduledSessions;

  @override
  Future<List<VideoSessionModel>> getActiveSessions() async {
    if (failSessions) throw Exception('sessions unavailable');
    return _sessions;
  }

  @override
  Future<List<StoryModel>> getActiveStories() async {
    if (failStories) throw Exception('stories unavailable');
    return stories;
  }

  @override
  Future<List<ScheduledSession>> getUpcomingScheduledSessions() async {
    if (failScheduledSessions) {
      throw Exception('scheduled sessions unavailable');
    }
    return _scheduledSessions;
  }
}

void main() {
  group('SocialsNotifier', () {
    test('sets error when all socials fetches fail', () async {
      final notifier = SocialsNotifier(
        _FakeSocialsRepository(
          failSessions: true,
          failStories: true,
          failScheduledSessions: true,
        ),
      );

      await notifier.loadActiveSessions();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.activeSessions, isEmpty);
      expect(notifier.state.stories, isEmpty);
      expect(notifier.state.scheduledSessions, isEmpty);
    });

    test(
      'keeps successful partial results when one socials fetch fails',
      () async {
        final story = StoryModel(
          id: 1,
          userId: 'user-1',
          userName: 'Ada',
          imageUrls: const ['https://example.com/story.jpg'],
          createdAt: DateTime(2026, 4, 1),
          expiresAt: DateTime(2026, 4, 2),
          viewCount: 0,
          viewedBy: const [],
          isActive: true,
        );
        final notifier = SocialsNotifier(
          _FakeSocialsRepository(stories: [story], failSessions: true),
        );

        await notifier.loadActiveSessions();

        expect(notifier.state.error, isNull);
        expect(notifier.state.activeSessions, isEmpty);
        expect(notifier.state.stories, [story]);
      },
    );
  });
}
