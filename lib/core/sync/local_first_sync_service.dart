import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/connectivity_service.dart';
import 'background_sync_scheduler.dart';
import 'conflict_policy.dart';
import 'hlc.dart';
import 'local_first_storage_service.dart';
import 'remote_sync_adapter.dart';
import 'sync_mutation.dart';
import 'version_vector.dart';

/// Summary outcome of a [LocalFirstSyncService.syncAllPending] cycle.
class LocalFirstSyncResult {
  const LocalFirstSyncResult({
    this.syncedCount = 0,
    this.failedCount = 0,
    this.conflictsResolved = 0,
    this.rateLimited = false,
  });

  final int syncedCount;
  final int failedCount;
  final int conflictsResolved;
  final bool rateLimited;

  bool get isSuccess => failedCount == 0 && !rateLimited;

  @override
  String toString() =>
      'LocalFirstSyncResult(synced: $syncedCount, failed: $failedCount, '
      'conflicts: $conflictsResolved, rateLimited: $rateLimited)';
}

/// Unified local-first synchronization coordinator across all mutable entity types.
class LocalFirstSyncService {
  LocalFirstSyncService({
    required this.storage,
    required this.remoteAdapter,
    required this.connectivity,
    BackgroundSyncScheduler? scheduler,
  }) : _scheduler = scheduler ?? BackgroundSyncScheduler(connectivity: connectivity);

  final LocalFirstStorageService storage;
  final RemoteSyncAdapter remoteAdapter;
  final ConnectivityService connectivity;
  final BackgroundSyncScheduler _scheduler;

  bool _started = false;
  bool _syncInProgress = false;
  bool _syncRequestedWhileRunning = false;

  BackgroundSyncScheduler get scheduler => _scheduler;

