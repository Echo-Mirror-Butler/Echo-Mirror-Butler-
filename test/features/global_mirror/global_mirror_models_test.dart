import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/features/global_mirror/data/models/video_post_model.dart';
import 'package:echomirror/features/global_mirror/data/models/mood_pin_comment_model.dart';

void main() {
  group('VideoPostModel', () {
    final now = DateTime.utc(2026, 3, 25, 12, 0, 0);
    final expires = now.add(const Duration(hours: 24));

    test('fromJson creates correct model', () {
      final json = {
        'id': 'v1',
        'videoUrl': 'https://example.com/video.mp4',
        'moodTag': 'happy',
        'timestamp': now.toIso8601String(),
        'expiresAt': expires.toIso8601String(),
      };

      final model = VideoPostModel.fromJson(json);

      expect(model.id, 'v1');
      expect(model.videoUrl, 'https://example.com/video.mp4');
      expect(model.moodTag, 'happy');
      expect(model.timestamp, now);
      expect(model.expiresAt, expires);
    });

    test('isImage identifies image URLs', () {
      final img = VideoPostModel(
        id: '1',
        videoUrl: 'test.jpg',
        moodTag: 'tag',
        timestamp: now,
        expiresAt: expires,
      );
      expect(img.isImage, isTrue);
      expect(img.isVideo, isFalse);
    });

    test('isImage identifies video URLs', () {
      final vid = VideoPostModel(
        id: '1',
        videoUrl: 'test.mp4',
        moodTag: 'tag',
        timestamp: now,
        expiresAt: expires,
      );
      expect(vid.isImage, isFalse);
      expect(vid.isVideo, isTrue);
    });
  });

  group('MoodPinCommentModel', () {
    final now = DateTime.utc(2026, 3, 25, 12, 0, 0);

    test('fromJson creates correct model', () {
      final json = {
        'id': 'c1',
        'moodPinId': 'p1',
        'text': 'Test comment',
        'timestamp': now.toIso8601String(),
        'userId': 'u1',
      };

      final model = MoodPinCommentModel.fromJson(json);

      expect(model.id, 'c1');
      expect(model.moodPinId, 'p1');
      expect(model.text, 'Test comment');
      expect(model.timestamp, now);
      expect(model.userId, 'u1');
    });

    test('toJson returns correct map', () {
      final model = MoodPinCommentModel(
        id: 'c1',
        moodPinId: 'p1',
        text: 'Test',
        timestamp: now,
      );

      final json = model.toJson();

      expect(json['id'], 'c1');
      expect(json['text'], 'Test');
    });
  });
}
