# Serverpod Setup for Mood Pin Comments and Notifications

## 1. Add Models to protocol.yaml

Navigate to `../echomirror_server/echomirror_server/protocol/` and add these models:

```yaml
# protocol/mood_pin_comment.yaml
class: MoodPinComment
table: mood_pin_comments
fields:
  moodPinId: int
  userId: int?
  text: String
  timestamp: DateTime
indexes:
  mood_pin_idx:
    fields: moodPinId
  user_idx:
    fields: userId
  timestamp_idx:
    fields: timestamp DESC

# protocol/user_mood_pin.yaml
class: UserMoodPin
table: user_mood_pins
fields:
  userId: int
  moodPinId: int
  createdAt: DateTime
indexes:
  user_idx:
    fields: userId
  mood_pin_idx:
    fields: moodPinId
  unique_user_pin:
    unique: true
    fields:
      - userId
      - moodPinId

# protocol/mood_comment_notification.yaml
class: MoodCommentNotification
table: mood_comment_notifications
fields:
  userId: int
  moodPinId: int
  commentId: int
  commentText: String
  sentiment: String
  timestamp: DateTime
  isRead: bool
indexes:
  user_idx:
    fields: userId
  unread_idx:
    fields:
      - userId
      - isRead
  timestamp_idx:
    fields: timestamp DESC
```

## 2. Update Global Endpoint

Update `../echomirror_server/echomirror_server/lib/src/endpoints/global_endpoint.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class GlobalEndpoint extends Endpoint {
  /// Stream mood pins in real-time (every 5 seconds)
  Stream<List<MoodPin>> streamMoodPins(Session session) async* {
    while (true) {
      try {
        // Get recent mood pins (last 24 hours)
        final cutoff = DateTime.now().subtract(Duration(hours: 24));
        final pins = await MoodPin.db.find(
          session,
          where: (t) => t.timestamp > cutoff,
          orderBy: (t) => t.timestamp,
          orderDescending: true,
          limit: 1000,
        );
        
        yield pins;
        await Future.delayed(Duration(seconds: 5));
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
        expiresAt: DateTime.now().add(Duration(hours: 24)),
      );
      
      final insertedPin = await MoodPin.db.insertRow(session, pin);
      
      // If user is authenticated, store the pin ID for them
      final userId = session.authKey?.userId;
      if (userId != null && insertedPin.id != null) {
        try {
          final userMoodPin = UserMoodPin(
            userId: userId,
            moodPinId: insertedPin.id!,
            createdAt: DateTime.now(),
          );
          await UserMoodPin.db.insertRow(session, userMoodPin);
        } catch (e) {
          // Ignore duplicate errors (user might have multiple pins at same location)
          session.log('Note: Could not store user mood pin: $e');
        }
      }
      
      return insertedPin.id;
    } catch (e) {
      session.log('Error adding mood pin: $e');
      return null;
    }
  }

  /// Add a comment to a mood pin
  Future<int?> addComment(
    Session session,
    int moodPinId,
    String text,
  ) async {
    try {
      final userId = session.authKey?.userId;
      
      final comment = MoodPinComment(
        moodPinId: moodPinId,
        userId: userId,
        text: text,
        timestamp: DateTime.now(),
      );
      
      final insertedComment = await MoodPinComment.db.insertRow(session, comment);
      
      // Check if this mood pin belongs to a user and create notification
      if (insertedComment.id != null) {
        final userMoodPins = await UserMoodPin.db.find(
          session,
          where: (t) => t.moodPinId.equals(moodPinId),
        );
        
        // Get the mood pin to get its sentiment
        final moodPin = await MoodPin.db.findById(session, moodPinId);
        
        if (moodPin != null) {
          // Create notifications for all users who own this pin
          for (final userPin in userMoodPins) {
            // Don't notify if the commenter is the owner
            if (userPin.userId != userId) {
              final notification = MoodCommentNotification(
                userId: userPin.userId,
                moodPinId: moodPinId,
                commentId: insertedComment.id!,
                commentText: text,
                sentiment: moodPin.sentiment,
                timestamp: DateTime.now(),
                isRead: false,
              );
              await MoodCommentNotification.db.insertRow(session, notification);
            }
          }
        }
      }
      
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
      
      return comments;
    } catch (e) {
      session.log('Error getting comments: $e');
      return [];
    }
  }

  /// Get notifications for the current user
  Future<List<MoodCommentNotification>> getNotifications(
    Session session,
  ) async {
    try {
      final userId = session.authKey?.userId;
      if (userId == null) return [];
      
      final notifications = await MoodCommentNotification.db.find(
        session,
        where: (t) => t.userId.equals(userId),
        orderBy: (t) => t.timestamp,
        orderDescending: true,
        limit: 100,
      );
      
      return notifications;
    } catch (e) {
      session.log('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(
    Session session,
    int notificationId,
  ) async {
    try {
      final userId = session.authKey?.userId;
      if (userId == null) return false;
      
      final notification = await MoodCommentNotification.db.findById(session, notificationId);
      if (notification == null || notification.userId != userId) {
        return false;
      }
      
      final updated = notification.copyWith(isRead: true);
      await MoodCommentNotification.db.updateRow(session, updated);
      return true;
    } catch (e) {
      session.log('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead(Session session) async {
    try {
      final userId = session.authKey?.userId;
      if (userId == null) return false;
      
      final notifications = await MoodCommentNotification.db.find(
        session,
        where: (t) => t.userId.equals(userId) & t.isRead.equals(false),
      );
      
      for (final notification in notifications) {
        final updated = notification.copyWith(isRead: true);
        await MoodCommentNotification.db.updateRow(session, updated);
      }
      
      return true;
    } catch (e) {
      session.log('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(
    Session session,
    int notificationId,
  ) async {
    try {
      final userId = session.authKey?.userId;
      if (userId == null) return false;
      
      final notification = await MoodCommentNotification.db.findById(session, notificationId);
      if (notification == null || notification.userId != userId) {
        return false;
      }
      
      await MoodCommentNotification.db.deleteRow(session, notification);
      return true;
    } catch (e) {
      session.log('Error deleting notification: $e');
      return false;
    }
  }

  /// Upload video and create post
  Future<String?> uploadVideo(
    Session session,
    ByteData videoData,
    String moodTag,
  ) async {
    // ... existing implementation ...
  }

  /// Get video feed (paginated)
  Future<List<VideoPost>> getVideoFeed(
    Session session,
    int offset,
    int limit,
  ) async {
    // ... existing implementation ...
  }
}
```

