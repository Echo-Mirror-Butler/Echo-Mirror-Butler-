import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

/// Global Mirror endpoint for anonymous mood sharing and videos
class GlobalEndpoint extends Endpoint {
  /// Stream mood pins in real-time (every 5 seconds)
  Stream<List<MoodPin>> streamMoodPins(Session session) async* {
    while (true) {
      try {
        // Get recent mood pins (last 24 hours)
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        final pins = await MoodPin.db.find(
          session,
          where: (t) => t.timestamp > cutoff,
          orderBy: (t) => t.timestamp,
          orderDescending: true,
          limit: 1000,
        );

        yield pins;
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        session.log('Error streaming mood pins: $e');
        yield [];
      }
    }
  }

  /// Add a new mood pin (anonymized)
  /// Returns the pin ID if successful, null otherwise
  Future<int?> addMoodPin(
    Session session,
    String sentiment,
    double latitude,
    double longitude,
  ) async {
    try {
      // Anonymize: round to 0.1 degrees (~11km precision)
      final gridLat = (latitude * 10).round() / 10;
      final gridLon = (longitude * 10).round() / 10;

      final pin = MoodPin(
        sentiment: sentiment,
        gridLat: gridLat,
        gridLon: gridLon,
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      final insertedPin = await MoodPin.db.insertRow(session, pin);

      session.log(
        'Added mood pin: $sentiment at ($gridLat, $gridLon) with ID ${insertedPin.id}',
      );
      return insertedPin.id;
    } catch (e) {
      session.log('Error adding mood pin: $e');
      return null;
    }
  }

  /// Upload video and create post
  Future<String?> uploadVideo(
    Session session,
    ByteData videoData,
    String moodTag,
  ) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'mood_video_$timestamp.mp4';

      // Upload to Serverpod file storage
      final bytes = videoData.buffer.asUint8List();
      await session.storage.storeFile(
        storageId: 'public',
        path: 'videos/$filename',
        byteData: ByteData.view(bytes.buffer),
      );

      // Get public URL
      final videoUrlUri = await session.storage.getPublicUrl(
        storageId: 'public',
        path: 'videos/$filename',
      );

      if (videoUrlUri == null) {
        session.log('Error: Could not generate public URL for video');
        return null;
      }

      final videoUrl = videoUrlUri.toString();

      // Create video post
      final post = VideoPost(
        videoUrl: videoUrl,
        moodTag: moodTag,
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await VideoPost.db.insertRow(session, post);
      session.log('Uploaded video: $moodTag, URL: $videoUrl');
      return videoUrl;
    } catch (e) {
      session.log('Error uploading video: $e');
      return null;
    }
  }

  /// Upload image and create post
  Future<String?> uploadImage(
    Session session,
    ByteData imageData,
    String moodTag,
  ) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'mood_image_$timestamp.jpg';

      // Upload to Serverpod file storage
      final bytes = imageData.buffer.asUint8List();
      await session.storage.storeFile(
        storageId: 'public',
        path: 'images/$filename',
        byteData: ByteData.view(bytes.buffer),
      );

      // Get public URL
      final imageUrlUri = await session.storage.getPublicUrl(
        storageId: 'public',
        path: 'images/$filename',
      );

      if (imageUrlUri == null) {
        session.log('Error: Could not generate public URL for image');
        return null;
      }

      final imageUrl = imageUrlUri.toString();

