import 'package:flutter/foundation.dart';
import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/serverpod_client_service.dart';
import 'dart:io';
import 'package:echomirror_server_client/echomirror_server_client.dart'
    as serverpod;
import '../models/video_session_model.dart';
import '../models/story_model.dart';

/// Repository for socials/video call operations
class SocialsRepository {
  SocialsRepository() {
    debugPrint('[SocialsRepository] Initialized');
  }

  Client get _client => ServerpodClientService.instance.client;

  /// Get current user info from SharedPreferences
  Future<Map<String, String>> _getCurrentUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'anonymous_user';
      final userEmail = prefs.getString('user_email') ?? 'Anonymous';

      // Extract name from email (part before @) or use email
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

  /// Get all active sessions
  Future<List<VideoSessionModel>> getActiveSessions() async {
    try {
      debugPrint('[SocialsRepository] getActiveSessions');

      final results = await _client.socials.getActiveSessions();
      debugPrint(
        '[SocialsRepository] Fetched ${results.length} active sessions from server',
      );

      return results.map((session) => _convertToModel(session)).toList();
    } catch (e) {
      debugPrint('[SocialsRepository] getActiveSessions error -> $e');
      return [];
    }
  }

  /// Create a new session
  Future<VideoSessionModel> createSession({
    required String title,
    bool isVoiceOnly = false,
  }) async {
    try {
      debugPrint(
        '[SocialsRepository] createSession -> title: $title, voiceOnly: $isVoiceOnly',
      );

      // Get current user info
      final userInfo = await _getCurrentUserInfo();
      debugPrint(
        '[SocialsRepository] Creating session as: ${userInfo['name']} (${userInfo['id']})',
      );

      final result = await _client.socials.createSession(
        title,
        userInfo['id']!,
        userInfo['name']!,
        null, // hostAvatarUrl - can be added later
        isVoiceOnly,
      );

      debugPrint('[SocialsRepository] Created session: ${result.id}');
      return _convertToModel(result);
    } catch (e) {
      debugPrint('[SocialsRepository] createSession error -> $e');
      rethrow;
    }
  }

  /// Join a session
  Future<bool> joinSession(String sessionId) async {
    try {
      debugPrint('[SocialsRepository] joinSession -> $sessionId');

      final sessionIdInt = int.tryParse(sessionId);
      if (sessionIdInt == null) {
        debugPrint('[SocialsRepository] Invalid session ID format');
        return false;
      }

      final success = await _client.socials.joinSession(sessionIdInt);
      debugPrint('[SocialsRepository] Join session result: $success');
      return success;
    } catch (e) {
      debugPrint('[SocialsRepository] joinSession error -> $e');
      return false;
    }
  }

  /// Leave a session
  Future<void> leaveSession(String sessionId) async {
    try {
      debugPrint('[SocialsRepository] leaveSession -> $sessionId');

      final sessionIdInt = int.tryParse(sessionId);
      if (sessionIdInt == null) {
        debugPrint('[SocialsRepository] Invalid session ID format');
        return;
      }

      await _client.socials.leaveSession(sessionIdInt);
      debugPrint('[SocialsRepository] Left session successfully');
    } catch (e) {
      debugPrint('[SocialsRepository] leaveSession error -> $e');
      rethrow;
    }
  }

  /// Get session details
  Future<VideoSessionModel?> getSession(String sessionId) async {
    try {
      debugPrint('[SocialsRepository] getSession -> $sessionId');

      final sessionIdInt = int.tryParse(sessionId);
      if (sessionIdInt == null) {
        debugPrint('[SocialsRepository] Invalid session ID format');
        return null;
      }

      final result = await _client.socials.getSession(sessionIdInt);
      if (result == null) {
        debugPrint('[SocialsRepository] Session not found');
        return null;
      }

      return _convertToModel(result);
    } catch (e) {
      debugPrint('[SocialsRepository] getSession error -> $e');
      return null;
    }
  }

  /// Get Agora credentials for WebRTC
  Future<Map<String, String>> getAgoraCredentials(
    String sessionId,
    int userId,
  ) async {
    try {
      debugPrint(
        '[SocialsRepository] getAgoraCredentials -> sessionId: $sessionId, userId: $userId',
      );

      final credentials = await _client.socials.getAgoraCredentials(
        sessionId,
        userId,
      );

      debugPrint(
        '[SocialsRepository] Got Agora credentials: ${credentials['appId']}',
      );
      return credentials;
    } catch (e) {
      debugPrint('[SocialsRepository] getAgoraCredentials error -> $e');
      rethrow;
    }
  }

  /// Create a scheduled session
  Future<ScheduledSession> createScheduledSession({
    required String title,
    required DateTime scheduledTime,
    bool isVoiceOnly = false,
    String? description,
  }) async {
    try {
      debugPrint(
        '[SocialsRepository] createScheduledSession -> title: $title, time: $scheduledTime',
      );
      final userInfo = await _getCurrentUserInfo();
      final result = await _client.socials.createScheduledSession(
        title,
        userInfo['id']!,
        userInfo['name']!,
        null, // hostAvatarUrl
        scheduledTime,
        description,
        isVoiceOnly,
      );
      debugPrint(
        '[SocialsRepository] Scheduled session created: ${result.id}',
      );
      return result;
    } catch (e) {
      debugPrint('[SocialsRepository] createScheduledSession error -> $e');
      rethrow;
    }
  }

