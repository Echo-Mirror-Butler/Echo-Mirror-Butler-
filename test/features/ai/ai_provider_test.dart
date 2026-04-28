import 'package:echomirror/features/ai/data/models/ai_insight_model.dart';
import 'package:echomirror/features/ai/data/repositories/ai_repository.dart';
import 'package:echomirror/features/ai/viewmodel/providers/ai_provider.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake AiRepository for testing
class FakeAiRepository extends AiRepository {
  AiInsightModel? generatedInsight;
  Exception? throwException;
  bool generateInsightCalled = false;
  List<LogEntryModel>? lastLogs;

  FakeAiRepository() : super();

  @override
  Future<AiInsightModel> generateInsight(
    List<LogEntryModel> recentLogs,
  ) async {
    generateInsightCalled = true;
    lastLogs = recentLogs;

    if (throwException != null) {
      throw throwException!;
    }

    if (generatedInsight != null) {
      return generatedInsight!;
    }

    return AiInsightModel(
      prediction:
          'Test prediction based on your logs. You have been consistent with meditation and exercise. If you continue this pattern for one month, you will see significant improvements in your mood and overall well-being. Your dedication to daily habits is paying off.',
      suggestions: [
        'Try adding a morning gratitude practice to boost your mood even further',
        'Consider journaling before bed to reflect on your progress',
      ],
      futureLetter:
          'Hey! It is me, your future self writing from one month ahead. I remember when you logged that tough day on March 15th where your mood was 2/5, but you still did your exercise habit. That consistency paid off - look at you now! I am so proud of how far you have come. Your mood scores have improved from 3/5 to 4/5 on average.',
      generatedAt: DateTime.now(),
      stressLevel: 2,
      calmingMessage: 'Take a deep breath',
      musicRecommendations: ['Relaxing piano', 'Nature sounds'],
    );
  }
}

void main() {
  const testUserId = '123e4567-e89b-12d3-a456-426614174000';
  final testDate = DateTime.utc(2026, 3, 25, 12, 0, 0);

  LogEntryModel buildLogEntry({
    String id = 'log-1',
    int? mood = 4,
    List<String> habits = const ['meditate', 'exercise'],
    String? notes = 'Feeling great today',
  }) {
    return LogEntryModel(
      id: id,
      userId: testUserId,
      date: testDate,
      mood: mood,
      habits: habits,
      notes: notes,
      createdAt: testDate,
    );
  }

  AiInsightModel buildTestInsight() {
    return AiInsightModel(
      prediction:
          'Test prediction based on your logs. You have been consistent with meditation and exercise. If you continue this pattern for one month, you will see significant improvements in your mood and overall well-being.',
      suggestions: ['Try adding morning gratitude', 'Consider journaling'],
      futureLetter:
          'Hey! It is me, your future self. I remember when you logged that tough day. That consistency paid off - look at you now! I am so proud of how far you have come.',
      generatedAt: DateTime.now(),
    );
  }

  group('AiInsightNotifier', () {
    late FakeAiRepository fakeRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeRepository = FakeAiRepository();
    });

    test('starts with null state and loads cached insight if available', () async {
      final cachedInsight = buildTestInsight();
      final cachedJson = cachedInsight.toJson();
      cachedJson.remove('generatedAt');

      SharedPreferences.setMockInitialValues({
        'cached_ai_insight': cachedInsight.toJson().toString(),
      });

      final notifier = AiInsightNotifier(fakeRepository);

      // Wait for async cache load
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state, isA<AsyncData<AiInsightModel?>>());
      expect(notifier.cachedInsight, isNotNull);
    });

    test('starts with null state when no cache exists', () async {
      SharedPreferences.setMockInitialValues({});

      final notifier = AiInsightNotifier(fakeRepository);

      // Give time for potential async load
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state, isA<AsyncData<AiInsightModel?>>());
    });

    test('generateInsight success - calls repo and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AiInsightNotifier(fakeRepository);

      final logs = [
        buildLogEntry(),
        buildLogEntry(id: 'log-2', mood: 5, habits: ['read']),
        buildLogEntry(id: 'log-3', mood: 3, habits: ['meditate']),
      ];

      await notifier.generateInsight(logs);

      expect(fakeRepository.generateInsightCalled, isTrue);
      expect(notifier.state, isA<AsyncData<AiInsightModel?>>());
      expect(notifier.cachedInsight, isNotNull);
    });

    test('generateInsight with fewer than 3 logs returns null state', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AiInsightNotifier(fakeRepository);

      final logs = [
        buildLogEntry(),
        buildLogEntry(id: 'log-2'),
      ];

      await notifier.generateInsight(logs);

      expect(fakeRepository.generateInsightCalled, isFalse);
      expect(notifier.state, equals(const AsyncValue<AiInsightModel?>.data(null)));
    });

    test('generateInsight error - state becomes AsyncError', () async {
      SharedPreferences.setMockInitialValues({});
      fakeRepository.throwException = Exception('API Error');
      final notifier = AiInsightNotifier(fakeRepository);

      final logs = [
        buildLogEntry(),
        buildLogEntry(id: 'log-2', mood: 5),
        buildLogEntry(id: 'log-3', mood: 3),
      ];

      await notifier.generateInsight(logs);

      expect(notifier.state, isA<AsyncError>());
    });

    test('generateInsight error with cached insight restores cache', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AiInsightNotifier(fakeRepository);

      // First, generate a successful insight
      final logs = [
        buildLogEntry(),
        buildLogEntry(id: 'log-2', mood: 5),
        buildLogEntry(id: 'log-3', mood: 3),
      ];

      await notifier.generateInsight(logs);
      expect(notifier.cachedInsight, isNotNull);

      // Now cause an error
      fakeRepository.throwException = Exception('API Error');
      fakeRepository.generateInsightCalled = false;

      await notifier.generateInsight(logs);

      // Should restore cached insight, not error
      expect(notifier.state, isA<AsyncData<AiInsightModel?>>());
    });

    test('clearInsight clears state and removes from cache', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AiInsightNotifier(fakeRepository);

      // First generate an insight
      final logs = [
        buildLogEntry(),
        buildLogEntry(id: 'log-2', mood: 5),
        buildLogEntry(id: 'log-3', mood: 3),
      ];

      await notifier.generateInsight(logs);
      expect(notifier.cachedInsight, isNotNull);

      // Clear insight
      notifier.clearInsight();

      expect(notifier.cachedInsight, isNull);
      expect(notifier.state, equals(const AsyncValue<AiInsightModel?>.data(null)));

      // Verify cache was cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_ai_insight'), isNull);
    });
  });
}
