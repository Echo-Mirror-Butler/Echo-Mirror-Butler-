import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/features/ai/data/models/ai_insight_model.dart';

void main() {
  group('AiInsightModel', () {
    final now = DateTime.utc(2026, 3, 25, 12, 0, 0);

    final map = {
      'prediction': 'Test prediction',
      'suggestions': ['S1', 'S2'],
      'futureLetter': 'Test letter',
      'generatedAt': now.toIso8601String(),
      'stressLevel': 2,
      'calmingMessage': 'Stay calm',
      'musicRecommendations': ['Track 1', 'Track 2'],
    };

    test('fromJson creates correct model', () {
      final model = AiInsightModel.fromJson(map);

      expect(model.prediction, 'Test prediction');
      expect(model.suggestions, ['S1', 'S2']);
      expect(model.futureLetter, 'Test letter');
      expect(model.generatedAt, now);
      expect(model.stressLevel, 2);
      expect(model.calmingMessage, 'Stay calm');
      expect(model.musicRecommendations, ['Track 1', 'Track 2']);
    });

    test('fromJson handles null optional fields', () {
      final minimalMap = {
        'prediction': 'P',
        'suggestions': null,
        'futureLetter': 'L',
        'generatedAt': null,
      };
      
      final model = AiInsightModel.fromJson(minimalMap);
      
      expect(model.suggestions, isEmpty);
      expect(model.stressLevel, isNull);
    });

    test('toJson returns correct map', () {
      final model = AiInsightModel(
        prediction: 'P',
        suggestions: ['S'],
        futureLetter: 'L',
        generatedAt: now,
        stressLevel: 1,
      );

      final result = model.toJson();

      expect(result['prediction'], 'P');
      expect(result['suggestions'], ['S']);
      expect(result['generatedAt'], now.toIso8601String());
    });

    test('copyWith updates fields correctly', () {
      final model = AiInsightModel(
        prediction: 'Old',
        suggestions: [],
        futureLetter: 'L',
        generatedAt: now,
      );

      final updated = model.copyWith(prediction: 'New', stressLevel: 3);

      expect(updated.prediction, 'New');
      expect(updated.stressLevel, 3);
      expect(updated.futureLetter, 'L');
    });
  });
}
