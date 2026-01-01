# Serverpod Video Sessions Setup

This document outlines the Serverpod endpoints needed for the video call/socials feature.

## Required Serverpod Endpoints

### 1. Video Session Management

Create a new endpoint file: `server/lib/src/endpoints/socials_endpoint.dart`

```dart
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class SocialsEndpoint extends Endpoint {
  /// Get all active video sessions
  Future<List<VideoSession>> getActiveSessions(Session session) async {
    // Query database for active sessions
    // Return sessions that are not expired and have participants
    return await VideoSession.db.find(
      session,
      where: (t) => t.isActive.equals(true) & 
                    t.expiresAt.isGreaterThan(DateTime.now()),
      orderBy: (t) => t.createdAt,
      orderDescending: true,
    );
  }

  /// Create a new video session
  Future<VideoSession> createSession(
    Session session, {
    required String title,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    bool isVoiceOnly = false,
  }) async {
    final videoSession = VideoSession(
      hostId: hostId,
      hostName: hostName,
      hostAvatarUrl: hostAvatarUrl,
      title: title,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(hours: 1)),
      participantCount: 1,
      isVideoEnabled: !isVoiceOnly,
      isVoiceOnly: isVoiceOnly,
      isActive: true,
    );

    return await VideoSession.db.insertRow(session, videoSession);
  }

  /// Join a video session
  Future<bool> joinSession(Session session, String sessionId) async {
    final videoSession = await VideoSession.db.findById(session, sessionId);
    if (videoSession == null || !videoSession.isActive) {
      return false;
    }

    // Increment participant count
    videoSession.participantCount++;
    await VideoSession.db.updateRow(session, videoSession);
    return true;
  }

  /// Leave a video session
  Future<void> leaveSession(Session session, String sessionId) async {
    final videoSession = await VideoSession.db.findById(session, sessionId);
    if (videoSession != null) {
      videoSession.participantCount = (videoSession.participantCount - 1).clamp(0, double.infinity).toInt();
      
      // If no participants left, end the session
      if (videoSession.participantCount == 0) {
        videoSession.isActive = false;
      }
      
      await VideoSession.db.updateRow(session, videoSession);
    }
  }

  /// Get session details
  Future<VideoSession?> getSession(Session session, String sessionId) async {
    return await VideoSession.db.findById(session, sessionId);
  }

  /// Get WebRTC signaling server URL
  Future<String> getSignalingServerUrl(Session session) async {
    // Return your WebRTC signaling server URL
    // This could be a WebSocket server or TURN/STUN server
    return 'wss://your-signaling-server.com';
  }
}
```

### 2. Database Model

Create a new protocol file: `server/lib/src/protocol/video_session.yaml`

```yaml
class: VideoSession
table: video_sessions
fields:
  id:
    type: int
    databaseType: bigInteger
  hostId:
    type: String
    databaseType: text
  hostName:
    type: String
    databaseType: text
  hostAvatarUrl:
    type: String?
    databaseType: text
    nullable: true
  title:
    type: String
    databaseType: text
  createdAt:
    type: DateTime
    databaseType: timestamp without time zone
  expiresAt:
    type: DateTime
    databaseType: timestamp without time zone
  participantCount:
    type: int
    databaseType: integer
  isVideoEnabled:
    type: bool
    databaseType: boolean
  isVoiceOnly:
    type: bool
    databaseType: boolean
  isActive:
    type: bool
    databaseType: boolean
```

### 3. WebRTC Signaling Server

You'll need to set up a WebRTC signaling server. Options:

1. **Simple WebSocket Server** - Use Serverpod's WebSocket support
2. **Janus Gateway** - Production-ready WebRTC server
3. **Kurento** - Media server for WebRTC
4. **Custom Node.js Server** - Using `socket.io` or `ws`

### 4. Update Client Repository

After generating the Serverpod client, update `lib/features/socials/data/repositories/socials_repository.dart`:

```dart
// Replace mock implementations with:
final results = await _client.socials.getActiveSessions();
final result = await _client.socials.createSession(
  title: title,
  hostId: userId,
  hostName: userName,
  isVoiceOnly: isVoiceOnly,
);
```

## Next Steps

1. Run `serverpod generate` to generate the client code
2. Deploy the Serverpod server
3. Set up WebRTC signaling server
4. Update the Flutter app to use the generated endpoints
5. Complete WebRTC integration in `video_call_screen.dart`

