import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

/// Cleanup task for expired Global Mirror content
class CleanupTask extends FutureCall {
  @override
  String get name => 'cleanup-expired-content';

  @override
  Future<void> invoke(Session session, SerializableModel? data) async {
    await cleanupExpiredContent(session);

    // Re-schedule the task to run again in 1 hour
    await session.serverpod.futureCallWithDelay(
      'cleanup-expired-content',
      null,
      const Duration(hours: 1),
    );
  }

  /// Register the cleanup task to run hourly
  static void register(Serverpod server) {
    // Register the future call - parameter order: FutureCall, then name
    final task = CleanupTask();
    server.registerFutureCall(task, task.name);
  }

  /// Start the periodic cleanup task
  static Future<void> start(Session session) async {
    // Schedule the first cleanup to run in 1 hour
    await session.serverpod.futureCallWithDelay(
      'cleanup-expired-content',
      null,
      const Duration(hours: 1),
    );
  }

  /// Clean up expired mood pins and video posts
  static Future<void> cleanupExpiredContent(Session session) async {
    try {
      final now = DateTime.now();
      int deletedPins = 0;
      int deletedComments = 0;
      int deletedUserPins = 0;
      int deletedNotifications = 0;
      int deletedVideos = 0;

      // Delete expired mood pins and related data
      final expiredPins = await MoodPin.db.find(
        session,
        where: (t) => t.expiresAt < now,
      );

      for (final pin in expiredPins) {
        if (pin.id != null) {
          // Delete related comments
          final comments = await MoodPinComment.db.find(
            session,
            where: (t) => t.moodPinId.equals(pin.id!),
          );
          for (final comment in comments) {
            await MoodPinComment.db.deleteRow(session, comment);
            deletedComments++;
          }

          // Delete related user mood pins
          final userPins = await UserMoodPin.db.find(
            session,
            where: (t) => t.moodPinId.equals(pin.id!),
          );
          for (final userPin in userPins) {
            await UserMoodPin.db.deleteRow(session, userPin);
            deletedUserPins++;
          }

          // Delete related notifications
          final notifications = await MoodCommentNotification.db.find(
            session,
            where: (t) => t.moodPinId.equals(pin.id!),
          );
          for (final notification in notifications) {
            await MoodCommentNotification.db.deleteRow(session, notification);
            deletedNotifications++;
          }
        }

        await MoodPin.db.deleteRow(session, pin);
        deletedPins++;
      }

      // Delete expired video posts and files
      final expiredPosts = await VideoPost.db.find(
        session,
        where: (t) => t.expiresAt < now,
      );

      for (final post in expiredPosts) {
        // Delete file from storage
        try {
          // Extract path from URL (assumes format: .../videos/filename.mp4)
          final uri = Uri.parse(post.videoUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length >= 2 &&
              pathSegments[pathSegments.length - 2] == 'videos') {
            final filename = pathSegments.last;
            await session.storage.deleteFile(
              storageId: 'public',
              path: 'videos/$filename',
            );
          }
        } catch (e) {
          session.log('Error deleting video file: $e');
        }

        // Delete database entry
        await VideoPost.db.deleteRow(session, post);
        deletedVideos++;
      }

      session.log(
        'Cleanup completed: $deletedPins mood pins, $deletedComments comments, '
        '$deletedUserPins user pins, $deletedNotifications notifications, '
        'and $deletedVideos videos deleted',
      );
    } catch (e) {
      session.log('Error in cleanup task: $e');
    }
  }
}
