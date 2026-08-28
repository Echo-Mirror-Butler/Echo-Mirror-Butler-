import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:echomirror/core/services/field_encryption_service.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakePostgrestBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  final dynamic _result;
  FakePostgrestBuilder([this._result]);

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> gte(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> lte(String column, Object value) => this;
  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;
  @override
  PostgrestTransformBuilder<PostgrestList> range(
    int from,
    int to, {
    String? referencedTable,
  }) => this;
  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) => this;
  @override
  PostgrestTransformBuilder<PostgrestMap> single() => _FakeSingleBuilder(_result);
  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() => _FakeMaybeSingleBuilder(_result);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList) onValue, {
    Function? onError,
  }) {
    final list = _result is List<Map<String, dynamic>>
        ? _result
        : _result is List
            ? _result.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];
    return Future.value(list).then(onValue, onError: onError);
  }
}

class _FakeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap> {
  final dynamic _result;
  _FakeSingleBuilder(this._result);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestMap) onValue, {
    Function? onError,
  }) {
    return Future.value(
      _result as PostgrestMap,
    ).then(onValue, onError: onError);
  }
}

class _FakeMaybeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap?> {
  final dynamic _result;
  _FakeMaybeSingleBuilder(this._result);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestMap?) onValue, {
    Function? onError,
  }) {
    return Future.value(
      _result as PostgrestMap?,
    ).then(onValue, onError: onError);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late FieldEncryptionService encryptionService;
  late LoggingRepository repository;

  final testDate = DateTime.utc(2026, 7, 15, 10, 0);
  const userId = 'user-enc-test-123';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    encryptionService = FieldEncryptionService.instance;
    encryptionService.clearCache();

    repository = LoggingRepository(
      supabaseClient: mockSupabase,
      encryptionService: encryptionService,
    );

    when(() => mockSupabase.from('log_entries')).thenAnswer((_) => mockQueryBuilder);
  });

  group('LoggingRepository Field-Level Encryption at Rest', () {
    test('createLogEntry encrypts private notes before sending payload to Supabase', () async {
      const sensitiveNote = 'Feeling overwhelmed by work today, need a break.';
      final entry = LogEntryModel(
        id: 'log-1',
        userId: userId,
        date: testDate,
        mood: 2,
        habits: ['exercise'],
        notes: sensitiveNote,
        createdAt: testDate,
      );

      Map<String, dynamic>? capturedPayload;

      when(() => mockQueryBuilder.insert(any())).thenAnswer((invocation) {
        capturedPayload = invocation.positionalArguments[0] as Map<String, dynamic>;
        final storedRow = {
          'id': 'log-1',
          'user_id': userId,
          'date': '2026-07-15',
          'mood': 2,
          'habits': ['exercise'],
          'notes': capturedPayload!['notes'], // Simulated stored row
          'created_at': testDate.toIso8601String(),
          'updated_at': null,
        };
        return FakePostgrestBuilder(storedRow);
      });

      final result = await repository.createLogEntry(entry);

      // Verify payload at rest is encrypted
      expect(capturedPayload, isNotNull);
      final storedNotes = capturedPayload!['notes'] as String;
      expect(encryptionService.isEncrypted(storedNotes), isTrue);
      expect(storedNotes.contains(sensitiveNote), isFalse);

      // Verify decrypted result returned to client
      expect(result.notes, equals(sensitiveNote));
    });

    test('getLogEntryForDate decrypts encrypted note stored at rest', () async {
      const originalNote = 'Great progress on open source bounty work!';
      final encryptedNote = await encryptionService.encrypt(originalNote, userId: userId);

      final row = {
        'id': 'log-2',
        'user_id': userId,
        'date': '2026-07-15',
        'mood': 5,
        'habits': ['code', 'read'],
        'notes': encryptedNote,
        'created_at': testDate.toIso8601String(),
      };

      when(() => mockQueryBuilder.select()).thenAnswer((_) => FakePostgrestBuilder(row));

      final result = await repository.getLogEntryForDate(testDate, userId);

      expect(result, isNotNull);
      expect(result!.notes, equals(originalNote));
    });

    test('getLogEntryForDate gracefully handles legacy plaintext notes', () async {
      const legacyPlaintextNote = 'Unencrypted legacy note from older app version.';

      final row = {
        'id': 'log-3',
        'user_id': userId,
        'date': '2026-07-15',
        'mood': 3,
        'habits': [],
        'notes': legacyPlaintextNote,
        'created_at': testDate.toIso8601String(),
      };

      when(() => mockQueryBuilder.select()).thenAnswer((_) => FakePostgrestBuilder(row));

      final result = await repository.getLogEntryForDate(testDate, userId);

      expect(result, isNotNull);
      expect(result!.notes, equals(legacyPlaintextNote));
    });

    test('getLogEntries decrypts all encrypted notes in fetched list', () async {
      final note1 = await encryptionService.encrypt('First encrypted note', userId: userId);
      final note2 = await encryptionService.encrypt('Second encrypted note', userId: userId);

      final rows = [
        {
          'id': 'log-10',
          'user_id': userId,
          'date': '2026-07-15',
          'mood': 4,
          'habits': [],
          'notes': note1,
          'created_at': testDate.toIso8601String(),
        },
        {
          'id': 'log-11',
          'user_id': userId,
          'date': '2026-07-14',
          'mood': 5,
          'habits': [],
          'notes': note2,
          'created_at': testDate.toIso8601String(),
        },
      ];

      when(() => mockQueryBuilder.select()).thenAnswer((_) => FakePostgrestBuilder(rows));

      final results = await repository.getLogEntries(userId);

      expect(results.length, equals(2));
      expect(results[0].notes, equals('First encrypted note'));
      expect(results[1].notes, equals('Second encrypted note'));
    });
  });
}
