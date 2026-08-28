import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:echomirror/core/models/local_models.dart';
import 'package:echomirror/core/services/conflict_resolution_service.dart';
import 'package:echomirror/core/services/offline_storage_service.dart';
import 'package:echomirror/core/services/sync_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakePostgrestBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  final dynamic _result;
  FakePostgrestBuilder([this._result]);

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;
  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) => this;
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

  late Directory tempDir;
  late OfflineStorageService storage;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late SyncService syncService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_conflict_test');
    storage = OfflineStorageService(
      initializeHive: () async => Hive.init(tempDir.path),
    );
    await storage.initialize();

    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    syncService = SyncService(
      offlineStorage: storage,
      supabase: mockSupabase,
      conflictResolver: ConflictResolutionService.instance,
    );

    when(() => mockSupabase.from('log_entries')).thenAnswer((_) => mockQueryBuilder);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SyncService Conflict Resolution on Reconnect', () {
    test('detects server divergence and resolves with smart merge without blind overwrite', () async {
      final baseTime = DateTime.utc(2026, 8, 1, 10, 0);
      final serverEditTime = DateTime.utc(2026, 8, 1, 12, 0);
      final offlineEditTime = DateTime.utc(2026, 8, 1, 14, 0);

      // 1. Queued local offline mutation
      final queuedEntry = LocalLogEntry(
        id: 'uuid-1',
        userId: 'user-conflict-1',
        date: '2026-08-01',
        mood: 5,
        habits: ['exercise'],
        notes: 'Offline note revision',
        createdAt: baseTime,
        updatedAt: offlineEditTime,
      );
      await storage.queueLogEntry(queuedEntry);

      // 2. Server state that diverged in the interim
      final serverRow = {
        'id': 'uuid-1',
        'mood': 3,
        'habits': ['meditate'],
        'notes': 'Server note revision',
        'created_at': baseTime.toIso8601String(),
        'updated_at': serverEditTime.toIso8601String(),
      };

      Map<String, dynamic>? updatedPayload;

      when(() => mockQueryBuilder.select(any())).thenAnswer((_) => FakePostgrestBuilder(serverRow));
      when(() => mockQueryBuilder.update(any())).thenAnswer((inv) {
        updatedPayload = inv.positionalArguments[0] as Map<String, dynamic>;
        return FakePostgrestBuilder(serverRow);
      });

      final result = await syncService.syncPendingEntries();

      expect(result.syncedCount, equals(1));
      expect(result.conflictsResolved, equals(1));
      expect(storage.pendingLogEntryCount, equals(0));

      // Verify payload sent to Supabase was smart-merged, not blindly overwritten
      expect(updatedPayload, isNotNull);
      expect(updatedPayload!['mood'], equals(5)); // Local was newer
      expect(updatedPayload!['habits'], containsAll(['meditate', 'exercise']));
      expect((updatedPayload!['notes'] as String).contains('Server note revision'), isTrue);
      expect((updatedPayload!['notes'] as String).contains('Offline note revision'), isTrue);
    });
  });
}
