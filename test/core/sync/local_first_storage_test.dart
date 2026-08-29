import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:echomirror/core/sync/local_first_storage_service.dart';
import 'package:echomirror/core/sync/sync_mutation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalFirstStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_first_storage_test');
    storage = LocalFirstStorageService(
      initializeHive: () async => Hive.init(tempDir.path),
      nodeId: 'test-node-1',
    );
    await storage.initialize();
  });

  tearDown(() async {
    await storage.clearAll();
    await storage.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalFirstStorageService', () {
    test('stages mutations and updates snapshot cache', () async {
      expect(storage.pendingCount, 0);

      final mutation = await storage.stageMutation(
        entityId: 'entry-2026-08-29',
        entityType: SyncEntityType.moodEntry,
        action: SyncMutationAction.create,
        payload: {
          'user_id': 'user-1',
          'date': '2026-08-29',
          'mood': 4,
          'habits': ['code', 'workout'],
          'notes': 'Offline day',
        },
        priority: SyncPriority.normal,
      );

      expect(storage.pendingCount, 1);
      expect(mutation.entityType, SyncEntityType.moodEntry);
      expect(mutation.status, SyncMutationStatus.pending);

      // Verify local snapshot was saved optimistically
      final snapshot = storage.getEntitySnapshot(
        SyncEntityType.moodEntry,
        'entry-2026-08-29',
      );
      expect(snapshot, isNotNull);
      expect(snapshot!['mood'], 4);
      expect(snapshot['habits'], ['code', 'workout']);
    });

    test('re-staging same pending entity merges and updates payload in place', () async {
      await storage.stageMutation(
        entityId: 'entry-2026-08-29',
        entityType: SyncEntityType.moodEntry,
        action: SyncMutationAction.create,
        payload: {
          'user_id': 'user-1',
          'date': '2026-08-29',
          'mood': 2,
          'habits': ['water'],
          'notes': 'Morning note',
        },
      );

      expect(storage.pendingCount, 1);

      // Re-stage later in the day
      final updatedMutation = await storage.stageMutation(
        entityId: 'entry-2026-08-29',
        entityType: SyncEntityType.moodEntry,
        action: SyncMutationAction.update,
        payload: {
          'user_id': 'user-1',
          'date': '2026-08-29',
          'mood': 5,
          'habits': ['meditation'],
          'notes': 'Evening note',
        },
      );

      expect(storage.pendingCount, 1);
      expect(updatedMutation.payload['mood'], 5);
      // Habits merged via Set-Union
      expect(updatedMutation.payload['habits'], ['meditation', 'water']);
    });

    test('getPendingMutations sorts high priority ahead of normal priority', () async {
      // Stage low/normal priority first
      await storage.stageMutation(
        entityId: 'story-1',
        entityType: SyncEntityType.story,
        action: SyncMutationAction.create,
        payload: {'title': 'Story'},
        priority: SyncPriority.low,
      );

      await storage.stageMutation(
        entityId: 'mood-1',
        entityType: SyncEntityType.moodEntry,
        action: SyncMutationAction.create,
        payload: {'mood': 3},
        priority: SyncPriority.normal,
      );

      // Stage high priority last
      await storage.stageMutation(
        entityId: 'follow-1',
        entityType: SyncEntityType.follow,
        action: SyncMutationAction.create,
        payload: {'target': 'user2'},
        priority: SyncPriority.high,
      );

      final pending = storage.getPendingMutations();
      expect(pending.length, 3);
      expect(pending[0].entityType, SyncEntityType.follow); // High priority first
      expect(pending[1].entityType, SyncEntityType.moodEntry); // Normal
      expect(pending[2].entityType, SyncEntityType.story); // Low
    });

    test('marking synced removes or marks mutations', () async {
      final mutation = await storage.stageMutation(
        entityId: 'gift-1',
        entityType: SyncEntityType.gift,
        action: SyncMutationAction.create,
        payload: {'amount': 10.0},
      );

      expect(storage.pendingCount, 1);

      await storage.markMutationSynced(mutation.id);
      expect(storage.pendingCount, 0);

      await storage.deleteMutation(mutation.id);
      expect(storage.getPendingMutations().isEmpty, isTrue);
    });
  });
}
