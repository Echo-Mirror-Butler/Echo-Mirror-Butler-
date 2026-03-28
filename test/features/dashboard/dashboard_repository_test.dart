import 'package:echomirror/features/dashboard/data/models/insight_model.dart';
import 'package:echomirror/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockLoggingRepository extends Mock implements LoggingRepository {}

// --- New Supabase Mocks ---
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockFunctionResponse extends Mock implements FunctionResponse {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
// We use dynamic generics here to easily bypass strict type-casting issues in tests
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<dynamic> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<dynamic> {}

LogEntryModel _entry({
  required String userId,
  required DateTime date,
  int? mood,
  List<String> habits = const [],
  String? notes,
}) {
  final normalized = DateTime(date.year, date.month, date.day);
  return LogEntryModel(
    id: '${userId}_${normalized.toIso8601String()}_${mood ?? 'none'}',
    userId: userId,
    date: normalized,
    mood: mood,
    habits: habits,
    notes: notes,
    createdAt: normalized,
  );
}

void main() {
  const userId = 'user_1';
  final fixedNow = DateTime(2026, 3, 25, 12, 0);

  late MockLoggingRepository loggingRepository;
  late DashboardRepository repository;
  
  // Supabase mock instances
  late MockSupabaseClient mockSupabaseClient;
  late MockFunctionsClient mockFunctionsClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockPostgrestTransformBuilder mockTransformBuilder;

  setUp(() {
    loggingRepository = MockLoggingRepository();
    
    // Initialize Supabase Mocks
    mockSupabaseClient = MockSupabaseClient();
    mockFunctionsClient = MockFunctionsClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockTransformBuilder = MockPostgrestTransformBuilder();

    // Wire up the basic Supabase client getters
    when(() => mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
    when(() => mockSupabaseClient.from(any())).thenReturn(mockQueryBuilder);

    // Inject the mocked Supabase client into the repository
    repository = DashboardRepository(
      loggingRepository,
      supabaseClient: mockSupabaseClient,
      now: () => fixedNow,
    );
  });

  group('DashboardRepository.getInsights', () {
    // ... [Your existing getInsights tests remain completely unchanged below] ...

    test('returns empty list when there are no log entries', () async {
      when(
        () => loggingRepository.getLogEntries(userId),
      ).thenAnswer((_) async => []);

      final insights = await repository.getInsights(userId);
      expect(insights, isEmpty);
      verify(() => loggingRepository.getLogEntries(userId)).called(1);
    });

    test(
      'adds "Mood Improvement Detected" when recent average is higher',
      () async {
        final entries = <LogEntryModel>[
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 1)), mood: 4),
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 2)), mood: 4),
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 3)), mood: 4),
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 20)), mood: 2),
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 21)), mood: 2),
        ];

        when(() => loggingRepository.getLogEntries(userId)).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        expect(
          insights.any((i) => i.title == 'Mood Improvement Detected' && i.type == InsightType.mood),
          isTrue,
        );
      },
    );

    test('adds "Mood Trend Notice" when recent average is lower', () async {
      final entries = <LogEntryModel>[
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 1)), mood: 2),
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 2)), mood: 2),
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 3)), mood: 2),
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 20)), mood: 4),
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 21)), mood: 4),
      ];

      when(() => loggingRepository.getLogEntries(userId)).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      expect(
        insights.any((i) => i.title == 'Mood Trend Notice' && i.type == InsightType.mood),
        isTrue,
      );
    });

    test('adds "Great Mood Day" when best mood entry is >= 4', () async {
      final entries = <LogEntryModel>[
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 1)), mood: 4),
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 2)), mood: 3),
        _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 3)), mood: 2),
      ];
      when(() => loggingRepository.getLogEntries(userId)).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      final greatMood = insights.where((i) => i.title == 'Great Mood Day').toList();
      expect(greatMood, isNotEmpty);
      expect(greatMood.first.type, InsightType.mood);
    });

    test('adds "Consistent Habit" when top habit logged >= 5 times', () async {
      final entries = List.generate(
        5,
        (i) => _entry(userId: userId, date: fixedNow.subtract(Duration(days: i)), mood: 3, habits: const ['Meditation']),
      );
      when(() => loggingRepository.getLogEntries(userId)).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      expect(
        insights.any((i) => i.title == 'Consistent Habit' && i.type == InsightType.habit),
        isTrue,
      );
    });

    test('adds "Habit Variety" when recent 7 days contain >= 3 unique habits', () async {
        final entries = <LogEntryModel>[
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 1)), habits: const ['Meditation']),
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 2)), habits: const ['Walk']),
          _entry(userId: userId, date: fixedNow.subtract(const Duration(days: 3)), habits: const ['Journaling']),
        ];
        when(() => loggingRepository.getLogEntries(userId)).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        expect(
          insights.any((i) => i.title == 'Habit Variety' && i.type == InsightType.habit),
          isTrue,
        );
      },
    );

    test('adds "Logging Milestone" when there are >= 7 entries', () async {
      final entries = List.generate(
        7,
        (i) => _entry(userId: userId, date: fixedNow.subtract(Duration(days: i)), mood: 3),
      );
      when(() => loggingRepository.getLogEntries(userId)).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      expect(
        insights.any((i) => i.title == 'Logging Milestone' && i.type == InsightType.general),
        isTrue,
      );
    });

    test('adds "Pattern Detected" prediction when there are >= 5 mood entries', () async {
        final monday = DateTime(2026, 3, 23); // Monday
        final entries = <LogEntryModel>[
          _entry(userId: userId, date: monday, mood: 5),
          _entry(userId: userId, date: monday.subtract(const Duration(days: 7)), mood: 5),
          _entry(userId: userId, date: monday.add(const Duration(days: 1)), mood: 3),
          _entry(userId: userId, date: monday.add(const Duration(days: 2)), mood: 3),
          _entry(userId: userId, date: monday.add(const Duration(days: 3)), mood: 3),
        ];

        when(() => loggingRepository.getLogEntries(userId)).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        expect(
          insights.any((i) => i.title == 'Pattern Detected' && i.type == InsightType.prediction),
          isTrue,
        );
      },
    );
  });

  // --- NEW TESTS FOR ISSUE #128 ---

  group('DashboardRepository.getPredictions', () {
    test('returns mapped InsightModels when Edge Function is successful', () async {
      // Arrange
      final mockResponse = MockFunctionResponse();
      when(() => mockResponse.data).thenReturn([
        {
          'id': 'edge-pred-1',
          'userId': userId,
          'title': 'AI Generated Insight',
          'description': 'You are doing great!',
          'date': fixedNow.toIso8601String(),
          'type': 'prediction', // Maps to InsightType.prediction
          'createdAt': fixedNow.toIso8601String(),
        }
      ]);

      when(() => mockFunctionsClient.invoke('generate-insight', body: {'user_id': userId}))
          .thenAnswer((_) async => mockResponse);

      // Act
      final result = await repository.getPredictions(userId);

      // Assert
      expect(result, isA<List<InsightModel>>());
      expect(result.length, 1);
      expect(result.first.title, 'AI Generated Insight');
      verify(() => mockFunctionsClient.invoke('generate-insight', body: {'user_id': userId})).called(1);
    });

    test('throws Exception when Edge Function fails', () async {
      // Arrange
      when(() => mockFunctionsClient.invoke('generate-insight', body: {'user_id': userId}))
          .thenThrow(FunctionException(status: 500, reason: 'Internal Server Error'));

      // Act & Assert
      expect(() => repository.getPredictions(userId), throwsException);
    });
  });

  group('DashboardRepository.getFutureLetters', () {
    test('returns mapped InsightModels when database query is successful', () async {
      // Arrange: Mock the fluent PostgREST chain
      when(() => mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('user_id', userId)).thenReturn(mockTransformBuilder);
      
      // Mock the final returned data list
      when(() => mockTransformBuilder.order('created_at', ascending: false))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'user_id': userId,
                  'content': 'Dear future me...',
                  'created_at': fixedNow.toIso8601String(),
                  'unlock_at': fixedNow.add(const Duration(days: 30)).toIso8601String(),
                }
              ]);

      // Act
      final result = await repository.getFutureLetters(userId);

      // Assert
      expect(result, isA<List<InsightModel>>());
      expect(result.length, 1);
      expect(result.first.title, 'Letter from Future You');
      expect(result.first.description, 'Dear future me...');
      verify(() => mockSupabaseClient.from('future_letters')).called(1);
    });

    test('throws Exception when database query fails', () async {
      // Arrange
      when(() => mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('user_id', userId)).thenReturn(mockTransformBuilder);
      
      when(() => mockTransformBuilder.order('created_at', ascending: false))
          .thenThrow(const PostgrestException(message: 'Relation "future_letters" does not exist'));

      // Act & Assert
      expect(() => repository.getFutureLetters(userId), throwsException);
    });
  });
}