import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echomirror/core/services/connectivity_service.dart';
import 'package:echomirror/core/sync/conflict_policy.dart';
import 'package:echomirror/core/sync/hlc.dart';
import 'package:echomirror/core/sync/local_first_storage_service.dart';
import 'package:echomirror/core/sync/local_first_sync_service.dart';
import 'package:echomirror/core/sync/remote_sync_adapter.dart';
import 'package:echomirror/core/sync/sync_mutation.dart';

/// Simulated remote Supabase backend maintaining real server state across test devices.
class SimulatedRemoteServerAdapter implements RemoteSyncAdapter {
  final Map<String, Map<String, dynamic>> logEntriesTable = {};
  final Map<String, Map<String, dynamic>> followsTable = {};
  final Map<String, Map<String, dynamic>> storiesTable = {};
  final Map<String, Map<String, dynamic>> giftsTable = {};

  bool isOnline = true;
  int droppedRequestsRemaining = 0;
  bool returnRateLimitOnce = false;

  @override
  Future<Map<String, dynamic>?> fetchRemoteEntity(
    SyncEntityType type,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    _checkNetwork();
    switch (type) {
      case SyncEntityType.moodEntry:
      case SyncEntityType.habitLog:
        final userId = payload['user_id']?.toString() ?? '';
        final date = payload['date']?.toString() ?? '';
        final key = '$userId:$date';
        final row = logEntriesTable[key] ?? logEntriesTable[entityId];
        return row != null ? Map<String, dynamic>.from(row) : null;

      case SyncEntityType.follow:
        final followerId = payload['follower_id']?.toString() ?? '';
        final followingId = payload['following_id']?.toString() ?? '';
        final key = '$followerId:$followingId';
        final row = followsTable[key];
        return row != null ? Map<String, dynamic>.from(row) : null;

      case SyncEntityType.story:
        final row = storiesTable[entityId];
        return row != null ? Map<String, dynamic>.from(row) : null;

      case SyncEntityType.gift:
        final row = giftsTable[entityId];
        return row != null ? Map<String, dynamic>.from(row) : null;

      case SyncEntityType.moodPin:
      case SyncEntityType.moodComment:
        return null;
    }
  }