      // Create video post (reusing VideoPost model for images too)
      final post = VideoPost(
        videoUrl: imageUrl, // Store image URL in videoUrl field
        moodTag: moodTag,
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await VideoPost.db.insertRow(session, post);
      session.log('Uploaded image: $moodTag, URL: $imageUrl');
      return imageUrl;
    } catch (e) {
      session.log('Error uploading image: $e');
      return null;
    }
  }

  /// Get video feed (paginated)
  Future<List<VideoPost>> getVideoFeed(
    Session session,
    int offset,
    int limit,
  ) async {
    try {
      final now = DateTime.now();
      final posts = await VideoPost.db.find(
        session,
        where: (t) => t.expiresAt > now,
        orderBy: (t) => t.timestamp,
        orderDescending: true,
        offset: offset,
        limit: limit,
      );

      session.log(
        'Retrieved ${posts.length} videos (offset: $offset, limit: $limit)',
      );
      return posts;
    } catch (e) {
      session.log('Error getting video feed: $e');
      return [];
    }
  }

  /// Get mood statistics for analytics (optional)
  Future<Map<String, int>> getMoodStatistics(Session session) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final pins = await MoodPin.db.find(
        session,
        where: (t) => t.timestamp > cutoff,
      );

      // Count by sentiment
      final stats = <String, int>{};
      for (final pin in pins) {
        stats[pin.sentiment] = (stats[pin.sentiment] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      session.log('Error getting mood statistics: $e');
      return {};
    }
  }

  /// Add a comment to a mood pin
  /// Returns comment ID if successful, null otherwise
  /// For now, comments are anonymous (userId is optional)
  Future<int?> addComment(Session session, int moodPinId, String text) async {
    try {
      final comment = MoodPinComment(
        moodPinId: moodPinId,
        userId: null, // Anonymous for now
        text: text,
        timestamp: DateTime.now(),
      );

      final insertedComment = await MoodPinComment.db.insertRow(
        session,
        comment,
      );
      session.log('Added comment to mood pin $moodPinId: $text');
      return insertedComment.id;
    } catch (e) {
      session.log('Error adding comment: $e');
      return null;
    }
  }

  /// Get comments for a mood pin
  Future<List<MoodPinComment>> getCommentsForPin(
    Session session,
    int moodPinId,
  ) async {
    try {
      final comments = await MoodPinComment.db.find(
        session,
        where: (t) => t.moodPinId.equals(moodPinId),
        orderBy: (t) => t.timestamp,
        orderDescending: true,
        limit: 100,
      );

      session.log(
        'Retrieved ${comments.length} comments for mood pin $moodPinId',
      );
      return comments;
    } catch (e) {
      session.log('Error getting comments: $e');
      return [];
    }
  }

  /// Get notifications for a specific user (by userId parameter)
  /// Note: For now, notifications are disabled as comments are anonymous
  /// This endpoint is prepared for future authentication implementation
  Future<List<MoodCommentNotification>> getNotifications(
    Session session,
    int userId,
  ) async {
    try {
      final notifications = await MoodCommentNotification.db.find(
        session,
        where: (t) => t.userId.equals(userId),
        orderBy: (t) => t.timestamp,
        orderDescending: true,
        limit: 100,
      );

      session.log(
        'Retrieved ${notifications.length} notifications for user $userId',
      );
      return notifications;
    } catch (e) {
      session.log('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  /// Note: For future authentication implementation
  Future<bool> markNotificationAsRead(
    Session session,
    int notificationId,
  ) async {
    try {
      final notification = await MoodCommentNotification.db.findById(
        session,
        notificationId,
      );
      if (notification == null) {
        session.log('Notification not found: $notificationId');
        return false;
      }

      final updated = notification.copyWith(isRead: true);
      await MoodCommentNotification.db.updateRow(session, updated);
      session.log('Marked notification $notificationId as read');
      return true;
    } catch (e) {
      session.log('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read for a user
  /// Note: For future authentication implementation
  Future<bool> markAllNotificationsAsRead(Session session, int userId) async {
    try {
      final notifications = await MoodCommentNotification.db.find(
        session,
        where: (t) => t.userId.equals(userId) & t.isRead.equals(false),
      );

      for (final notification in notifications) {
        final updated = notification.copyWith(isRead: true);
        await MoodCommentNotification.db.updateRow(session, updated);
      }

      session.log(
        'Marked ${notifications.length} notifications as read for user $userId',
      );
      return true;
    } catch (e) {
      session.log('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a notification
  /// Note: For future authentication implementation
  Future<bool> deleteNotification(Session session, int notificationId) async {
    try {
      final notification = await MoodCommentNotification.db.findById(
        session,
        notificationId,
      );
      if (notification == null) {
        session.log('Notification not found: $notificationId');
        return false;
      }

      await MoodCommentNotification.db.deleteRow(session, notification);
      session.log('Deleted notification $notificationId');
      return true;
    } catch (e) {
      session.log('Error deleting notification: $e');
      return false;
    }
  }

  /// Generate cluster encouragement message for Global Mirror mood clusters
  ///
  /// Creates a short, supportive message when users tap on mood clusters
  Future<String> generateClusterEncouragement(
    Session session,
    String sentiment,
    int nearbyCount,
  ) async {
    try {
      final apiKey = Platform.environment['GEMINI_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        session.log(
          '[GlobalEndpoint] GEMINI_API_KEY not found, using fallback message',
        );
        return 'Others nearby are feeling similar—many found short walks or deep breathing helped today.';
      }

      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
      );

      final prompt =
          '''
You are the collective voice of others nearby who are feeling $sentiment.
Generate a short, encouraging message (30-50 words) that:
- Acknowledges shared feelings in a warm, supportive way
- Mentions what helped others (walks, breathing, etc.)
- Feels supportive and non-intrusive
- Speaks as a collective "we" or "others nearby"
- Avoids being preachy or overly optimistic

Example: "Others nearby are feeling similar—many found short walks or deep breathing helped today. You're not alone in this."

Respond with ONLY the message text, no JSON, no quotes, just the message.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final message =
          response.text?.trim() ??
          'Others nearby are feeling similar—many found short walks or deep breathing helped today.';

      session.log('[GlobalEndpoint] Generated cluster encouragement: $message');
      return message;
    } catch (e) {
      session.log(
        '[GlobalEndpoint] Error generating cluster encouragement: $e',
      );
      // Fallback message
      return 'Others nearby are feeling similar—many found short walks or deep breathing helped today.';
    }
  }
}