## 3. Update Cleanup Task

Update `../echomirror_server/echomirror_server/lib/src/tasks/cleanup_task.dart` to also clean up comments and notifications:

```dart
static Future<void> cleanupExpiredContent(Session session) async {
  try {
    final now = DateTime.now();
    
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
        }
        
        // Delete related user mood pins
        final userPins = await UserMoodPin.db.find(
          session,
          where: (t) => t.moodPinId.equals(pin.id!),
        );
        for (final userPin in userPins) {
          await UserMoodPin.db.deleteRow(session, userPin);
        }
        
        // Delete related notifications
        final notifications = await MoodCommentNotification.db.find(
          session,
          where: (t) => t.moodPinId.equals(pin.id!),
        );
        for (final notification in notifications) {
          await MoodCommentNotification.db.deleteRow(session, notification);
        }
      }
      
      await MoodPin.db.deleteRow(session, pin);
    }
    
    // ... rest of cleanup for videos ...
    
    session.log('Cleanup completed: ${expiredPins.length} pins deleted');
  } catch (e) {
    session.log('Error in cleanup task: $e');
  }
}
```

## 4. Generate and Deploy

```bash
cd ../echomirror_server/echomirror_server
serverpod generate
cd ../echomirror_server_client
flutter pub get
cd ../../echomirror
flutter pub get
```

## 5. Database Migration

```bash
cd ../echomirror_server/echomirror_server
serverpod create-migration
serverpod run-migration --mode production
```

