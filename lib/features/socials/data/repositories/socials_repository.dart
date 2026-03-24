import 'dart:convert';
import 'dart:io';

import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/story_model.dart';
import '../models/video_session_model.dart';

/// Repository for socials/video call operations backed by Supabase REST APIs.
class SocialsRepository {
  SocialsRepository() {
    debugPrint('[SocialsRepository] Initialized (Supabase REST)');
  }

  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  Map<String, String> get _restHeaders => {
    'apikey': _supabaseAnonKey,
    'Authorization': 'Bearer $_supabaseAnonKey',
    'Content-Type': 'application/json',
  };

  void _ensureSupabaseConfigured() {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. '
        'Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
      );
    }
  }

  Uri _restUri(String tableOrRpc, [Map<String, String>? query]) {
    final uri = Uri.parse('$_supabaseUrl/rest/v1/$tableOrRpc');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  /// Get current user info from SharedPreferences.
  Future<Map<String, String>> _getCurrentUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'anonymous_user';
      final userEmail = prefs.getString('user_email') ?? 'Anonymous';
      final userName = userEmail.contains('@')
          ? userEmail.split('@')[0]
          : userEmail;

      return {'id': userId, 'name': userName, 'email': userEmail};
    } catch (e) {
      debugPrint('[SocialsRepository] Error getting user info: $e');
      return {
        'id': 'anonymous_user',
        'name': 'Anonymous',
        'email': 'anonymous@example.com',
      };
    }
  }

  Future<List<dynamic>> _decodeList(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Supabase request failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    return <dynamic>[];
  }

  VideoSessionModel _videoSessionFromSupabase(Map<String, dynamic> data) {
    return VideoSessionModel(
      id: (data['id'] ?? '').toString(),
      hostId: (data['host_id'] ?? '').toString(),
      hostName: (data['host_name'] ?? '').toString(),
      hostAvatarUrl: data['host_avatar_url'] as String?,
      title: (data['title'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((data['created_at'] ?? '').toString()) ??
          DateTime.now(),
      expiresAt: data['expires_at'] != null
          ? DateTime.tryParse(data['expires_at'].toString())
          : null,
      participantCount: (data['participant_count'] as num?)?.toInt() ?? 0,
      isVideoEnabled: data['is_video_enabled'] as bool? ?? true,
      isVoiceOnly: data['is_voice_only'] as bool? ?? false,
      isActive: data['is_active'] as bool? ?? true,
    );
  }

  StoryModel _storyFromSupabase(Map<String, dynamic> data) {
    final imageUrlsRaw = data['image_urls'];
    final viewedByRaw = data['viewed_by'];
    return StoryModel(
      id: (data['id'] as num?)?.toInt() ?? 0,
      userId: (data['user_id'] ?? '').toString(),
      userName: (data['user_name'] ?? '').toString(),
      userAvatarUrl: data['user_avatar_url'] as String?,
      imageUrls: imageUrlsRaw is List
          ? imageUrlsRaw.map((e) => e.toString()).toList()
          : const [],
      createdAt:
          DateTime.tryParse((data['created_at'] ?? '').toString()) ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse((data['expires_at'] ?? '').toString()) ??
          DateTime.now().add(const Duration(hours: 24)),
      viewCount: (data['view_count'] as num?)?.toInt() ?? 0,
      viewedBy: viewedByRaw is List
          ? viewedByRaw.map((e) => e.toString()).toList()
          : const [],
      isActive: data['is_active'] as bool? ?? true,
    );
  }

  ScheduledSession _scheduledSessionFromSupabase(Map<String, dynamic> data) {
    return ScheduledSession(
      id: (data['id'] as num?)?.toInt(),
      hostId: (data['host_id'] ?? '').toString(),
      hostName: (data['host_name'] ?? '').toString(),
      hostAvatarUrl: data['host_avatar_url'] as String?,
      title: (data['title'] ?? '').toString(),
      description: data['description'] as String?,
      scheduledTime:
          DateTime.tryParse((data['scheduled_time'] ?? '').toString()) ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse((data['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isVideoEnabled: data['is_video_enabled'] as bool? ?? true,
      isVoiceOnly: data['is_voice_only'] as bool? ?? false,
      isNotified: data['is_notified'] as bool? ?? false,
      isCancelled: data['is_cancelled'] as bool? ?? false,
      actualSessionId: data['actual_session_id']?.toString(),
    );
  }

  /// Get all active sessions.
  Future<List<VideoSessionModel>> getActiveSessions() async {
    _ensureSupabaseConfigured();
    try {
      final response = await http.get(
        _restUri('video_sessions', {
          'is_active': 'eq.true',
          'order': 'created_at.desc',
          'select': '*',
        }),
        headers: _restHeaders,
      );
      final rows = await _decodeList(response);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_videoSessionFromSupabase)
          .toList();
    } catch (e) {
      debugPrint('[SocialsRepository] getActiveSessions error -> $e');
      return [];
    }
  }

  /// Create a new session.
  Future<VideoSessionModel> createSession({
    required String title,
    bool isVoiceOnly = false,
  }) async {
    _ensureSupabaseConfigured();
    final userInfo = await _getCurrentUserInfo();

    final response = await http.post(
      _restUri('video_sessions'),
      headers: {..._restHeaders, 'Prefer': 'return=representation'},
      body: jsonEncode({
        'title': title,
        'host_id': userInfo['id'],
        'host_name': userInfo['name'],
        'host_avatar_url': null,
        'participant_count': 1,
        'is_video_enabled': !isVoiceOnly,
        'is_voice_only': isVoiceOnly,
        'is_active': true,
      }),
    );

    final rows = await _decodeList(response);
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw Exception('Failed to create session: empty response payload');
    }
    return _videoSessionFromSupabase(rows.first as Map<String, dynamic>);
  }

  /// Join a session (increments participant count via RPC).
  Future<bool> joinSession(String sessionId) async {
    _ensureSupabaseConfigured();
    try {
      final response = await http.post(
        _restUri('rpc/increment_participants'),
        headers: _restHeaders,
        body: jsonEncode({'session_id': sessionId}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[SocialsRepository] joinSession error -> $e');
      return false;
    }
  }

  /// Leave a session (decrements participant count via RPC).
  Future<void> leaveSession(String sessionId) async {
    _ensureSupabaseConfigured();
    final response = await http.post(
      _restUri('rpc/decrement_participants'),
      headers: _restHeaders,
      body: jsonEncode({'session_id': sessionId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to leave session (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Get session details.
  Future<VideoSessionModel?> getSession(String sessionId) async {
    _ensureSupabaseConfigured();
    try {
      final response = await http.get(
        _restUri('video_sessions', {
          'id': 'eq.$sessionId',
          'limit': '1',
          'select': '*',
        }),
        headers: _restHeaders,
      );
      final rows = await _decodeList(response);
      if (rows.isEmpty || rows.first is! Map<String, dynamic>) return null;
      return _videoSessionFromSupabase(rows.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SocialsRepository] getSession error -> $e');
      return null;
    }
  }

  /// Agora credentials now come from Supabase Edge Functions in later phase.
  Future<Map<String, String>> getAgoraCredentials(
    String sessionId,
    int userId,
  ) async {
    throw UnimplementedError(
      'Moved to Supabase Edge Functions (migration phase 7).',
    );
  }

  /// Create a scheduled session.
  Future<ScheduledSession> createScheduledSession({
    required String title,
    required DateTime scheduledTime,
    bool isVoiceOnly = false,
    String? description,
  }) async {
    _ensureSupabaseConfigured();
    final userInfo = await _getCurrentUserInfo();
    final response = await http.post(
      _restUri('scheduled_sessions'),
      headers: {..._restHeaders, 'Prefer': 'return=representation'},
      body: jsonEncode({
        'title': title,
        'host_id': userInfo['id'],
        'host_name': userInfo['name'],
        'host_avatar_url': null,
        'description': description,
        'scheduled_time': scheduledTime.toUtc().toIso8601String(),
        'is_video_enabled': !isVoiceOnly,
        'is_voice_only': isVoiceOnly,
        'is_notified': false,
        'is_cancelled': false,
      }),
    );

    final rows = await _decodeList(response);
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw Exception('Failed to create scheduled session: empty response');
    }
    return _scheduledSessionFromSupabase(rows.first as Map<String, dynamic>);
  }

  /// Get upcoming scheduled sessions for the current user.
  Future<List<ScheduledSession>> getUpcomingScheduledSessions() async {
    _ensureSupabaseConfigured();
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final response = await http.get(
        _restUri('scheduled_sessions', {
          'scheduled_time': 'gte.$nowIso',
          'is_cancelled': 'eq.false',
          'order': 'scheduled_time.asc',
          'select': '*',
        }),
        headers: _restHeaders,
      );
      final rows = await _decodeList(response);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_scheduledSessionFromSupabase)
          .toList();
    } catch (e) {
      debugPrint(
        '[SocialsRepository] getUpcomingScheduledSessions error -> $e',
      );
      return [];
    }
  }

  // ==================== STORIES ====================

  /// Get all active stories.
  Future<List<StoryModel>> getActiveStories() async {
    _ensureSupabaseConfigured();
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final response = await http.get(
        _restUri('stories', {
          'is_active': 'eq.true',
          'expires_at': 'gt.$nowIso',
          'order': 'created_at.desc',
          'select': '*',
        }),
        headers: _restHeaders,
      );
      final rows = await _decodeList(response);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_storyFromSupabase)
          .toList();
    } catch (e) {
      debugPrint('[SocialsRepository] getActiveStories error -> $e');
      return [];
    }
  }

  /// Get stories by user ID.
  Future<List<StoryModel>> getUserStories(String userId) async {
    _ensureSupabaseConfigured();
    try {
      final response = await http.get(
        _restUri('stories', {
          'user_id': 'eq.$userId',
          'order': 'created_at.desc',
          'select': '*',
        }),
        headers: _restHeaders,
      );
      final rows = await _decodeList(response);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_storyFromSupabase)
          .toList();
    } catch (e) {
      debugPrint('[SocialsRepository] getUserStories error -> $e');
      return [];
    }
  }

  /// Upload a story image and return its public URL.
  Future<String?> uploadStoryImage(File imageFile, String userId) async {
    _ensureSupabaseConfigured();
    try {
      final fileSize = await imageFile.length();
      const maxUploadSize = 400 * 1024; // 400KB
      if (fileSize > maxUploadSize) {
        throw Exception(
          'Image file exceeds 400KB limit. Please choose a smaller image.',
        );
      }

      final extension = imageFile.path.split('.').last.toLowerCase();
      final objectPath =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final uploadUrl = Uri.parse(
        '$_supabaseUrl/storage/v1/object/stories/$objectPath',
      );

      final response = await http.post(
        uploadUrl,
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'x-upsert': 'false',
          'Content-Type': 'application/octet-stream',
        },
        body: await imageFile.readAsBytes(),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to upload story image '
          '(${response.statusCode}): ${response.body}',
        );
      }

      return '$_supabaseUrl/storage/v1/object/public/stories/$objectPath';
    } catch (e) {
      debugPrint('[SocialsRepository] uploadStoryImage error -> $e');
      rethrow;
    }
  }

  /// Create a new story.
  Future<StoryModel?> createStory({
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required List<String> imageUrls,
  }) async {
    _ensureSupabaseConfigured();
    try {
      final now = DateTime.now().toUtc();
      final response = await http.post(
        _restUri('stories'),
        headers: {..._restHeaders, 'Prefer': 'return=representation'},
        body: jsonEncode({
          'user_id': userId,
          'user_name': userName,
          'user_avatar_url': userAvatarUrl,
          'image_urls': imageUrls,
          'created_at': now.toIso8601String(),
          'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
          'view_count': 0,
          'viewed_by': <String>[],
          'is_active': true,
        }),
      );
      final rows = await _decodeList(response);
      if (rows.isEmpty || rows.first is! Map<String, dynamic>) return null;
      return _storyFromSupabase(rows.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SocialsRepository] createStory error -> $e');
      return null;
    }
  }

  /// View a story (increment view count via RPC).
  Future<void> viewStory(int storyId, String viewerId) async {
    _ensureSupabaseConfigured();
    try {
      final response = await http.post(
        _restUri('rpc/increment_view_count'),
        headers: _restHeaders,
        body: jsonEncode({'story_id': storyId, 'viewer_id': viewerId}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to increment story view count (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('[SocialsRepository] viewStory error -> $e');
    }
  }

  /// Delete a story.
  Future<bool> deleteStory(int storyId, String userId) async {
    _ensureSupabaseConfigured();
    try {
      final response = await http.delete(
        _restUri('stories', {'id': 'eq.$storyId', 'user_id': 'eq.$userId'}),
        headers: _restHeaders,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[SocialsRepository] deleteStory error -> $e');
      return false;
    }
  }
}