  @override
  Future<void> pushMutation(
    SyncMutation mutation,
    Map<String, dynamic> payload,
  ) async {
    _checkNetwork();
    switch (mutation.entityType) {
      case SyncEntityType.moodEntry:
      case SyncEntityType.habitLog:
        final userId = payload['user_id']?.toString() ?? '';
        final date = payload['date']?.toString() ?? '';
        final key = '$userId:$date';
        if (mutation.action == SyncMutationAction.delete) {
          logEntriesTable.remove(key);
        } else {
          logEntriesTable[key] = Map<String, dynamic>.from(payload);
        }
        break;

      case SyncEntityType.follow:
        final followerId = payload['follower_id']?.toString() ?? '';
        final followingId = payload['following_id']?.toString() ?? '';
        final key = '$followerId:$followingId';
        if (mutation.action == SyncMutationAction.delete) {
          followsTable.remove(key);
        } else {
          followsTable[key] = Map<String, dynamic>.from(payload);
        }
        break;

      case SyncEntityType.story:
        if (mutation.action == SyncMutationAction.delete) {
          storiesTable.remove(mutation.entityId);
        } else {
          storiesTable[mutation.entityId] = Map<String, dynamic>.from(payload);
        }
        break;

      case SyncEntityType.gift:
        giftsTable[mutation.entityId] = Map<String, dynamic>.from(payload);
        break;

      case SyncEntityType.moodPin:
      case SyncEntityType.moodComment:
        break;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullRemoteChanges(
    SyncEntityType type, {
    DateTime? since,
    int? limit,
  }) async {
    _checkNetwork();
    switch (type) {
      case SyncEntityType.moodEntry:
      case SyncEntityType.habitLog:
        return logEntriesTable.values.map(Map<String, dynamic>.from).toList();
      case SyncEntityType.follow:
        return followsTable.values.map(Map<String, dynamic>.from).toList();
      case SyncEntityType.story:
        return storiesTable.values.map(Map<String, dynamic>.from).toList();
      case SyncEntityType.gift:
        return giftsTable.values.map(Map<String, dynamic>.from).toList();
      case SyncEntityType.moodPin:
      case SyncEntityType.moodComment:
        return [];
    }
  }

  void _checkNetwork() {
    if (!isOnline) {
      throw const SocketException('Simulated network offline');
    }
    if (droppedRequestsRemaining > 0) {
      droppedRequestsRemaining--;
      throw const SocketException('Simulated packet drop / timeout');
    }
    if (returnRateLimitOnce) {
      returnRateLimitOnce = false;
      throw const PostgrestException(
        message: 'Rate limit exceeded',
        code: 'PT429',
      );
    }
  }
}

class _TestConnectivityService extends ConnectivityService {
  final StreamController<bool> _ctrl = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  Stream<bool> get onStatusChange => _ctrl.stream;

  @override
  Future<bool> isConnected() async => _online;

  void setOnline(bool online) {
    _online = online;
    _ctrl.add(online);
  }

  Future<void> dispose() async {
    await _ctrl.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory rootTempDir;
  late SimulatedRemoteServerAdapter server;

  setUp(() async {
    rootTempDir = await Directory.systemTemp.createTemp('sync_simulation_test');
    server = SimulatedRemoteServerAdapter();
  });

  tearDown(() async {
    if (rootTempDir.existsSync()) {
      await rootTempDir.delete(recursive: true);
    }
  });

  group('Multi-Device & Flaky Connectivity Convergence Simulation', () {
    test(
      'multi-entity concurrent offline edits across Device A and Device B '
      'eventually converge with zero silently lost writes',
      () async {
        // 1. Initialize Device A
        final dirA = Directory('${rootTempDir.path}/deviceA')..createSync();
        final connectivityA = _TestConnectivityService();
        final storageA = LocalFirstStorageService(
          initializeHive: () async => Hive.init(dirA.path),
          nodeId: 'device-A',
        );
        final syncA = LocalFirstSyncService(
          storage: storageA,
          remoteAdapter: server,
          connectivity: connectivityA,
        );
        await syncA.start();

        // 2. Initialize Device B
        final dirB = Directory('${rootTempDir.path}/deviceB')..createSync();
        final connectivityB = _TestConnectivityService();
        final storageB = LocalFirstStorageService(
          initializeHive: () async => Hive.init(dirB.path),
          nodeId: 'device-B',
        );
        final syncB = LocalFirstSyncService(
          storage: storageB,
          remoteAdapter: server,
          connectivity: connectivityB,
        );
        await syncB.start();

        // --- PHASE 1: GO OFFLINE ON BOTH DEVICES ---
        connectivityA.setOnline(false);
        connectivityB.setOnline(false);
        server.isOnline = false;

        // Device A logs mood offline
        await storageA.stageMutation(
          entityId: 'entry_2026-08-29',
          entityType: SyncEntityType.moodEntry,
          action: SyncMutationAction.create,
          payload: {
            'id': 'entry_2026-08-29',
            'user_id': 'user_test',
            'date': '2026-08-29',
            'mood': 3,
            'habits': ['running', 'meditation'],
            'notes': 'Device A reflection: Great morning run in the park.',
            'updated_at': '2026-08-29T08:00:00.000Z',
          },
          priority: SyncPriority.high,
        );

        // Device A follows a friend offline
        await storageA.stageMutation(
          entityId: 'user_test:user_friend_1',
          entityType: SyncEntityType.follow,
          action: SyncMutationAction.create,
          payload: {
            'follower_id': 'user_test',
            'following_id': 'user_friend_1',
            'created_at': '2026-08-29T08:05:00.000Z',
          },
          priority: SyncPriority.high,
        );

        // Device A sends a gift offline
        await storageA.stageMutation(
          entityId: 'gift_tx_001',
          entityType: SyncEntityType.gift,
          action: SyncMutationAction.create,
          payload: {
            'id': 'gift_tx_001',
            'sender_user_id': 'user_test',
            'recipient_user_id': 'user_friend_1',
            'echo_amount': 25.0,
            'stellar_tx_hash': 'tx_hash_device_a_123',
            'status': 'completed',
          },
          priority: SyncPriority.normal,
        );

        // Device B logs concurrent mood & habit edit for the same day offline
        // (Device B logs higher mood and different habits + distinct notes)
        await storageB.stageMutation(
          entityId: 'entry_2026-08-29',
          entityType: SyncEntityType.moodEntry,
          action: SyncMutationAction.create,
          payload: {
            'id': 'entry_2026-08-29',
            'user_id': 'user_test',
            'date': '2026-08-29',
            'mood': 5,
            'habits': ['reading', 'meditation'],
            'notes': 'Device B reflection: Calm evening reading and deep focus.',
            'updated_at': '2026-08-29T20:00:00.000Z',
          },
          priority: SyncPriority.high,
        );

        // Device B follows a second friend offline
        await storageB.stageMutation(
          entityId: 'user_test:user_friend_2',
          entityType: SyncEntityType.follow,
          action: SyncMutationAction.create,
          payload: {
            'follower_id': 'user_test',
            'following_id': 'user_friend_2',
            'created_at': '2026-08-29T20:05:00.000Z',
          },
          priority: SyncPriority.high,
        );

        // Device B creates a story interaction offline
        await storageB.stageMutation(
          entityId: 'story_777',
          entityType: SyncEntityType.story,
          action: SyncMutationAction.create,
          payload: {
            'id': 'story_777',
            'user_id': 'user_test',
            'view_count': 1,
            'viewed_by': ['viewer_alpha'],
            'is_active': true,
          },
          priority: SyncPriority.low,
        );

        expect(storageA.pendingCount, 3);
        expect(storageB.pendingCount, 3);

        // --- PHASE 2: FLAKY CONNECTIVITY FOR DEVICE A ---
        server.isOnline = true;
        connectivityA.setOnline(true);

        // Inject transient packet drop + rate limit on first sync attempt
        server.droppedRequestsRemaining = 1;
        final firstAttempt = await syncA.syncAllPending();
        expect(firstAttempt.isSuccess, isFalse);
        expect(storageA.pendingCount, greaterThan(0));

        // Let flaky network stabilize and re-sync Device A
        server.droppedRequestsRemaining = 0;
        final secondAttempt = await syncA.syncAllPending();
        expect(secondAttempt.isSuccess, isTrue);
        expect(storageA.pendingCount, 0);

        // Verify Device A writes are on server
        expect(server.logEntriesTable.containsKey('user_test:2026-08-29'), isTrue);
        expect(server.followsTable.containsKey('user_test:user_friend_1'), isTrue);
        expect(server.giftsTable.containsKey('gift_tx_001'), isTrue);

        // --- PHASE 3: DEVICE B RECONNECTS AND SYNCS ---
        connectivityB.setOnline(true);
        final syncResultB = await syncB.syncAllPending();
        expect(syncResultB.isSuccess, isTrue);
        expect(storageB.pendingCount, 0);
        expect(syncResultB.conflictsResolved, greaterThanOrEqualTo(1));

        // --- PHASE 4: VERIFY PRINCIPLED CONVERGENCE ON SERVER ---
        final serverMoodLog = server.logEntriesTable['user_test:2026-08-29']!;

        // 1. Mood rating: Device B's newer edit (5) won LWW
        expect(serverMoodLog['mood'], 5);

        // 2. Habits: Set-Union of Device A (running, meditation) and Device B (reading, meditation)
        final habits = (serverMoodLog['habits'] as List).cast<String>();
        expect(habits, containsAll(['meditation', 'reading', 'running']));

        // 3. Notes: LWW-CS preserved Device B's note as primary and surfaced Device A's note in backup metadata
        expect(serverMoodLog['notes'], 'Device B reflection: Calm evening reading and deep focus.');
        expect(serverMoodLog['conflict_surfaced'], isTrue);
        expect(
          serverMoodLog['conflicted_note_backup'],
          'Device A reflection: Great morning run in the park.',
        );

        // 4. Follows: Both friend_1 and friend_2 follows exist on server
        expect(server.followsTable.containsKey('user_test:user_friend_1'), isTrue);
        expect(server.followsTable.containsKey('user_test:user_friend_2'), isTrue);

        // 5. Gifts & Stories: Both present
        expect(server.giftsTable['gift_tx_001']?['status'], 'completed');
        expect(server.storiesTable['story_777']?['view_count'], 1);

        // --- PHASE 5: DEVICE A PULLS AND CONVERGES TO SAME STATE ---
        final pullCount = await syncA.pullAndMerge(SyncEntityType.moodEntry);
        expect(pullCount, greaterThanOrEqualTo(1));

        final snapshotA = storageA.getEntitySnapshot(
          SyncEntityType.moodEntry,
          'entry_2026-08-29',
        );
        expect(snapshotA, isNotNull);
        expect(snapshotA!['mood'], 5);
        expect(
          (snapshotA['habits'] as List).cast<String>(),
          containsAll(['meditation', 'reading', 'running']),
        );
        expect(snapshotA['conflict_surfaced'], isTrue);

        // Clean teardown
        syncA.dispose();
        syncB.dispose();
        await connectivityA.dispose();
        await connectivityB.dispose();
        await storageA.close();
        await storageB.close();
      },
    );
  });
}
