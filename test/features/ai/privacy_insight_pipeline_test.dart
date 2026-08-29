import 'dart:convert';
import 'package:echomirror/features/ai/data/services/privacy_insight_pipeline.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PrivacyInsightPipeline pipeline;

  setUp(() {
    pipeline = PrivacyInsightPipeline();
  });

  group('PrivacyInsightPipeline', () {
    final baseTime = DateTime.utc(2026, 3, 10, 9, 0, 0);

    List<LogEntryModel> sampleLogs = [
      LogEntryModel(
        id: 'log-1',
        userId: 'user-abc',
        date: baseTime,
        mood: 3,
        habits: ['hydrate'],
        notes:
            'Secret note about my personal private medical issues and work frustration',
        createdAt: baseTime,
      ),
      LogEntryModel(
        id: 'log-2',
        userId: 'user-abc',
        date: baseTime.add(const Duration(days: 1)),
        mood: 4,
        habits: ['meditate', 'hydrate'],
        notes:
            'Feeling calmer after 15 minutes of deep breathing in the morning',
        createdAt: baseTime.add(const Duration(days: 1)),
      ),
      LogEntryModel(
        id: 'log-3',
        userId: 'user-abc',
        date: baseTime.add(const Duration(days: 2)),
        mood: 5,
        habits: ['meditate', 'exercise'],
        notes: 'Super energetic and happy! Finished the key milestone at work',
        createdAt: baseTime.add(const Duration(days: 2)),
      ),
    ];

    test('builds privacy payload with valid numerical trends and clusters', () {
      final payload = pipeline.buildPrivacyPayload(
        sampleLogs,
        previousFollowThroughRate: {'acted': 3, 'total': 4},
      );

      expect(payload.privacyMode, isTrue);
      expect(payload.logCount, equals(3));
      expect(
        payload.previousFollowThroughRate,
        equals({'acted': 3, 'total': 4}),
      );

      // Mood trends
      expect(payload.moodTrend['average'], equals(4.0));
      expect(payload.moodTrend['min'], equals(3));
      expect(payload.moodTrend['max'], equals(5));
      expect(payload.moodTrend['direction'], equals('improving'));
      expect(payload.moodTrend['slope'], greaterThan(0.0));

      // Habit frequencies
      expect(payload.habitFrequencies['hydrate'], equals(2));
      expect(payload.habitFrequencies['meditate'], equals(2));
      expect(payload.habitFrequencies['exercise'], equals(1));

      // Habit-mood correlations
      expect(payload.habitMoodCorrelations['exercise'], equals(5.0));
      expect(payload.habitMoodCorrelations['meditate'], equals(4.5));

      // Sanitized logs
      expect(payload.sanitizedLogs.length, equals(3));
      for (final logMap in payload.sanitizedLogs) {
        expect(logMap.containsKey('noteEmbedding'), isTrue);
        expect((logMap['noteEmbedding'] as List).length, equals(64));
        // Verify 'notes' key is completely absent
        expect(logMap.containsKey('notes'), isFalse);
      }
    });

    test('strict zero-plaintext verification passes for sanitized payload', () {
      final payload = pipeline.buildPrivacyPayload(sampleLogs);
      final payloadJson = payload.toJson();

      final zeroLeak = pipeline.verifyZeroPlaintextLeakage(
        payloadJson,
        sampleLogs,
      );
      expect(zeroLeak, isTrue);

      final rawSerialized = jsonEncode(payloadJson);
      // Ensure none of the private text strings exist anywhere in the payload
      expect(rawSerialized.contains('medical issues'), isFalse);
      expect(rawSerialized.contains('work frustration'), isFalse);
      expect(rawSerialized.contains('deep breathing'), isFalse);
      expect(rawSerialized.contains('Super energetic'), isFalse);
      expect(rawSerialized.contains('key milestone'), isFalse);
    });

    test(
      'detects plaintext leak when sensitive text is inadvertently injected',
      () {
        final payload = pipeline.buildPrivacyPayload(sampleLogs);
        final corruptedJson = payload.toJson();
        // Inject leak
        corruptedJson['leak'] = 'medical issues and work frustration';

        final leakDetected = pipeline.verifyZeroPlaintextLeakage(
          corruptedJson,
          sampleLogs,
        );
        expect(leakDetected, isFalse);
      },
    );
  });
}
