import 'package:echomirror/features/global_mirror/data/models/mood_pin_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoodPinModel', () {
    test('fromJson creates correct model', () {
      final now = DateTime.now();
      final json = {
        'id': 'pin-123',
        'sentiment': 'happy',
        'gridLat': 10.15,
        'gridLon': 20.25,
        'timestamp': now.toIso8601String(),
        'userId': 'user-789',
      };

      final model = MoodPinModel.fromJson(json);

      expect(model.id, 'pin-123');
      expect(model.sentiment, 'happy');
      expect(model.gridLat, 10.15);
      expect(model.gridLon, 20.25);
      expect(model.userId, 'user-789');
    });

    test('toJson returns correct map', () {
      final now = DateTime.now();
      final model = MoodPinModel(
        id: 'pin-1',
        sentiment: 'calm',
        gridLat: 5.0,
        gridLon: -5.0,
        timestamp: now,
        userId: 'u1',
      );

      final json = model.toJson();

      expect(json['id'], 'pin-1');
      expect(json['sentiment'], 'calm');
      expect(json['gridLat'], 5.0);
      expect(json['gridLon'], -5.0);
      expect(json['userId'], 'u1');
    });

    test('anonymizeCoordinate rounds to 0.1 precision', () {
      expect(MoodPinModel.anonymizeCoordinate(12.3456), 12.3);
      expect(MoodPinModel.anonymizeCoordinate(12.3556), 12.4);
    });

    test('copyWith updates fields correctly', () {
      final model = MoodPinModel(
        id: '1',
        sentiment: 'neutral',
        gridLat: 0.0,
        gridLon: 0.0,
        timestamp: DateTime.now(),
      );

      final updated = model.copyWith(sentiment: 'excited', userId: 'new-u');

      expect(updated.sentiment, 'excited');
      expect(updated.userId, 'new-u');
      expect(updated.id, '1');
    });
  });
}
