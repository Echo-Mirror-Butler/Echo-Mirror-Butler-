# Socials Endpoint Setup Guide

## Status
✅ VideoSession YAML model created (`lib/src/video_session.yaml`)
✅ SocialsEndpoint created (`lib/src/endpoints/socials_endpoint.dart`)
⏳ Need to fix endpoint syntax errors and regenerate

## Steps to Complete

### 1. Fix Endpoint Syntax
The endpoint file needs to be fixed. The issue is likely with:
- Named parameters (Serverpod endpoints should use positional parameters)
- Const declarations in methods

### 2. Generate Serverpod Code
```bash
cd /Users/macbookpro/echomirror_server/echomirror_server_server
serverpod generate
```

### 3. Create Database Migration
```bash
serverpod create-migration
serverpod run-migration --mode development
```

### 4. Update Flutter Repository
Update `lib/features/socials/data/repositories/socials_repository.dart` to use the actual endpoints:

```dart
// Replace mock implementations with:
final results = await _client.socials.getActiveSessions();

final result = await _client.socials.createSession(
  title: title,
  hostId: userId,
  hostName: userName,
  hostAvatarUrl: null,
  isVoiceOnly: isVoiceOnly,
);
```

## Endpoint Methods

The `SocialsEndpoint` provides:
- `getActiveSessions()` - Get all active video sessions
- `createSession()` - Create a new session
- `joinSession(sessionId)` - Join a session
- `leaveSession(sessionId)` - Leave a session
- `getSession(sessionId)` - Get session details
- `getSignalingServerUrl()` - Get WebRTC signaling URL
- `endSession(sessionId, hostId)` - End session (host only)

## Next Steps

1. Fix syntax errors in `socials_endpoint.dart`
2. Run `serverpod generate`
3. Create and run migration
4. Update Flutter app to use real endpoints
5. Set up WebRTC signaling server

