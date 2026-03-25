import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<dynamic> {}

void main() {
  late LoggingRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockPostgrestTransformBuilder mockTransformBuilder;

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

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockTransformBuilder = MockPostgrestTransformBuilder();
    repository = LoggingRepository(supabaseClient: mockSupabase);
  });

  group('LoggingRepository', () {
    test('createLogEntry returns LogEntryModel on success', () async {
      final entry = buildEntry();
      when(() => mockSupabase.from('log_entries')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select()).thenReturn(mockTransformBuilder);
      when(
        () => mockTransformBuilder.single(),
      ).thenAnswer((_) async => buildLogJson());

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
      when(() => mockSupabase.from('log_entries')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.update(any())).thenReturn(mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq(any(), any()),
      ).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select()).thenReturn(mockTransformBuilder);
      when(
        () => mockTransformBuilder.single(),
      ).thenAnswer((_) async => buildLogJson(mood: 5));

      final result = await repository.updateLogEntry(entry);

      expect(result.mood, 5);
      expect(result.id, 'log-1');
    });

    test('getLogEntryForDate returns null when no entry exists', () async {
      when(() => mockSupabase.from('log_entries')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq(any(), any()),
      ).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.maybeSingle()).thenAnswer((_) async => null);

      final result = await repository.getLogEntryForDate(now, userId);

      expect(result, isNull);
    });

    test('getLogEntries returns empty list on error (no throw)', () async {
      when(() => mockSupabase.from('log_entries')).thenThrow(Exception('db'));

      final result = await repository.getLogEntries(userId);

      expect(result, isEmpty);
    });

    test('deleteLogEntry completes without error on success', () async {
      when(() => mockSupabase.from('log_entries')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.delete()).thenReturn(mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq(any(), any()),
      ).thenReturn(mockFilterBuilder);

      await repository.deleteLogEntry('log-1', userId);

      verify(() => mockFilterBuilder.eq('id', 'log-1')).called(1);
      verify(() => mockFilterBuilder.eq('user_id', userId)).called(1);
    });

    test('getLogEntries filters by startDate and endDate correctly', () async {
      final startDate = DateTime.utc(2026, 3, 1);
      final endDate = DateTime.utc(2026, 3, 31);

      when(() => mockSupabase.from('log_entries')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.select()).thenReturn(mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq(any(), any()),
      ).thenReturn(mockFilterBuilder);
      when(
        () => mockFilterBuilder.gte(any(), any()),
      ).thenReturn(mockFilterBuilder);
      when(
        () => mockFilterBuilder.lte(any(), any()),
      ).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.order(any())).thenAnswer((_) async => []);

      await repository.getLogEntries(
        userId,
        startDate: startDate,
        endDate: endDate,
      );

      verify(() => mockFilterBuilder.gte('date', '2026-03-01')).called(1);
      verify(() => mockFilterBuilder.lte('date', '2026-03-31')).called(1);
      verify(() => mockFilterBuilder.order('date')).called(1);
    });
  });
}
