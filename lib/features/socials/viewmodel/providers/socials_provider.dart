import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/scheduled_session_model.dart';
import '../../data/models/video_session_model.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/socials_repository.dart';
import '../../../../core/services/notification_service.dart';

/// Socials repository provider
final socialsRepositoryProvider = Provider<SocialsRepository>((ref) {
  return SocialsRepository();
});

/// Socials state
class SocialsState {
  final List<VideoSessionModel> activeSessions;
  final List<StoryModel> stories;
  final List<ScheduledSession> scheduledSessions;
  final bool isLoading;
  final String? error;

  const SocialsState({
    this.activeSessions = const [],
    this.stories = const [],
    this.scheduledSessions = const [],
    this.isLoading = false,
    this.error,
  });

  SocialsState copyWith({
    List<VideoSessionModel>? activeSessions,
    List<StoryModel>? stories,
    List<ScheduledSession>? scheduledSessions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SocialsState(
      activeSessions: activeSessions ?? this.activeSessions,
      stories: stories ?? this.stories,
      scheduledSessions: scheduledSessions ?? this.scheduledSessions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Socials notifier with auto-refresh capability
class SocialsNotifier extends StateNotifier<SocialsState> {
  SocialsNotifier(this._repository) : super(const SocialsState());

  final SocialsRepository _repository;
  final NotificationService _notificationService = NotificationService();
  Timer? _refreshTimer;
  final List<String> _notifiedSessions =
      []; // Track sessions we've already notified about

  /// Start auto-refresh timer (every 15 seconds)
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // Only refresh if not currently loading (to avoid overlapping requests)
      if (!state.isLoading) {
        loadActiveSessions(silent: true);
      }
    });
  }

  /// Stop auto-refresh timer
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Load active sessions and stories
  Future<void> loadActiveSessions({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    final sessionsFuture = _loadSection<List<VideoSessionModel>>(
      'active sessions',
      _repository.getActiveSessions,
    );
    final storiesFuture = _loadSection<List<StoryModel>>(
      'stories',
      _repository.getActiveStories,
    );
    final scheduledFuture = _loadSection<List<ScheduledSession>>(
      'scheduled sessions',
      _repository.getUpcomingScheduledSessions,
    );

    final sessionsResult = await sessionsFuture;
    final storiesResult = await storiesFuture;
    final scheduledResult = await scheduledFuture;
    final results = [sessionsResult, storiesResult, scheduledResult];
    final failedResults = results.where((result) => !result.isSuccess).toList();
    final allFailed = failedResults.length == results.length;

    if (allFailed) {
      if (!silent) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Unable to load socials right now. Please check your connection and try again.',
        );
      }
      return;
    }

    if (failedResults.isNotEmpty) {
      debugPrint(
        '[SocialsNotifier] Partial socials load failure: '
        '${failedResults.map((result) => result.label).join(', ')}',
      );
    }

    final sessions = sessionsResult.value;
    state = state.copyWith(
      activeSessions: sessions ?? state.activeSessions,
      stories: storiesResult.value ?? state.stories,
      scheduledSessions: scheduledResult.value ?? state.scheduledSessions,
      isLoading: false,
      clearError: true,
    );

    // Notify about new active sessions
    if (sessions != null && sessions.isNotEmpty) {
      _notifyAboutActiveSessions(sessions);
    }
  }

  Future<_SectionLoadResult<T>> _loadSection<T>(
    String label,
    Future<T> Function() load,
  ) async {
    try {
      return _SectionLoadResult.success(label, await load());
    } catch (e) {
      debugPrint('[SocialsNotifier] Error loading $label: $e');
      return _SectionLoadResult.failure(label, e);
    }
  }

  /// Load stories only
  Future<void> loadStories({bool silent = false}) async {
    try {
      final stories = await _repository.getActiveStories();
      state = state.copyWith(stories: stories, clearError: true);
    } catch (e) {
      debugPrint('[SocialsNotifier] Error loading stories: $e');
      if (!silent) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  /// Notify about active sessions
  void _notifyAboutActiveSessions(List<VideoSessionModel> sessions) {
    for (final session in sessions) {
      // Only notify about sessions we haven't notified about yet
      final sessionKey =
          '${session.id}-${session.createdAt.millisecondsSinceEpoch}';
      if (!_notifiedSessions.contains(sessionKey)) {
        _notificationService.notifyActiveSessionAvailable(
          sessionTitle: session.title,
          hostName: session.hostName,
          participantCount: session.participantCount,
        );
        _notifiedSessions.add(sessionKey);

        // Clean up old session keys (keep only last 10)
        if (_notifiedSessions.length > 10) {
          _notifiedSessions.removeAt(0);
        }
      }
    }

    // Remove keys for sessions that are no longer active
    final activeSessionKeys = sessions
        .map((s) => '${s.id}-${s.createdAt.millisecondsSinceEpoch}')
        .toSet();
    _notifiedSessions.removeWhere((key) => !activeSessionKeys.contains(key));
  }

  /// Create a new session
  Future<VideoSessionModel?> createSession({
    required String title,
    bool isVoiceOnly = false,
  }) async {
    try {
      final session = await _repository.createSession(
        title: title,
        isVoiceOnly: isVoiceOnly,
      );
      // Reload active sessions
      await loadActiveSessions();
      return session;
    } catch (e) {
      debugPrint('[SocialsNotifier] Error creating session: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Schedule a future session
  Future<ScheduledSession?> scheduleSession({
    required String title,
    required DateTime scheduledTime,
    bool isVoiceOnly = false,
  }) async {
    try {
      final session = await _repository.createScheduledSession(
        title: title,
        scheduledTime: scheduledTime,
        isVoiceOnly: isVoiceOnly,
      );
      final scheduled = await _repository.getUpcomingScheduledSessions();
      state = state.copyWith(scheduledSessions: scheduled);
      return session;
    } catch (e) {
      debugPrint('[SocialsNotifier] Error scheduling session: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Join a session
  Future<bool> joinSession(String sessionId) async {
    try {
      await _repository.joinSession(sessionId);
      await loadActiveSessions();
      return true;
    } catch (e) {
      debugPrint('[SocialsNotifier] Error joining session: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Leave a session
  Future<void> leaveSession(String sessionId) async {
    try {
      await _repository.leaveSession(sessionId);
      await loadActiveSessions();
    } catch (e) {
      debugPrint('[SocialsNotifier] Error leaving session: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// End a session (host only - marks session as inactive)
  Future<void> endSession(String sessionId) async {
    try {
      await _repository.endSession(sessionId);
      await loadActiveSessions();
    } catch (e) {
      debugPrint('[SocialsNotifier] Error ending session: $e');
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Socials provider
final socialsProvider = StateNotifierProvider<SocialsNotifier, SocialsState>((
  ref,
) {
  return SocialsNotifier(ref.read(socialsRepositoryProvider));
});

class _SectionLoadResult<T> {
  const _SectionLoadResult._({required this.label, this.value, this.error});

  factory _SectionLoadResult.success(String label, T value) {
    return _SectionLoadResult._(label: label, value: value);
  }

  factory _SectionLoadResult.failure(String label, Object error) {
    return _SectionLoadResult._(label: label, error: error);
  }

  final String label;
  final T? value;
  final Object? error;

  bool get isSuccess => error == null;
}
