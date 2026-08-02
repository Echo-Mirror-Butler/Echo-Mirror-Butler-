import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echomirror/core/models/local_models.dart';
import 'package:echomirror/core/services/connectivity_service.dart';
import 'package:echomirror/core/services/mood_sync_service.dart';
import 'package:echomirror/core/services/offline_storage_service.dart';
import 'package:echomirror/core/services/sync_service.dart';

/// Records sync runs and drains the queue without touching the network.
class _FakeSyncService extends SyncService {
  _FakeSyncService(OfflineStorageService storage)
    : super(
        offlineStorage: storage,
        supabase: SupabaseClient('http://localhost:54321', 'test-anon-key'),
      );

  int syncCalls = 0;
  final List<List<String>> syncedDateBatches = [];

  @override
  Future<SyncResult> syncPendingEntries() async {
    syncCalls++;
    final pending = offlineStorage.getPendingLogEntries();
    syncedDateBatches.add(pending.map((e) => e.date).toList());
    for (final entry in pending) {
      await offlineStorage.deleteLogEntry(entry.id);
    }
    return SyncResult(syncedCount: pending.length);
  }
}

class _FakeConnectivityService extends ConnectivityService {
  final StreamController<bool> controller = StreamController<bool>.broadcast();
  bool online = false;

  @override
  Stream<bool> get onStatusChange => controller.stream;

  @override
  Future<bool> isConnected() async => online;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late OfflineStorageService storage;
  late _FakeSyncService syncService;
  late _FakeConnectivityService connectivity;
  late MoodSyncService moodSync;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mood_sync_test');
    storage = OfflineStorageService(
      initializeHive: () async => Hive.init(tempDir.path),
    );
    syncService = _FakeSyncService(storage);
    connectivity = _FakeConnectivityService();
    moodSync = MoodSyncService(
      offlineStorage: storage,
      syncService: syncService,
      connectivity: connectivity,
    );
  });

  tearDown(() async {
    moodSync.dispose();
    await connectivity.controller.close();
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  LocalLogEntry buildEntry(String id, String date, DateTime createdAt) {
    return LocalLogEntry(
      id: id,
      userId: 'user-1',
      date: date,
      mood: 3,
      habits: const [],
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  group('queueMoodLog', () {
    test('stores a pending entry and increments pendingCount', () async {
      expect(moodSync.pendingCount, 0);

      final entry = await moodSync.queueMoodLog(
        userId: 'user-1',
        date: DateTime.utc(2026, 7, 26),
        mood: 4,
        habits: const ['walk'],
        notes: 'offline note',
      );

      expect(moodSync.pendingCount, 1);
      expect(entry.date, '2026-07-26');
      expect(entry.synced, isFalse);
      // Must be a valid v4 UUID (log_entries.id is a Postgres uuid column)
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(entry.id),
        isTrue,
      );
    });

    test('re-logging the same date overwrites the queued entry', () async {
      await moodSync.queueMoodLog(
        userId: 'user-1',
        date: DateTime.utc(2026, 7, 26),
        mood: 2,
      );
      final updated = await moodSync.queueMoodLog(
        userId: 'user-1',
        date: DateTime.utc(2026, 7, 26),
        mood: 5,
        notes: 'better now',
      );

      expect(moodSync.pendingCount, 1);
      expect(updated.mood, 5);
      expect(updated.notes, 'better now');
    });

    test('throws OfflineQueueFullException beyond 50 entries', () async {
      await storage.initialize();
      final firstDate = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < OfflineStorageService.maxPendingLogEntries; i++) {
        await storage.queueLogEntry(
          buildEntry(
            'id-$i',
            MoodSyncService.dateKey(firstDate.add(Duration(days: i))),
            DateTime.now(),
          ),
        );
      }
      expect(moodSync.pendingCount, 50);

      await expectLater(
        () => moodSync.queueMoodLog(
          userId: 'user-1',
          date: DateTime.utc(2026, 7, 26),
          mood: 3,
        ),
        throwsA(isA<OfflineQueueFullException>()),
      );
    });
  });

  group('pending queue ordering', () {
    test('getPendingLogEntries returns oldest first', () async {
      await storage.initialize();
      final now = DateTime(2026, 7, 26, 12);
      await storage.queueLogEntry(buildEntry('newest', '2026-07-26', now));
      await storage.queueLogEntry(
        buildEntry(
          'oldest',
          '2026-07-24',
          now.subtract(const Duration(days: 2)),
        ),
      );
      await storage.queueLogEntry(
        buildEntry(
          'middle',
          '2026-07-25',
          now.subtract(const Duration(days: 1)),
        ),
      );

      final pending = storage.getPendingLogEntries();
      expect(pending.map((e) => e.id).toList(), ['oldest', 'middle', 'newest']);
    });
  });

  group('auto-sync on reconnect', () {
    test(
      'syncs queued entries oldest first when connection restores',
      () async {
        await moodSync.start();
        expect(syncService.syncCalls, 0);

        await moodSync.queueMoodLog(
          userId: 'user-1',
          date: DateTime.utc(2026, 7, 25),
          mood: 2,
        );
        await moodSync.queueMoodLog(
          userId: 'user-1',
          date: DateTime.utc(2026, 7, 26),
          mood: 4,
        );
        expect(moodSync.pendingCount, 2);

        connectivity.online = true;
        connectivity.controller.add(true);
        await pumpEventQueue();

        expect(syncService.syncCalls, 1);
        expect(syncService.syncedDateBatches.single, [
          '2026-07-25',
          '2026-07-26',
        ]);
        expect(moodSync.pendingCount, 0);
      },
    );

    test('syncs at startup when already online with pending entries', () async {
      await moodSync.queueMoodLog(
        userId: 'user-1',
        date: DateTime.utc(2026, 7, 26),
        mood: 3,
      );

      connectivity.online = true;
      await moodSync.start();
      await pumpEventQueue();

      expect(syncService.syncCalls, 1);
      expect(moodSync.pendingCount, 0);
    });

    test('does not sync while still offline', () async {
      await moodSync.start();
      await moodSync.queueMoodLog(
        userId: 'user-1',
        date: DateTime.utc(2026, 7, 26),
        mood: 3,
      );

      connectivity.controller.add(false);
      await pumpEventQueue();

      expect(syncService.syncCalls, 0);
      expect(moodSync.pendingCount, 1);
    });
  });

  group('watchPendingCount', () {
    test(
      'emits current count immediately and updates on queue changes',
      () async {
        await storage.initialize();
        final emissions = <int>[];
        final sub = moodSync.watchPendingCount().listen(emissions.add);
        await pumpEventQueue();
        expect(emissions, [0]);

        await moodSync.queueMoodLog(
          userId: 'user-1',
          date: DateTime.utc(2026, 7, 26),
          mood: 3,
        );
        await pumpEventQueue();
        expect(emissions.last, 1);

        await sub.cancel();
      },
    );
  });
}
