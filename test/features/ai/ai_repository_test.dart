import 'package:echomirror/features/ai/data/models/ai_insight_model.dart';
import 'package:echomirror/features/ai/data/repositories/ai_repository.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late AiRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockFunctionsClient mockFunctions;

  const userId = '123e4567-e89b-12d3-a456-426614174000';
  final now = DateTime.utc(2026, 3, 25, 12, 0, 0);

  LogEntryModel buildLogEntry({
    String id = 'log-1',
    int? mood = 4,
    List<String> habits = const ['meditate', 'exercise'],
    String? notes = 'Feeling great today',
  }) {
    return LogEntryModel(
      id: id,
      userId: userId,
      date: now,
      mood: mood,
      habits: habits,
      notes: notes,
      createdAt: now,
    );
  }

  Map<String, dynamic> buildInsightResponse({
    String prediction =
        'I noticed you have been consistently logging meditation every morning for the past week. Your mood scores have improved from 3/5 to 4/5. Your notes mention feeling more focused and energized. If you continue this pattern, in one month you will likely see even greater improvements in your overall well-being and productivity.',
    String futureLetter =
        'Hey! It is me, your future self writing from one month ahead. I remember when you logged that tough day on January 15th where your mood was 2/5, but you still did your exercise habit. That consistency paid off - look at you now! I am so proud of how far you have come.',
    List<String> suggestions = const [
      'Try adding a morning gratitude practice to boost your mood even further',
      'Consider journaling before bed to reflect on your progress',
    ],
    int stressLevel = 2,
  }) {
    return {
      'prediction': prediction,
      'futureLetter': futureLetter,
      'suggestions': suggestions,
      'stressLevel': stressLevel,
      'calmingMessage': 'Take a deep breath',
      'musicRecommendations': ['Relaxing piano', 'Nature sounds'],
    };
  }

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockFunctions = MockFunctionsClient();
    repository = AiRepository(client: mockSupabase);

    when(() => mockSupabase.functions).thenReturn(mockFunctions);
  });

  group('AiRepository', () {
    group('generateInsight', () {
      test('returns AiInsightModel on successful API call', () async {
        final logs = [
          buildLogEntry(),
          buildLogEntry(
            id: 'log-2',
            mood: 5,
            habits: const ['read'],
            notes: 'Good day',
          ),
        ];

        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async =>
              FunctionResponse(data: buildInsightResponse(), status: 200),
        );

        final result = await repository.generateInsight(logs);

        expect(result, isA<AiInsightModel>());
        expect(result.prediction, contains('meditation'));
        expect(result.suggestions, isNotEmpty);
        expect(result.futureLetter, isNotEmpty);
        expect(result.stressLevel, equals(2));
        expect(result.calmingMessage, equals('Take a deep breath'));
        expect(result.musicRecommendations, hasLength(2));
      });

      test(
        'throws exception when Gemini API returns empty prediction',
        () async {
          final logs = [buildLogEntry()];
          when(
            () => mockFunctions.invoke(any(), body: any(named: 'body')),
          ).thenAnswer(
            (_) async => FunctionResponse(
              data: buildInsightResponse(prediction: ''),
              status: 200,
            ),
          );

          expect(
            () => repository.generateInsight(logs),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'throws exception when Gemini API returns empty future letter',
        () async {
          final logs = [buildLogEntry()];
          when(
            () => mockFunctions.invoke(any(), body: any(named: 'body')),
          ).thenAnswer(
            (_) async => FunctionResponse(
              data: buildInsightResponse(futureLetter: ''),
              status: 200,
            ),
          );

          expect(
            () => repository.generateInsight(logs),
            throwsA(isA<Exception>()),
          );
        },
      );

      test('throws exception when prediction is too short', () async {
        final logs = [buildLogEntry()];
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async => FunctionResponse(
            data: buildInsightResponse(
              prediction: 'Too short - under 150 characters expected minimum',
            ),
            status: 200,
          ),
        );

        expect(
          () => repository.generateInsight(logs),
          throwsA(isA<Exception>()),
        );
      });

      test('throws exception when future letter is too short', () async {
        final logs = [buildLogEntry()];
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async => FunctionResponse(
            data: buildInsightResponse(
              futureLetter:
                  'Too short - future letter must be at least 250 characters',
            ),
            status: 200,
          ),
        );

        expect(
          () => repository.generateInsight(logs),
          throwsA(isA<Exception>()),
        );
      });

      test('throws exception when no logs provided', () async {
        expect(() => repository.generateInsight([]), throwsA(isA<Exception>()));
      });

      test('throws exception when all logs are empty', () async {
        final logs = [buildLogEntry(mood: null, habits: const [], notes: null)];

        expect(
          () => repository.generateInsight(logs),
          throwsA(isA<Exception>()),
        );
      });

      test('sends correct prompts with log data to API', () async {
        final logs = [buildLogEntry(id: 'test-log-1')];
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async =>
              FunctionResponse(data: buildInsightResponse(), status: 200),
        );

        await repository.generateInsight(logs);

        verify(
          () => mockFunctions.invoke(
            'generate-insight',
            body: any(named: 'body'),
          ),
        ).called(1);
      });
    });

    group('generateChatResponse', () {
      test(
        'returns non-empty string response on successful API call',
        () async {
          const userMessage = 'How am I doing this week?';
          const responseText =
              'Based on your recent logs, you have been doing great!';

          when(
            () => mockFunctions.invoke(any(), body: any(named: 'body')),
          ).thenAnswer(
            (_) async =>
                FunctionResponse(data: {'response': responseText}, status: 200),
          );

          final result = await repository.generateChatResponse(userMessage);

          expect(result, equals(responseText));
          expect(result.isNotEmpty, isTrue);
        },
      );

      test('returns non-empty string response with context', () async {
        const userMessage = 'Give me tips';
        const context = 'You have been stressed this week';
        const responseText = 'Here are some tips for managing stress.';

        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async =>
              FunctionResponse(data: {'response': responseText}, status: 200),
        );

        final result = await repository.generateChatResponse(
          userMessage,
          context: context,
        );

        expect(result, equals(responseText));
      });

      test('throws exception when Gemini API returns empty response', () async {
        const userMessage = 'Hello';
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async => FunctionResponse(data: {'response': ''}, status: 200),
        );

        expect(
          () => repository.generateChatResponse(userMessage),
          throwsA(isA<Exception>()),
        );
      });

      test('throws exception when API call fails', () async {
        const userMessage = 'Hello';
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.generateChatResponse(userMessage),
          throwsA(isA<Exception>()),
        );
      });

      test('sends correct prompts to API based on user message', () async {
        const userMessage = 'How is my mood?';
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async => FunctionResponse(
            data: {'response': 'Your mood seems good!'},
            status: 200,
          ),
        );

        await repository.generateChatResponse(userMessage);

        verify(
          () => mockFunctions.invoke(
            'generate-chat-response',
            body: {'userMessage': userMessage},
          ),
        ).called(1);
      });

      test('sends context when provided to API', () async {
        const userMessage = 'Give advice';
        const context = 'Recent stress at work';
        when(
          () => mockFunctions.invoke(any(), body: any(named: 'body')),
        ).thenAnswer(
          (_) async => FunctionResponse(
            data: {'response': 'Try relaxation techniques.'},
            status: 200,
          ),
        );

        await repository.generateChatResponse(userMessage, context: context);

        verify(
          () => mockFunctions.invoke(
            'generate-chat-response',
            body: {'userMessage': userMessage, 'context': context},
          ),
        ).called(1);
      });
    });

    group('getMockInsight', () {
      test('returns AiInsightModel with default values', () {
        final result = repository.getMockInsight();

        expect(result, isA<AiInsightModel>());
        expect(result.prediction, isNotEmpty);
        expect(result.suggestions, isNotEmpty);
        expect(result.futureLetter, isNotEmpty);
      });
    });
  });
}
