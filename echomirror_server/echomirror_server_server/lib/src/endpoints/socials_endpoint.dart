import 'dart:typed_data';
import 'package:serverpod/serverpod.dart';
import 'package:agora_token_service/agora_token_service.dart';
import '../generated/protocol.dart';

/// Socials endpoint for video/voice call sessions
class SocialsEndpoint extends Endpoint {
  // Agora credentials
  static const String _agoraAppId = 'eccb4923605644c89d00aa2bd9e3c10c';
  static const String _agoraAppCertificate = 'dc3ce665edcb48a581cb665bf1c61ab7';

  /// Token expiration time (24 hours)
  static const int _tokenExpirationInSeconds = 24 * 3600;

  /// Get all active video sessions
  Future<List<VideoSession>> getActiveSessions(Session session) async {
    try {
      final sessions = await VideoSession.db.find(
        session,
        where: (t) => t.isActive.equals(true),
        orderBy: (t) => t.createdAt,
        orderDescending: true,
        limit: 50,
      );
      session.log('Found ${sessions.length} active video sessions');
      return sessions;
    } catch (e) {
      session.log('Error getting active sessions: $e');
      return [];
    }
  }

  /// Create a new video session
  Future<VideoSession> createSession(
    Session session,
    String title,
    String hostId,
    String hostName,
    String? hostAvatarUrl,
    bool isVoiceOnly,
  ) async {
    try {
      final videoSession = VideoSession(
        hostId: hostId,
        hostName: hostName,
        hostAvatarUrl: hostAvatarUrl,
        title: title,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        participantCount: 1,
        isVideoEnabled: !isVoiceOnly,
        isVoiceOnly: isVoiceOnly,
        isActive: true,
      );
      final insertedSession = await VideoSession.db.insertRow(
        session,
        videoSession,
      );
      session.log(
        'Created video session: "$title" by $hostName (ID: ${insertedSession.id})',
      );
      return insertedSession;
    } catch (e) {
      session.log('Error creating video session: $e');
      rethrow;
    }
  }

  /// Join a video session
  Future<bool> joinSession(Session session, int sessionId) async {
    try {
      final videoSession = await VideoSession.db.findById(session, sessionId);
      if (videoSession == null || !videoSession.isActive) return false;
      final now = DateTime.now();
      if (videoSession.expiresAt.isBefore(now)) {
        videoSession.isActive = false;
        await VideoSession.db.updateRow(session, videoSession);
        return false;
      }
      videoSession.participantCount = videoSession.participantCount + 1;
      await VideoSession.db.updateRow(session, videoSession);
      return true;
    } catch (e) {
      session.log('Error joining session: $e');
      return false;
    }
  }

  /// Leave a video session
  Future<void> leaveSession(Session session, int sessionId) async {
    try {
      final videoSession = await VideoSession.db.findById(session, sessionId);
      if (videoSession == null) return;
      videoSession.participantCount = (videoSession.participantCount - 1)
          .clamp(0, double.infinity)
          .toInt();
      if (videoSession.participantCount == 0) {
        videoSession.isActive = false;
      }
      await VideoSession.db.updateRow(session, videoSession);
    } catch (e) {
      session.log('Error leaving session: $e');
      rethrow;
    }
  }

  /// Get session details by ID
  Future<VideoSession?> getSession(Session session, int sessionId) async {
    try {
      final videoSession = await VideoSession.db.findById(session, sessionId);
      if (videoSession != null && !videoSession.isActive) return null;
      final now = DateTime.now();
      if (videoSession != null && videoSession.expiresAt.isBefore(now)) {
        videoSession.isActive = false;
        await VideoSession.db.updateRow(session, videoSession);
        return null;
      }
      return videoSession;
    } catch (e) {
      session.log('Error getting session: $e');
      return null;
    }
  }

  /// Get Agora credentials for WebRTC with token generation
  Future<Map<String, String>> getAgoraCredentials(
    Session session,
    String channelName,
    int userId,
  ) async {
    try {
      session.log(
        'Generating Agora token for channel: $channelName, uid: $userId',
      );

      // Generate RTC token
      final token = RtcTokenBuilder.build(
        appId: _agoraAppId,
        appCertificate: _agoraAppCertificate,
        channelName: channelName,
        uid: userId.toString(),
        role: RtcRole
            .publisher, // Publisher role allows both sending and receiving
        expireTimestamp:
            DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            _tokenExpirationInSeconds,
      );

      session.log('✅ Generated Agora token successfully');

      return {
        'appId': _agoraAppId,
        'token': token,
        'channelName': channelName,
        'uid': userId.toString(),
      };
    } catch (e) {
      session.log('❌ Error generating Agora token: $e');
      rethrow;
    }
  }

  /// End a session (host only)
  Future<bool> endSession(Session session, int sessionId, String hostId) async {
    try {
      final videoSession = await VideoSession.db.findById(session, sessionId);
      if (videoSession == null || videoSession.hostId != hostId) return false;
      videoSession.isActive = false;
      await VideoSession.db.updateRow(session, videoSession);
      return true;
    } catch (e) {
      session.log('Error ending session: $e');
      return false;
    }
  }

