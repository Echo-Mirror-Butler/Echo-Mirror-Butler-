import 'dart:async';
import 'dart:typed_data';
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class GlobalEndpoint extends Endpoint {
  int? _getUserId(Session session) {
    final userIdentifier = session.authenticated?.userIdentifier;
    if (userIdentifier == null) return null;
    return userIdentifier.hashCode.abs();
  }
  /// Stream mood pins in real-time
  Stream<List<MoodPin>> streamMoodPins(Session session) async* {
    // Initial fetch
    var pins = await _getActiveMoodPins(session);
    yield pins;

    // Stream updates every 5 seconds
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      pins = await _getActiveMoodPins(session);
      yield pins;
    }
  }

  Future<List<MoodPin>> _getActiveMoodPins(Session session) async {
    final now = DateTime.now();
    return await MoodPin.db.find(
      session,
      where: (t) => t.expiresAt > now,
      orderBy: (t) => t.timestamp,
      orderDescending: true,
      limit: 100,
    );
  }

  /// Add a mood pin with anonymized location
  Future<int?> addMoodPin(
    Session session,
    String sentiment,
    double latitude,
    double longitude,
  ) async {
    // Anonymize coordinates to ~1km grid
    final gridLat = (latitude * 100).round() / 100.0;
    final gridLon = (longitude * 100).round() / 100.0;

    final userId = _getUserId(session);

    final pin = MoodPin(
      sentiment: sentiment,
      gridLat: gridLat,
      gridLon: gridLon,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      userId: userId,
    );

    final inserted = await MoodPin.db.insertRow(session, pin);

    // Award ECHO for sharing mood
    if (userId != null) {
      await _awardEchoForAction(session, userId, 2.0, 'mood_pin');
    }

    return inserted.id;
  }

  /// Upload video and create post
  Future<String?> uploadVideo(
    Session session,
    ByteData videoData,
    String moodTag,
  ) async {
    final userId = _getUserId(session);

    // Store video (in production, use cloud storage)
    final bytes = videoData.buffer.asUint8List();
    final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    // For now, store as base64 in database (not ideal for production)
    // In production, use Serverpod's file storage or S3
    final videoUrl = 'local://$fileName';

    final post = VideoPost(
      videoUrl: videoUrl,
      moodTag: moodTag,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      userId: userId,
    );

    await VideoPost.db.insertRow(session, post);

    // Award ECHO for posting video
    if (userId != null) {
      await _awardEchoForAction(session, userId, 5.0, 'video_post');
    }

    return videoUrl;
  }

  /// Upload image and create post
  Future<String?> uploadImage(
    Session session,
    ByteData imageData,
    String moodTag,
  ) async {
    final userId = _getUserId(session);

    final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final imageUrl = 'local://$fileName';

    final post = VideoPost(
      videoUrl: imageUrl,
      moodTag: moodTag,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      userId: userId,
    );

    await VideoPost.db.insertRow(session, post);

    // Award ECHO for posting image
    if (userId != null) {
      await _awardEchoForAction(session, userId, 2.0, 'image_post');
    }

    return imageUrl;
  }

  /// Get video feed (paginated)
  Future<List<VideoPost>> getVideoFeed(
    Session session,
    int offset,
    int limit,
  ) async {
    final now = DateTime.now();
    return await VideoPost.db.find(
      session,
      where: (t) => t.expiresAt > now,
      orderBy: (t) => t.timestamp,
      orderDescending: true,
      offset: offset,
      limit: limit,
    );
  }

  /// Add a comment to a mood pin
  Future<int?> addComment(
    Session session,
    int moodPinId,
    String text,
  ) async {
    final userId = _getUserId(session);

    final comment = MoodPinComment(
      moodPinId: moodPinId,
      text: text,
      timestamp: DateTime.now(),
      userId: userId,
    );

    final inserted = await MoodPinComment.db.insertRow(session, comment);

    // Award ECHO to pin owner for receiving comment
    final pin = await MoodPin.db.findById(session, moodPinId);
    if (pin?.userId != null && pin!.userId != userId) {
      await _awardEchoForAction(session, pin.userId!, 1.0, 'comment_received');
    }

    return inserted.id;
  }

  /// Get comments for a mood pin
  Future<List<MoodPinComment>> getCommentsForPin(
    Session session,
    int moodPinId,
  ) async {
    return await MoodPinComment.db.find(
      session,
      where: (t) => t.moodPinId.equals(moodPinId),
      orderBy: (t) => t.timestamp,
      orderDescending: true,
    );
  }

  /// Generate cluster encouragement message
  Future<String> generateClusterEncouragement(
    Session session,
    String sentiment,
    int nearbyCount,
  ) async {
    // Simple encouragement messages based on sentiment
    final messages = {
      'positive': 'Great energy in your area! $nearbyCount others are feeling upbeat too.',
      'negative': 'You\'re not alone—$nearbyCount others nearby understand. Many found short walks or deep breathing helped today.',
      'neutral': '$nearbyCount others nearby are taking it easy. Sometimes neutral is perfectly okay.',
      'excited': 'The excitement is contagious! $nearbyCount others are feeling the same energy.',
      'calm': 'A peaceful moment shared by $nearbyCount others in your area.',
      'anxious': 'Take a breath—$nearbyCount others nearby are working through similar feelings. You\'ve got this.',
    };

    return messages[sentiment] ?? 
        'Others nearby are feeling similar—many found short walks or deep breathing helped today.';
  }

  /// Helper to award ECHO for actions
  Future<void> _awardEchoForAction(
    Session session,
    int userId,
    double amount,
    String reason,
  ) async {
    var wallet = await EchoWallet.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );

    if (wallet == null) {
      wallet = EchoWallet(
        userId: userId,
        balance: 10.0 + amount,
        createdAt: DateTime.now(),
      );
      await EchoWallet.db.insertRow(session, wallet);
    } else {
      wallet = wallet.copyWith(balance: wallet.balance + amount);
      await EchoWallet.db.updateRow(session, wallet);
    }
  }
}
