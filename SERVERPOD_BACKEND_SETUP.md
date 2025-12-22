# Serverpod Backend Setup for Global Mirror Feature

## 1. Add Models to protocol.yaml

Navigate to `../echomirror_server/echomirror_server/protocol/` and add these models:

```yaml
# protocol/mood_pin.yaml
class: MoodPin
table: mood_pins
fields:
  sentiment: String
  gridLat: double
  gridLon: double
  timestamp: DateTime
  expiresAt: DateTime?
indexes:
  timestamp_idx:
    fields: timestamp
  expires_idx:
    fields: expiresAt

# protocol/video_post.yaml
class: VideoPost
table: video_posts
fields:
  videoUrl: String
  moodTag: String
  timestamp: DateTime
  expiresAt: DateTime
indexes:
  timestamp_idx:
    fields: timestamp DESC
  expires_idx:
    fields: expiresAt
```

## 2. Create Global Endpoint

Create `../echomirror_server/echomirror_server/lib/src/endpoints/global_endpoint.dart`:

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
  Future<bool> addMoodPin(
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
      
      await MoodPin.db.insertRow(session, pin);
      return true;
    } catch (e) {
      session.log('Error adding mood pin: $e');
      return false;
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
      final videoUrl = session.storage.getPublicUrl(
        storageId: 'public',
        path: 'videos/$filename',
      );
      
      // Create video post
      final post = VideoPost(
        videoUrl: videoUrl ?? '',
        moodTag: moodTag,
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(hours: 24)),
      );
      
      await VideoPost.db.insertRow(session, post);
      return videoUrl;
    } catch (e) {
      session.log('Error uploading video: $e');
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
      
      return posts;
    } catch (e) {
      session.log('Error getting video feed: $e');
      return [];
    }
  }
}
```

## 3. Add Scheduled Task for Cleanup

Create `../echomirror_server/echomirror_server/lib/src/tasks/cleanup_task.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class CleanupTask {
  static void register(Serverpod server) {
    // Run cleanup every hour
    server.addPeriodicTask(
      name: 'cleanup-expired-content',
      schedule: '0 * * * *', // Every hour at minute 0
      task: (Session session) async {
        await cleanupExpiredContent(session);
      },
    );
  }

  static Future<void> cleanupExpiredContent(Session session) async {
    try {
      final now = DateTime.now();
      
      // Delete expired mood pins
      final expiredPins = await MoodPin.db.find(
        session,
        where: (t) => t.expiresAt < now,
      );
      
      for (final pin in expiredPins) {
        await MoodPin.db.deleteRow(session, pin);
      }
      
      // Delete expired video posts and files
      final expiredPosts = await VideoPost.db.find(
        session,
        where: (t) => t.expiresAt < now,
      );
      
      for (final post in expiredPosts) {
        // Delete file from storage
        try {
          final path = post.videoUrl.split('/videos/').last;
          await session.storage.deleteFile(
            storageId: 'public',
            path: 'videos/$path',
          );
        } catch (e) {
          session.log('Error deleting video file: $e');
        }
        
        // Delete database entry
        await VideoPost.db.deleteRow(session, post);
      }
      
      session.log('Cleanup completed: ${expiredPins.length} pins, ${expiredPosts.length} videos deleted');
    } catch (e) {
      session.log('Error in cleanup task: $e');
    }
  }
}
```

## 4. Register Endpoint and Task

In `../echomirror_server/echomirror_server/lib/src/server.dart`, add:

```dart
import 'endpoints/global_endpoint.dart';
import 'tasks/cleanup_task.dart';

// In the server initialization:
@override
void initialize() {
  super.initialize();
  
  // Register the cleanup task
  CleanupTask.register(this);
}
```

## 5. Generate and Deploy

```bash
cd ../echomirror_server/echomirror_server
serverpod generate
cd ../echomirror_server_client
flutter pub get
cd ../../echomirror
flutter pub get
```

## 6. Database Migration

After generation, create and run migration:

```bash
cd ../echomirror_server/echomirror_server
serverpod create-migration
serverpod run-migration --mode production
```

## Notes

- **Privacy**: Coordinates are rounded to 0.1 degrees (~11km) for anonymity
- **Expiration**: Content auto-expires after 24 hours
- **Storage**: Videos stored in Serverpod's public file storage
- **No User IDs**: All data is anonymous, no user linking