  // ===== SCHEDULED SESSIONS =====

  /// Create a scheduled session
  Future<ScheduledSession> createScheduledSession(
    Session session,
    String title,
    String hostId,
    String hostName,
    String? hostAvatarUrl,
    DateTime scheduledTime,
    String? description,
    bool isVoiceOnly,
  ) async {
    try {
      final scheduledSession = ScheduledSession(
        hostId: hostId,
        hostName: hostName,
        hostAvatarUrl: hostAvatarUrl,
        title: title,
        description: description,
        scheduledTime: scheduledTime,
        createdAt: DateTime.now(),
        isVideoEnabled: !isVoiceOnly,
        isVoiceOnly: isVoiceOnly,
        isNotified: false,
        isCancelled: false,
      );
      final inserted = await ScheduledSession.db.insertRow(
        session,
        scheduledSession,
      );
      session.log(
        'Created scheduled session: "$title" at ${scheduledTime.toIso8601String()}',
      );
      return inserted;
    } catch (e) {
      session.log('Error creating scheduled session: $e');
      rethrow;
    }
  }

  /// Get upcoming scheduled sessions for a user
  Future<List<ScheduledSession>> getUpcomingScheduledSessions(
    Session session,
    String userId,
  ) async {
    try {
      final now = DateTime.now();
      final allSessions = await ScheduledSession.db.find(
        session,
        where: (t) => t.hostId.equals(userId) & t.isCancelled.equals(false),
        orderBy: (t) => t.scheduledTime,
        limit: 100,
      );
      // Filter in memory for date comparison
      final upcomingSessions = allSessions
          .where((s) => s.scheduledTime.isAfter(now))
          .toList();
      session.log(
        'Found ${upcomingSessions.length} upcoming scheduled sessions for user $userId',
      );
      return upcomingSessions;
    } catch (e) {
      session.log('Error getting upcoming scheduled sessions: $e');
      return [];
    }
  }

  /// Get all upcoming public scheduled sessions
  Future<List<ScheduledSession>> getAllUpcomingScheduledSessions(
    Session session,
  ) async {
    try {
      final now = DateTime.now();
      final allSessions = await ScheduledSession.db.find(
        session,
        where: (t) => t.isCancelled.equals(false),
        orderBy: (t) => t.scheduledTime,
        limit: 100,
      );
      // Filter in memory for date comparison
      final upcomingSessions = allSessions
          .where((s) => s.scheduledTime.isAfter(now))
          .toList();
      session.log(
        'Found ${upcomingSessions.length} upcoming scheduled sessions',
      );
      return upcomingSessions;
    } catch (e) {
      session.log('Error getting all upcoming scheduled sessions: $e');
      return [];
    }
  }

  /// Cancel a scheduled session
  Future<bool> cancelScheduledSession(
    Session session,
    int sessionId,
    String userId,
  ) async {
    try {
      final scheduledSession = await ScheduledSession.db.findById(
        session,
        sessionId,
      );
      if (scheduledSession == null || scheduledSession.hostId != userId)
        return false;
      scheduledSession.isCancelled = true;
      await ScheduledSession.db.updateRow(session, scheduledSession);
      session.log('Cancelled scheduled session: $sessionId');
      return true;
    } catch (e) {
      session.log('Error cancelling scheduled session: $e');
      return false;
    }
  }

  /// Start a scheduled session (converts to active session)
  Future<VideoSession?> startScheduledSession(
    Session session,
    int scheduledSessionId,
    String userId,
  ) async {
    try {
      final scheduledSession = await ScheduledSession.db.findById(
        session,
        scheduledSessionId,
      );
      if (scheduledSession == null ||
          scheduledSession.hostId != userId ||
          scheduledSession.isCancelled) {
        return null;
      }

      // Create the active video session
      final videoSession = await createSession(
        session,
        scheduledSession.title,
        scheduledSession.hostId,
        scheduledSession.hostName,
        scheduledSession.hostAvatarUrl,
        scheduledSession.isVoiceOnly,
      );

      // Link the scheduled session to the active session
      scheduledSession.actualSessionId = videoSession.id.toString();
      await ScheduledSession.db.updateRow(session, scheduledSession);

      session.log(
        'Started scheduled session: $scheduledSessionId -> active session: ${videoSession.id}',
      );
      return videoSession;
    } catch (e) {
      session.log('Error starting scheduled session: $e');
      return null;
    }
  }

