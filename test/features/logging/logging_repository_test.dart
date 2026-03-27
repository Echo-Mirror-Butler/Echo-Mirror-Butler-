import 'dart:async';

import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestListBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class MockPostgrestMapBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap> {}

class MockPostgrestNullableMapBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap?> {}

class FakeMapCallback extends Fake {
  PostgrestMap call(PostgrestMap value) => value;
}

class FakeNullableMapCallback extends Fake {
  PostgrestMap? call(PostgrestMap? value) => value;
}

class FakeListCallback extends Fake {
  PostgrestList call(PostgrestList value) => value;
}

void _stubListAwait(
  MockPostgrestListBuilder builder,
  List<Map<String, dynamic>> result,
) {
  when(() => builder.then(any(), onError: any(named: 'onError'))).thenAnswer((
    invocation,
  ) async {
    final onValue =
        invocation.positionalArguments.first
            as FutureOr<dynamic> Function(PostgrestList);
    return onValue(result);
  });
}

void _stubMapAwait(
  MockPostgrestMapBuilder builder,
  Map<String, dynamic> result,
) {
  when(() => builder.then(any(), onError: any(named: 'onError'))).thenAnswer((
    invocation,
  ) async {
    final onValue =
        invocation.positionalArguments.first
            as FutureOr<dynamic> Function(PostgrestMap);
    return onValue(result);
  });
}

void _stubNullableMapAwait(
  MockPostgrestNullableMapBuilder builder,
  Map<String, dynamic>? result,
) {
  when(() => builder.then(any(), onError: any(named: 'onError'))).thenAnswer((
    invocation,
  ) async {
    final onValue =
        invocation.positionalArguments.first
            as FutureOr<dynamic> Function(PostgrestMap?);
    return onValue(result);
  });
}

void main() {
  late LoggingRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestListBuilder mockListBuilder;
  late MockPostgrestMapBuilder mockMapBuilder;
  late MockPostgrestNullableMapBuilder mockNullableMapBuilder;

  const userId = '123e4567-e89b-12d3-a456-426614174000';
  final now = DateTime.utc(2026, 3, 25, 12, 0, 0);

  Map<String, dynamic> buildLogJson({
    String id = 'log-1',
    String user = userId,
    DateTime? date,
    int mood = 4,
  }) {
    final d = date ?? now;
    return {
      'id': id,
      'user_id': user,
      'date': d.toIso8601String(),
      'mood': mood,
      'habits': ['hydrate', 'walk'],
      'notes': 'note',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
  }

  LogEntryModel buildEntry() {
    return LogEntryModel(
      id: 'log-1',
      userId: userId,
      date: now,
      mood: 4,
      habits: const ['hydrate', 'walk'],
      notes: 'note',
      createdAt: now,
      updatedAt: now,
    );
  }

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(FakeMapCallback());
    registerFallbackValue(FakeNullableMapCallback());
    registerFallbackValue(FakeListCallback());
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockListBuilder = MockPostgrestListBuilder();
    mockMapBuilder = MockPostgrestMapBuilder();
    mockNullableMapBuilder = MockPostgrestNullableMapBuilder();
    repository = LoggingRepository(supabaseClient: mockSupabase);

    when(
      () => mockSupabase.from('log_entries'),
    ).thenAnswer((_) => mockQueryBuilder);

    when(() => mockListBuilder.eq(any(), any())).thenReturn(mockListBuilder);
    when(() => mockListBuilder.gte(any(), any())).thenReturn(mockListBuilder);
    when(() => mockListBuilder.lte(any(), any())).thenReturn(mockListBuilder);
    when(
      () => mockListBuilder.order(
        any(),
        ascending: any(named: 'ascending'),
        nullsFirst: any(named: 'nullsFirst'),
        referencedTable: any(named: 'referencedTable'),
      ),
    ).thenReturn(mockListBuilder);
    when(() => mockListBuilder.select(any())).thenReturn(mockListBuilder);
    when(() => mockListBuilder.single()).thenReturn(mockMapBuilder);
    when(
      () => mockListBuilder.maybeSingle(),
    ).thenReturn(mockNullableMapBuilder);
  });

  group('LoggingRepository', () {
    test('createLogEntry returns LogEntryModel on success', () async {
      final entry = buildEntry();

      when(
        () => mockQueryBuilder.insert(any()),
      ).thenAnswer((_) => mockListBuilder);
      _stubMapAwait(mockMapBuilder, buildLogJson());

      final result = await repository.createLogEntry(entry);

      expect(result.id, 'log-1');
      expect(result.userId, userId);
      expect(result.mood, 4);
    });

    test('createLogEntry throws on Supabase error', () async {
      final entry = buildEntry();
      when(() => mockSupabase.from('log_entries')).thenThrow(Exception('db'));

      expect(() => repository.createLogEntry(entry), throwsA(isA<Exception>()));
    });

    test('updateLogEntry returns updated model on success', () async {
      final entry = buildEntry().copyWith(mood: 5, notes: 'updated');

      when(
        () => mockQueryBuilder.update(any()),
      ).thenAnswer((_) => mockListBuilder);
      _stubMapAwait(mockMapBuilder, buildLogJson(mood: 5));

      final result = await repository.updateLogEntry(entry);

      expect(result.mood, 5);
      expect(result.id, 'log-1');
    });

    test('getLogEntryForDate returns null when no entry exists', () async {
      when(() => mockQueryBuilder.select()).thenAnswer((_) => mockListBuilder);
      _stubNullableMapAwait(mockNullableMapBuilder, null);

      final result = await repository.getLogEntryForDate(now, userId);

      expect(result, isNull);
    });

    test('getLogEntries returns empty list on error (no throw)', () async {
      when(() => mockSupabase.from('log_entries')).thenThrow(Exception('db'));

      final result = await repository.getLogEntries(userId);

      expect(result, isEmpty);
    });

    test('deleteLogEntry completes without error on success', () async {
      when(() => mockQueryBuilder.delete()).thenAnswer((_) => mockListBuilder);
      _stubListAwait(mockListBuilder, <Map<String, dynamic>>[]);

      await repository.deleteLogEntry('log-1', userId);
    });

    test('getLogEntries filters by startDate and endDate correctly', () async {
      final startDate = DateTime.utc(2026, 3, 1);
      final endDate = DateTime.utc(2026, 3, 31);

      when(() => mockQueryBuilder.select()).thenAnswer((_) => mockListBuilder);
      _stubListAwait(mockListBuilder, <Map<String, dynamic>>[]);

      await repository.getLogEntries(
        userId,
        startDate: startDate,
        endDate: endDate,
      );

      verify(() => mockListBuilder.gte('date', '2026-03-01')).called(1);
      verify(() => mockListBuilder.lte('date', '2026-03-31')).called(1);
    });
  });
}
