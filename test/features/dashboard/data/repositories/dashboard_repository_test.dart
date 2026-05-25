import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echo_mirror_butler/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:echo_mirror_butler/features/dashboard/data/models/insight_model.dart';
import 'package:echo_mirror_butler/features/logging/data/repositories/logging_repository.dart';
import 'package:echo_mirror_butler/features/logging/data/models/log_entry_model.dart';

class MockLoggingRepository extends Mock implements LoggingRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

List<LogEntryModel> _fakeLogEntries() => [
  LogEntryModel(
    id: '1',
    userId: 'user-123',
    date: DateTime(2024, 1, 1),
    mood: 4,
    habits: ['exercise', 'reading'],
    notes: 'Good day',
  ),
  LogEntryModel(
    id: '2',
    userId: 'user-123',
    date: DateTime(2024, 1, 2),
    mood: 3,
    habits: ['meditation'],
    notes: 'Average day',
  ),
];

DashboardRepository _buildRepo({
  required MockLoggingRepository loggingRepo,
  required MockSupabaseClient supabaseClient,
}) => DashboardRepository(
  loggingRepo,
  supabaseClient: supabaseClient,
  now: () => DateTime(2024, 1, 10),
);

void main() {
  late MockLoggingRepository loggingRepo;
  late MockSupabaseClient supabase;
  late MockFunctionsClient functions;

  setUp(() {
    loggingRepo = MockLoggingRepository();
    supabase = MockSupabaseClient();
    functions = MockFunctionsClient();
    when(() => supabase.functions).thenReturn(functions);
  });

  group('getPredictions', () {
    test('returns empty list when user has no log entries', () async {
      when(
        () => loggingRepo.getLogEntries('user-123'),
      ).thenAnswer((_) async => []);

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final result = await repo.getPredictions('user-123');

      expect(result, isEmpty);
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });

    test('maps prediction field to InsightModel', () async {
      when(
        () => loggingRepo.getLogEntries('user-123'),
      ).thenAnswer((_) async => _fakeLogEntries());

      when(
        () => functions.invoke('generate-insight', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => FunctionResponse(
          data: {'prediction': 'You tend to feel great on Fridays.'},
          status: 200,
        ),
      );

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final results = await repo.getPredictions('user-123');

      expect(results, isNotEmpty);
      expect(results.first.title, 'AI Prediction');
      expect(results.first.description, 'You tend to feel great on Fridays.');
      expect(results.first.type, InsightType.prediction);
    });

    test('returns empty list when edge function throws', () async {
      when(
        () => loggingRepo.getLogEntries('user-123'),
      ).thenAnswer((_) async => _fakeLogEntries());

      when(
        () => functions.invoke('generate-insight', body: any(named: 'body')),
      ).thenThrow(Exception('Network error'));

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final results = await repo.getPredictions('user-123');

      expect(results, isEmpty);
    });

    test(
      'returns empty list when edge function returns non-map data',
      () async {
        when(
          () => loggingRepo.getLogEntries('user-123'),
        ).thenAnswer((_) async => _fakeLogEntries());

        when(
          () => functions.invoke('generate-insight', body: any(named: 'body')),
        ).thenAnswer(
          (_) async => FunctionResponse(data: 'unexpected string', status: 200),
        );

        final repo = _buildRepo(
          loggingRepo: loggingRepo,
          supabaseClient: supabase,
        );
        final results = await repo.getPredictions('user-123');

        expect(results, isEmpty);
      },
    );

    test('maps calmingMessage to InsightModel with mood type', () async {
      when(
        () => loggingRepo.getLogEntries('user-123'),
      ).thenAnswer((_) async => _fakeLogEntries());

      when(
        () => functions.invoke('generate-insight', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => FunctionResponse(
          data: {'calmingMessage': 'Breathe and be present.'},
          status: 200,
        ),
      );

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final results = await repo.getPredictions('user-123');

      final calming = results
          .where((r) => r.title == 'Calming Thought')
          .toList();
      expect(calming, hasLength(1));
      expect(calming.first.type, InsightType.mood);
    });
  });

  group('getFutureLetters', () {
    late MockSupabaseQueryBuilder queryBuilder;

    setUp(() {
      queryBuilder = MockSupabaseQueryBuilder();
      when(() => supabase.from('future_letters')).thenReturn(queryBuilder);
      when(() => queryBuilder.select()).thenReturn(queryBuilder);
      when(() => queryBuilder.eq('user_id', any())).thenReturn(queryBuilder);
      when(
        () => queryBuilder.order('created_at', ascending: false),
      ).thenReturn(queryBuilder);
      when(() => queryBuilder.limit(10)).thenReturn(queryBuilder);
    });

    test('returns empty list when table is empty', () async {
      when(() => queryBuilder).thenAnswer((_) async => <dynamic>[]);

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final results = await repo.getFutureLetters('user-123');

      expect(results, isEmpty);
    });

    test('maps rows to InsightModel correctly', () async {
      final fakeRow = {
        'id': 'letter-1',
        'user_id': 'user-123',
        'title': 'Hello Future Me',
        'content': 'You made it!',
        'created_at': '2024-01-01T00:00:00Z',
        'delivery_date': '2025-01-01T00:00:00Z',
      };

      when(() => queryBuilder).thenAnswer((_) async => [fakeRow]);

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final results = await repo.getFutureLetters('user-123');

      expect(results, hasLength(1));
      expect(results.first.id, 'letter-1');
      expect(results.first.title, 'Hello Future Me');
      expect(results.first.description, 'You made it!');
      expect(results.first.type, InsightType.general);
    });

    test('returns empty list when Supabase throws', () async {
      when(() => queryBuilder).thenThrow(Exception('DB error'));

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final results = await repo.getFutureLetters('user-123');

      expect(results, isEmpty);
    });

    test('uses default title when title is absent', () async {
      final fakeRow = {
        'id': 'letter-2',
        'user_id': 'user-123',
        'content': 'No title here',
        'created_at': '2024-01-01T00:00:00Z',
      };

      when(() => queryBuilder).thenAnswer((_) async => [fakeRow]);

      final repo = _buildRepo(
        loggingRepo: loggingRepo,
        supabaseClient: supabase,
      );
      final results = await repo.getFutureLetters('user-123');

      expect(results.first.title, 'Future Letter');
    });
  });
}
