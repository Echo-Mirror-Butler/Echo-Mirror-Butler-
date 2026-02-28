import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echomirror_server_client/echomirror_server_client.dart';
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
  }) {
    return SocialsState(
      activeSessions: activeSessions ?? this.activeSessions,
      stories: stories ?? this.stories,
      scheduledSessions: scheduledSessions ?? this.scheduledSessions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Socials notifier with auto-refresh capability
class SocialsNotifier extends StateNotifier<SocialsState> {
  SocialsNotifier(this._repository) : super(const SocialsState()) {
    _startAutoRefresh();
  }

  final SocialsRepository _repository;
  final NotificationService _notificationService = NotificationService();
  Timer? _refreshTimer;
  List<String> _notifiedSessions =
      []; // Track sessions we've already notified about

  /// Start auto-refresh timer (every 5 seconds)
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final sessions = await _repository.getActiveSessions();
      final stories = await _repository.getActiveStories();
      final scheduled = await _repository.getUpcomingScheduledSessions();
      state = state.copyWith(
        activeSessions: sessions,
        stories: stories,
        scheduledSessions: scheduled,
        isLoading: false,
      );

      // Notify about new active sessions
      if (sessions.isNotEmpty) {
        _notifyAboutActiveSessions(sessions);
      }
    } catch (e) {
      debugPrint('[SocialsNotifier] Error loading sessions: $e');
      if (!silent) {
        state = state.copyWith(isLoading: false, error: e.toString());
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

  /// Load stories only
  Future<void> loadStories({bool silent = false}) async {
    try {
      final stories = await _repository.getActiveStories();
      state = state.copyWith(stories: stories);
    } catch (e) {
      debugPrint('[SocialsNotifier] Error loading stories: $e');
    }
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
}

/// Socials provider
final socialsProvider = StateNotifierProvider<SocialsNotifier, SocialsState>((
  ref,
) {
  return SocialsNotifier(ref.read(socialsRepositoryProvider));
});