  /// Get sessions that need notifications (within 10 minutes, not yet notified)
  Future<List<ScheduledSession>> getSessionsNeedingNotification(
    Session session,
  ) async {
    try {
      final now = DateTime.now();
      final notificationWindow = now.add(const Duration(minutes: 10));

      final allSessions = await ScheduledSession.db.find(
        session,
        where: (t) => t.isNotified.equals(false) & t.isCancelled.equals(false),
      );

      // Filter in memory for date comparisons
      final sessionsNeedingNotification = allSessions
          .where(
            (s) =>
                s.scheduledTime.isAfter(now) &&
                s.scheduledTime.isBefore(notificationWindow),
          )
          .toList();

      session.log(
        'Found ${sessionsNeedingNotification.length} sessions needing notification',
      );
      return sessionsNeedingNotification;
    } catch (e) {
      session.log('Error getting sessions needing notification: $e');
      return [];
    }
  }

  /// Mark session as notified
  Future<bool> markSessionAsNotified(Session session, int sessionId) async {
    try {
      final scheduledSession = await ScheduledSession.db.findById(
        session,
        sessionId,
      );
      if (scheduledSession == null) return false;

      scheduledSession.isNotified = true;
      await ScheduledSession.db.updateRow(session, scheduledSession);
      session.log('Marked session as notified: $sessionId');
      return true;
    } catch (e) {
      session.log('Error marking session as notified: $e');
      return false;
    }
  }

  // ==================== STORIES ====================

  /// Upload a story image and return its public URL
  Future<String?> uploadStoryImage(
    Session session,
    ByteData imageData,
    String userId,
  ) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'story_${userId}_$timestamp.jpg';

      // Upload to Serverpod file storage
      final bytes = imageData.buffer.asUint8List();
      await session.storage.storeFile(
        storageId: 'public',
        path: 'stories/$filename',
        byteData: ByteData.view(bytes.buffer),
      );

      // Get public URL
      final imageUrlUri = await session.storage.getPublicUrl(
        storageId: 'public',
        path: 'stories/$filename',
      );

      if (imageUrlUri == null) {
        session.log('Error: Could not generate public URL for story image');
        return null;
      }

      final imageUrl = imageUrlUri.toString();
      session.log('Uploaded story image: $imageUrl');
      return imageUrl;
    } catch (e) {
      session.log('Error uploading story image: $e');
      return null;
    }
  }

  /// Create a new story
  Future<Story> createStory(
    Session session,
    String userId,
    String userName,
    String? userAvatarUrl,
    List<String> imageUrls,
  ) async {
    try {
      final story = Story(
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        viewCount: 0,
        viewedBy: [],
        isActive: true,
      );

      final insertedStory = await Story.db.insertRow(session, story);
      session.log(
        'Created story for user: $userName (ID: ${insertedStory.id})',
      );
      return insertedStory;
    } catch (e) {
      session.log('Error creating story: $e');
      rethrow;
    }
  }

  /// Get all active stories (not expired)
  Future<List<Story>> getActiveStories(Session session) async {
    try {
      final stories = await Story.db.find(
        session,
        where: (t) => t.isActive.equals(true),
        orderBy: (t) => t.createdAt,
        orderDescending: true,
      );

      // Filter expired stories in memory
      final now = DateTime.now();
      final activeStories = stories
          .where((s) => s.expiresAt.isAfter(now))
          .toList();

      session.log('Found ${activeStories.length} active stories');
      return activeStories;
    } catch (e) {
      session.log('Error getting active stories: $e');
      return [];
    }
  }

  /// Get stories by user ID
  Future<List<Story>> getUserStories(Session session, String userId) async {
    try {
      final stories = await Story.db.find(
        session,
        where: (t) => t.userId.equals(userId) & t.isActive.equals(true),
        orderBy: (t) => t.createdAt,
        orderDescending: true,
      );

      // Filter expired stories in memory
      final now = DateTime.now();
      final activeStories = stories
          .where((s) => s.expiresAt.isAfter(now))
          .toList();

      session.log('Found ${activeStories.length} stories for user: $userId');
      return activeStories;
    } catch (e) {
      session.log('Error getting user stories: $e');
      return [];
    }
  }

  /// View a story (increment view count and add viewer)
  Future<void> viewStory(Session session, int storyId, String viewerId) async {
    try {
      final story = await Story.db.findById(session, storyId);
      if (story == null) {
        session.log('Story not found: $storyId');
        return;
      }

      // Add viewer if not already viewed
      if (!story.viewedBy.contains(viewerId)) {
        story.viewedBy.add(viewerId);
        story.viewCount = story.viewedBy.length;
        await Story.db.updateRow(session, story);
        session.log(
          'Story viewed by: $viewerId (Total views: ${story.viewCount})',
        );
      }
    } catch (e) {
      session.log('Error viewing story: $e');
    }
  }

  /// Delete a story
  Future<bool> deleteStory(Session session, int storyId, String userId) async {
    try {
      final story = await Story.db.findById(session, storyId);
      if (story == null || story.userId != userId) {
        session.log('Story not found or unauthorized: $storyId');
        return false;
      }

      story.isActive = false;
      await Story.db.updateRow(session, story);
      session.log('Deleted story: $storyId');
      return true;
    } catch (e) {
      session.log('Error deleting story: $e');
      return false;
    }
  }
}
