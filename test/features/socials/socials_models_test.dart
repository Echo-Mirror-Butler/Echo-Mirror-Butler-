import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/features/socials/data/models/video_session_model.dart';

void main() {
  group('VideoSessionModel', () {
    final now = DateTime.utc(2026, 3, 25, 12, 0, 0);
    
    final map = {
      'id': 'session-1',
      'hostId': 'user-1',
      'hostName': 'Host Name',
      'hostAvatarUrl': 'https://example.com/avatar.png',
      'title': 'Test Session',
      'createdAt': now.toIso8601String(),
      'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
      'participantCount': 5,
      'isVideoEnabled': true,
      'isVoiceOnly': false,
      'isActive': true,
    };

    test('fromJson creates correct model', () {
      final model = VideoSessionModel.fromJson(map);
      
      expect(model.id, 'session-1');
      expect(model.hostId, 'user-1');
      expect(model.hostName, 'Host Name');
      expect(model.hostAvatarUrl, 'https://example.com/avatar.png');
      expect(model.title, 'Test Session');
      expect(model.createdAt, now);
      expect(model.expiresAt, now.add(const Duration(hours: 1)));
      expect(model.participantCount, 5);
      expect(model.isVideoEnabled, true);
      expect(model.isVoiceOnly, false);
      expect(model.isActive, true);
    });

    test('toJson returns correct map', () {
      final model = VideoSessionModel(
        id: 'session-1',
        hostId: 'user-1',
        hostName: 'Host Name',
        hostAvatarUrl: 'https://example.com/avatar.png',
        title: 'Test Session',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        participantCount: 5,
        isVideoEnabled: true,
        isVoiceOnly: false,
        isActive: true,
      );

      final result = model.toJson();
      
      expect(result['id'], 'session-1');
      expect(result['hostId'], 'user-1');
      expect(result['createdAt'], now.toIso8601String());
    });

    test('copyWith updates fields correctly', () {
      final model = VideoSessionModel(
        id: 'session-1',
        hostId: 'user-1',
        hostName: 'Host Name',
        title: 'Original',
        createdAt: now,
        participantCount: 0,
        isActive: true,
      );

      final updated = model.copyWith(title: 'Updated', participantCount: 10);
      
      expect(updated.title, 'Updated');
      expect(updated.participantCount, 10);
      expect(updated.id, 'session-1');
    });
  });
}