  /// Get upcoming scheduled sessions for the current user
  Future<List<ScheduledSession>> getUpcomingScheduledSessions() async {
    try {
      debugPrint('[SocialsRepository] getUpcomingScheduledSessions');
      final userInfo = await _getCurrentUserInfo();
      return await _client.socials.getUpcomingScheduledSessions(
        userInfo['id']!,
      );
    } catch (e) {
      debugPrint('[SocialsRepository] getUpcomingScheduledSessions error -> $e');
      return [];
    }
  }

  /// Convert Serverpod VideoSession to local VideoSessionModel
  VideoSessionModel _convertToModel(VideoSession session) {
    return VideoSessionModel(
      id: session.id.toString(),
      hostId: session.hostId,
      hostName: session.hostName,
      hostAvatarUrl: session.hostAvatarUrl,
      title: session.title,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
      participantCount: session.participantCount,
      isVideoEnabled: session.isVideoEnabled,
      isVoiceOnly: session.isVoiceOnly,
      isActive: session.isActive,
    );
  }

  // ==================== STORIES ====================

  /// Get all active stories
  Future<List<StoryModel>> getActiveStories() async {
    try {
      debugPrint('[SocialsRepository] getActiveStories');
      // ignore: avoid_dynamic_calls
      final stories =
          await (_client.socials as dynamic).getActiveStories() as List;
      return stories
          .map((s) => StoryModel.fromServerpod(s as serverpod.Story))
          .toList();
    } catch (e) {
      debugPrint('[SocialsRepository] getActiveStories error -> $e');
      return [];
    }
  }

  /// Get stories by user ID
  Future<List<StoryModel>> getUserStories(String userId) async {
    try {
      debugPrint('[SocialsRepository] getUserStories -> $userId');
      // ignore: avoid_dynamic_calls
      final stories =
          await (_client.socials as dynamic).getUserStories(userId) as List;
      return stories
          .map((s) => StoryModel.fromServerpod(s as serverpod.Story))
          .toList();
    } catch (e) {
      debugPrint('[SocialsRepository] getUserStories error -> $e');
      return [];
    }
  }

  /// Upload a story image and return its URL
  Future<String?> uploadStoryImage(File imageFile, String userId) async {
    try {
      debugPrint('[SocialsRepository] uploadStoryImage -> $userId');

      // Check file size (400KB limit for Serverpod endpoints)
      final fileSize = await imageFile.length();
      const maxDirectUploadSize = 400 * 1024; // 400KB

      if (fileSize > maxDirectUploadSize) {
        debugPrint(
          '[SocialsRepository] Image file exceeds 400KB limit: ${fileSize / 1024} KB',
        );
        throw Exception(
          'Image file exceeds 400KB limit. Please choose a smaller image.',
        );
      }

      // Read file bytes
      final bytes = await imageFile.readAsBytes();
      final byteData = ByteData.view(bytes.buffer);

      // Upload to server
      // ignore: avoid_dynamic_calls
      final imageUrl =
          await (_client.socials as dynamic).uploadStoryImage(byteData, userId)
              as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint(
          '[SocialsRepository] Image uploaded successfully: $imageUrl',
        );
      } else {
        debugPrint(
          '[SocialsRepository] WARNING: Upload returned null or empty URL',
        );
      }

      return imageUrl;
    } catch (e) {
      debugPrint('[SocialsRepository] uploadStoryImage error -> $e');
      rethrow;
    }
  }

  /// Create a new story
  Future<StoryModel?> createStory({
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required List<String> imageUrls,
  }) async {
    try {
      debugPrint(
        '[SocialsRepository] createStory -> $userName, ${imageUrls.length} images',
      );
      // ignore: avoid_dynamic_calls
      final story =
          await (_client.socials as dynamic).createStory(
                userId,
                userName,
                userAvatarUrl,
                imageUrls,
              )
              as serverpod.Story;
      return StoryModel.fromServerpod(story);
    } catch (e) {
      debugPrint('[SocialsRepository] createStory error -> $e');
      return null;
    }
  }

  /// View a story (increment view count)
  Future<void> viewStory(int storyId, String viewerId) async {
    try {
      debugPrint('[SocialsRepository] viewStory -> $storyId');
      // ignore: avoid_dynamic_calls
      await (_client.socials as dynamic).viewStory(storyId, viewerId);
    } catch (e) {
      debugPrint('[SocialsRepository] viewStory error -> $e');
    }
  }

  /// Delete a story
  Future<bool> deleteStory(int storyId, String userId) async {
    try {
      debugPrint('[SocialsRepository] deleteStory -> $storyId');
      // ignore: avoid_dynamic_calls
      return await (_client.socials as dynamic).deleteStory(storyId, userId)
          as bool;
    } catch (e) {
      debugPrint('[SocialsRepository] deleteStory error -> $e');
      return false;
    }
  }
}
