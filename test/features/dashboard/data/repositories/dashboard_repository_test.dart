import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echomirror/features/dashboard/data/models/insight_model.dart';
import 'package:echomirror/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';

class MockLoggingRepository extends Mock implements LoggingRepository {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakeFutureLettersBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  FakeFutureLettersBuilder(this._result);
  final Future<PostgrestList> _result;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<PostgrestList> order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestFilterBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) => this;

  @override
  Stream<PostgrestList> asStream() => _result.asStream();

  @override
  Future<PostgrestList> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _result.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => _result.then(onValue, onError: onError);

  @override
  Future<PostgrestList> timeout(
    Duration timeLimit, {
    FutureOr<PostgrestList> Function()? onTimeout,
  }) => _result.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<PostgrestList> whenComplete(FutureOr<void> Function() action) =>
      _result.whenComplete(action);
}

List<LogEntryModel> _fakeLogEntries() => [
      LogEntryModel(
        id: '1',
        userId: 'user-123',
        date: DateTime(2024, 1, 1),
        mood: 4,
        habits: ['exercise', 'reading'],
        notes: 'Good day',
        createdAt: DateTime(2024, 1, 1),
      ),
      LogEntryModel(
        id: '2',
        userId: 'user-123',
        date: DateTime(2024, 1, 2),
        mood: 3,
        habits: ['meditation'],
        notes: 'Average day',
        createdAt: DateTime(2024, 1, 2),
      ),
    ];

DashboardRepository buildRepo({
  required MockLoggingRepository loggingRepo,
  required MockSupabaseClient supabaseClient,
}) =>
    DashboardRepository(
      loggingRepo,
      supabaseClient: supabaseClient,
      now: () => DateTime(2024, 1, 10),
    );

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSupabaseQueryBuilder());
  });
  late MockLoggingRepository loggingRepo;
  late MockSupabaseClient supabase;
  late MockFunctionsClient functions;
  late MockSupabaseQueryBuilder queryBuilder;

  setUp(() {
    loggingRepo = MockLoggingRepository();
    supabase = MockSupabaseClient();
    functions = MockFunctionsClient();
    queryBuilder = MockSupabaseQueryBuilder();

    when(() => supabase.functions).thenReturn(functions);
    when(() => supabase.from('future_letters')).thenAnswer((_) => queryBuilder);
  });

  group('getPredictions', () {
    test('returns empty list when user has no log entries', () async {
      when(() => loggingRepo.getLogEntries('user-123'))
          .thenAnswer((_) async => []);

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final result = await repo.getPredictions('user-123');

      expect(result, isEmpty);
      verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
    });

    test('maps prediction field to InsightModel', () async {
      when(() => loggingRepo.getLogEntries('user-123'))
          .thenAnswer((_) async => _fakeLogEntries());
      when(() => functions.invoke('generate-insight', body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'prediction': 'You tend to feel great on Fridays.'},
                status: 200,
              ));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getPredictions('user-123');

      expect(results, isNotEmpty);
      expect(results.first.title, 'AI Prediction');
      expect(results.first.description, 'You tend to feel great on Fridays.');
      expect(results.first.type, InsightType.prediction);
    });

    test('returns empty list when edge function throws', () async {
      when(() => loggingRepo.getLogEntries('user-123'))
          .thenAnswer((_) async => _fakeLogEntries());
      when(() => functions.invoke('generate-insight', body: any(named: 'body')))
          .thenThrow(Exception('Network error'));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getPredictions('user-123');

      expect(results, isEmpty);
    });

    test('returns empty list when edge function returns non-map data', () async {
      when(() => loggingRepo.getLogEntries('user-123'))
          .thenAnswer((_) async => _fakeLogEntries());
      when(() => functions.invoke('generate-insight', body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: 'unexpected string',
                status: 200,
              ));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getPredictions('user-123');

      expect(results, isEmpty);
    });

    test('maps calmingMessage to InsightModel with mood type', () async {
      when(() => loggingRepo.getLogEntries('user-123'))
          .thenAnswer((_) async => _fakeLogEntries());
      when(() => functions.invoke('generate-insight', body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(
                data: {'calmingMessage': 'Breathe and be present.'},
                status: 200,
              ));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getPredictions('user-123');

      final calming = results.where((i) => i.title == 'Calming Thought').toList();
      expect(calming, hasLength(1));
      expect(calming.first.type, InsightType.mood);
    });
  });

  group('getFutureLetters', () {
    void stubSelect(Future<PostgrestList> result) {
      final fakeBuilder = FakeFutureLettersBuilder(result);
      when(() => queryBuilder.select()).thenAnswer((_) => fakeBuilder);
    }

    test('returns empty list when table is empty', () async {
      stubSelect(Future.value([]));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getFutureLetters('user-123');

      expect(results, isEmpty);
    });

    test('maps rows to InsightModel correctly', () async {
      final fakeRow = <String, dynamic>{
        'id': 'letter-1',
        'user_id': 'user-123',
        'title': 'Hello Future Me',
        'content': 'You made it!',
        'created_at': '2024-01-01T00:00:00Z',
        'delivery_date': '2025-01-01T00:00:00Z',
      };
      stubSelect(Future.value([fakeRow]));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getFutureLetters('user-123');

      expect(results, hasLength(1));
      expect(results.first.id, 'letter-1');
      expect(results.first.title, 'Hello Future Me');
      expect(results.first.description, 'You made it!');
      expect(results.first.type, InsightType.general);
    });

    test('returns empty list when Supabase throws', () async {
      stubSelect(Future.error(Exception('DB error')));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getFutureLetters('user-123');

      expect(results, isEmpty);
    });

    test('uses default title when title is absent', () async {
      final fakeRow = <String, dynamic>{
        'id': 'letter-2',
        'user_id': 'user-123',
        'content': 'No title here',
        'created_at': '2024-01-01T00:00:00Z',
      };
      stubSelect(Future.value([fakeRow]));

      final repo = buildRepo(loggingRepo: loggingRepo, supabaseClient: supabase);
      final results = await repo.getFutureLetters('user-123');

      expect(results.first.title, 'Future Letter');
    });
  });
}