  /// Starts the storage service, registers with the background sync scheduler,
  /// and runs an initial sync if online.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await storage.initialize();
    await _scheduler.start(() => syncAllPending());
  }

  void dispose() {
    _scheduler.dispose();
    _started = false;
  }

  /// Syncs all pending mutations, ordered by priority (high priority first)
  /// and causal HLC (oldest first). Coalesces concurrent calls.
  Future<LocalFirstSyncResult> syncAllPending({
    SyncPriority? priority,
    SyncEntityType? entityType,
  }) async {
    if (_syncInProgress) {
      _syncRequestedWhileRunning = true;
      return const LocalFirstSyncResult();
    }

    _syncInProgress = true;
    try {
      var result = await _executeSyncRun(priority: priority, entityType: entityType);
      while (_syncRequestedWhileRunning) {
        _syncRequestedWhileRunning = false;
        result = await _executeSyncRun(priority: priority, entityType: entityType);
      }
      _scheduler.recordOutcome(
        success: result.isSuccess,
        rateLimited: result.rateLimited,
      );
      return result;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<LocalFirstSyncResult> _executeSyncRun({
    SyncPriority? priority,
    SyncEntityType? entityType,
  }) async {
    await storage.initialize();
    final pending = storage.getPendingMutations(
      priority: priority,
      entityType: entityType,
    );

    if (pending.isEmpty) {
      return const LocalFirstSyncResult();
    }

    int synced = 0;
    int failed = 0;
    int conflicts = 0;

    for (final mutation in pending) {
      try {
        mutation.status = SyncMutationStatus.inFlight;
        await mutation.save();

        // 1. Fetch remote state to detect concurrency/conflicts
        final remote = await remoteAdapter.fetchRemoteEntity(
          mutation.entityType,
          mutation.entityId,
          mutation.payload,
        );

        Map<String, dynamic> payloadToPush = mutation.payload;

        if (remote != null) {
          // Parse remote HLC or default from remote updated_at
          final remoteHlcStr = remote['hlc']?.toString();
          final remoteHlc = Hlc.tryParse(remoteHlcStr) ??
              Hlc(
                millis: (DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
                        DateTime.now())
                    .millisecondsSinceEpoch,
                counter: 0,
                nodeId: 'server',
              );

          final remoteVv = VersionVector.fromMap(
            remote['version_vector'] as Map?,
          );

          // Update local clock observing remote
          storage.observeRemoteHlc(remoteHlc, remoteVv);

          // Evaluate conflict policy
          final policy = ConflictPolicyRegistry.getPolicy(mutation.entityType);
          final resolution = policy.resolve(
            local: mutation.payload,
            remote: remote,
            localHlc: mutation.parsedHlc,
            remoteHlc: remoteHlc,
            localVector: mutation.parsedVersionVector,
            remoteVector: remoteVv,
          );

          payloadToPush = resolution.resolvedData;
          if (resolution.hasConflict) {
            conflicts++;
            debugPrint(
              '[LocalFirstSyncService] Resolved conflict for ${mutation.entityType.name} '
              '(${mutation.entityId}): ${resolution.conflictDescription}',
            );
          }
        }

        // 2. Attach updated HLC metadata to payload
        payloadToPush['hlc'] = mutation.hlc;
        payloadToPush['version_vector'] = mutation.versionVector;

        // 3. Push to remote backend
        await remoteAdapter.pushMutation(mutation, payloadToPush);

        // 4. Update local snapshot and mark synced
        await storage.saveEntitySnapshot(
          mutation.entityType,
          mutation.entityId,
          payloadToPush,
        );
        await storage.deleteMutation(mutation.id);
        synced++;
      } on PostgrestException catch (e) {
        if (e.code == 'PT429') {
          debugPrint('[LocalFirstSyncService] Server rate limit encountered (PT429)');
          await storage.markMutationFailed(mutation.id, 'PT429 rate limit');
          return LocalFirstSyncResult(
            syncedCount: synced,
            failedCount: failed + (pending.length - synced - failed),
            conflictsResolved: conflicts,
            rateLimited: true,
          );
        }
        debugPrint('[LocalFirstSyncService] Postgrest error syncing ${mutation.id}: $e');
        await storage.markMutationFailed(mutation.id, e.message);
        failed++;
      } catch (e) {
        debugPrint('[LocalFirstSyncService] Error syncing mutation ${mutation.id}: $e');
        await storage.markMutationFailed(mutation.id, e.toString());
        failed++;
      }
    }

    debugPrint(
      '[LocalFirstSyncService] Sync finished: $synced synced, '
      '$failed failed, $conflicts conflicts resolved',
    );

    return LocalFirstSyncResult(
      syncedCount: synced,
      failedCount: failed,
      conflictsResolved: conflicts,
    );
  }

  /// Pulls remote updates and merges them cleanly into local storage.
  Future<int> pullAndMerge(SyncEntityType type, {DateTime? since, int? limit}) async {
    await storage.initialize();
    try {
      final remoteRows = await remoteAdapter.pullRemoteChanges(
        type,
        since: since,
        limit: limit,
      );

      int mergedCount = 0;
      for (final row in remoteRows) {
        final entityId = (row['id'] ?? row['date'] ?? '').toString();
        if (entityId.isEmpty) continue;

        final localSnapshot = storage.getEntitySnapshot(type, entityId);
        if (localSnapshot == null) {
          await storage.saveEntitySnapshot(type, entityId, row);
          mergedCount++;
        } else {
          final localHlc = Hlc.tryParse(localSnapshot['hlc']?.toString()) ??
              storage.latestHlc ??
              Hlc.now(storage.nodeId);
          final remoteHlc = Hlc.tryParse(row['hlc']?.toString()) ??
              Hlc(
                millis: (DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                        DateTime.now())
                    .millisecondsSinceEpoch,
                counter: 0,
                nodeId: 'server',
              );

          final policy = ConflictPolicyRegistry.getPolicy(type);
          final resolution = policy.resolve(
            local: localSnapshot,
            remote: row,
            localHlc: localHlc,
            remoteHlc: remoteHlc,
          );

          await storage.saveEntitySnapshot(type, entityId, resolution.resolvedData);
          storage.observeRemoteHlc(remoteHlc);
          mergedCount++;
        }
      }
      return mergedCount;
    } catch (e) {
      debugPrint('[LocalFirstSyncService] Pull error for $type: $e');
      return 0;
    }
  }
}

/// Provider for [RemoteSyncAdapter].
final remoteSyncAdapterProvider = Provider<RemoteSyncAdapter>((ref) {
  return SupabaseRemoteSyncAdapter();
});

/// Provider for [LocalFirstSyncService].
final localFirstSyncServiceProvider = Provider<LocalFirstSyncService>((ref) {
  final service = LocalFirstSyncService(
    storage: ref.watch(localFirstStorageServiceProvider),
    remoteAdapter: ref.watch(remoteSyncAdapterProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    scheduler: ref.watch(backgroundSyncSchedulerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Initializer provider for starting local-first synchronization at app boot.
final localFirstSyncInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(localFirstSyncServiceProvider).start();
});

/// Stream of all pending local-first mutations count.
final pendingLocalMutationsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(localFirstStorageServiceProvider).watchPendingCount();
});
