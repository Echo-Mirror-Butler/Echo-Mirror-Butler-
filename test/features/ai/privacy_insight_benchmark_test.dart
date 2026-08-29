import 'dart:convert';
import 'package:echomirror/features/ai/data/services/privacy_insight_pipeline.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PrivacyInsightPipeline pipeline;

  setUp(() {
    pipeline = PrivacyInsightPipeline();
  });

  group('Privacy-Preserving AI Insight Benchmark Suite', () {
    final baseDate = DateTime.utc(2026, 3, 1, 8, 30, 0);

    // Scenario 1: Consistent Morning Habit Builder
    final habitBuilderLogs = List.generate(7, (i) {
      final date = baseDate.add(Duration(days: i));
      return LogEntryModel(
        id: 'hb-$i',
        userId: 'user-builder',
        date: date,
        mood: 3 + (i ~/ 3), // 3, 3, 3, 4, 4, 4, 5
        habits: ['meditation', 'morning_walk', 'hydrate'],
        notes:
            'Morning mindfulness session on day $i felt peaceful and grounding.',
        createdAt: date,
      );
    });

    // Scenario 2: Work Stress & Recovery
    final stressRecoveryLogs = [
      LogEntryModel(
        id: 'sr-1',
        userId: 'user-stress',
        date: baseDate,
        mood: 4,
        habits: ['exercise'],
        notes: 'Good start to the week, got workout in.',
        createdAt: baseDate,
      ),
      LogEntryModel(
        id: 'sr-2',
        userId: 'user-stress',
        date: baseDate.add(const Duration(days: 1)),
        mood: 2,
        habits: [],
        notes: 'Overwhelmed with intense production bug and manager pressure.',
        createdAt: baseDate.add(const Duration(days: 1)),
      ),
      LogEntryModel(
        id: 'sr-3',
        userId: 'user-stress',
        date: baseDate.add(const Duration(days: 2)),
        mood: 1,
        habits: [],
        notes:
            'Exhausted and burned out from staying up until 2am fixing servers.',
        createdAt: baseDate.add(const Duration(days: 2)),
      ),
      LogEntryModel(
        id: 'sr-4',
        userId: 'user-stress',
        date: baseDate.add(const Duration(days: 3)),
        mood: 3,
        habits: ['hydrate', 'sleep'],
        notes: 'Took a break, slept 9 hours and feeling slightly better.',
        createdAt: baseDate.add(const Duration(days: 3)),
      ),
      LogEntryModel(
        id: 'sr-5',
        userId: 'user-stress',
        date: baseDate.add(const Duration(days: 4)),
        mood: 5,
        habits: ['exercise', 'friends'],
        notes: 'Relaxing weekend with friends outdoors, completely recharged!',
        createdAt: baseDate.add(const Duration(days: 4)),
      ),
    ];

    // Scenario 3: Declining Mood Needing Support
    final decliningLogs = List.generate(5, (i) {
      final date = baseDate.add(Duration(days: i));
      return LogEntryModel(
        id: 'dec-$i',
        userId: 'user-declining',
        date: date,
        mood: 5 - i, // 5, 4, 3, 2, 1
        habits: i < 2 ? ['gym', 'read'] : [],
        notes:
            'Feeling increasingly disconnected and unmotivated day by day ($i).',
        createdAt: date,
      );
    });

    test(
      'Benchmark 1: 100% Zero-Plaintext Leakage across all benchmark datasets',
      () {
        final datasets = [habitBuilderLogs, stressRecoveryLogs, decliningLogs];

        for (var idx = 0; idx < datasets.length; idx++) {
          final logs = datasets[idx];
          final payload = pipeline.buildPrivacyPayload(logs);
          final payloadJson = payload.toJson();

          // Strict verification
          final isLeakFree = pipeline.verifyZeroPlaintextLeakage(
            payloadJson,
            logs,
          );
          expect(
            isLeakFree,
            isTrue,
            reason: 'Dataset $idx failed privacy guarantee',
          );

          final serialized = jsonEncode(payloadJson);
          for (final log in logs) {
            if (log.notes != null && log.notes!.length > 10) {
              final testSnippet = log.notes!.substring(0, 10);
              expect(
                serialized.contains(testSnippet),
                isFalse,
                reason: 'Plaintext snippet "$testSnippet" leaked in payload',
              );
            }
          }
        }
      },
    );

    test('Benchmark 2: Trend trajectory & slope accuracy', () {
      final hbPayload = pipeline.buildPrivacyPayload(habitBuilderLogs);
      expect(hbPayload.moodTrend['direction'], equals('improving'));
      expect(hbPayload.moodTrend['slope'], greaterThan(0.0));

      final decPayload = pipeline.buildPrivacyPayload(decliningLogs);
      expect(decPayload.moodTrend['direction'], equals('declining'));
      expect(decPayload.moodTrend['slope'], lessThan(-0.5));
    });

    test('Benchmark 3: Habit-Mood correlation precision', () {
      final srPayload = pipeline.buildPrivacyPayload(stressRecoveryLogs);
      // Exercise and friends should show highest mood correlation in stress recovery
      final correlations = srPayload.habitMoodCorrelations;
      expect(correlations['exercise'], greaterThanOrEqualTo(4.0));
      expect(correlations['friends'], equals(5.0));
    });

    test('Benchmark 4: Latency & throughput under mobile budgets', () {
      final stopwatch = Stopwatch()..start();
      const iterations = 50;
      for (var i = 0; i < iterations; i++) {
        pipeline.buildPrivacyPayload(stressRecoveryLogs);
      }
      stopwatch.stop();

      final avgLatencyMs = stopwatch.elapsedMilliseconds / iterations;
      // Processing 5 logs + embedding + vector index + clustering + payload must be < 5ms
      expect(avgLatencyMs, lessThan(5.0));
    });
  });
}
