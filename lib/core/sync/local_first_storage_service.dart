import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hlc.dart';
import 'version_vector.dart';
import 'sync_mutation.dart';
import 'conflict_policy.dart';

/// Central local-first storage service managing the persistent mutation queue,
/// hybrid logical clocks, and local entity snapshots across all mutable entity types.
class LocalFirstStorageService {
  LocalFirstStorageService({
    Future<void> Function()? initializeHive,
    String? nodeId,
    String? boxPrefix,
  })  : _initializeHive = initializeHive ?? Hive.initFlutter,
        _nodeId = nodeId ?? _generateRandomNodeId(),
        _boxPrefix = boxPrefix ?? nodeId;

  static const String mutationsBoxName = 'local_first_mutations';
  static const String snapshotsBoxName = 'local_first_snapshots';
  static const String metadataBoxName = 'local_first_metadata';

  static const int maxPendingMutations = 200;

  final Future<void> Function() _initializeHive;
  final String? _boxPrefix;
  String _nodeId;

  late Box<SyncMutation> _mutationsBox;
  late Box<dynamic> _snapshotsBox;
  late Box<dynamic> _metadataBox;

  Future<void>? _initFuture;
  bool _initialized = false;
  Hlc? _latestHlc;
  VersionVector _versionVector = VersionVector();

  bool get isInitialized => _initialized;
  String get nodeId => _nodeId;
  Hlc? get latestHlc => _latestHlc;
  VersionVector get versionVector => _versionVector;

  /// Initializes local Hive storage and loads metadata/clocks. Idempotent.
  Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    await _initializeHive();

    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(SyncMutationAdapter());
    }

    final mBox = _boxPrefix != null ? '${_boxPrefix}_$mutationsBoxName' : mutationsBoxName;
    final sBox = _boxPrefix != null ? '${_boxPrefix}_$snapshotsBoxName' : snapshotsBoxName;
    final metaBox = _boxPrefix != null ? '${_boxPrefix}_$metadataBoxName' : metadataBoxName;

    _mutationsBox = await Hive.openBox<SyncMutation>(mBox);
    _snapshotsBox = await Hive.openBox<dynamic>(sBox);
    _metadataBox = await Hive.openBox<dynamic>(metaBox);

    // Restore or persist nodeId
    final savedNodeId = _metadataBox.get('node_id') as String?;
    if (savedNodeId != null && savedNodeId.isNotEmpty) {
      _nodeId = savedNodeId;
    } else {
      await _metadataBox.put('node_id', _nodeId);
    }

    // Restore latest HLC
    final savedHlcStr = _metadataBox.get('latest_hlc') as String?;
    if (savedHlcStr != null) {
      _latestHlc = Hlc.tryParse(savedHlcStr);
    }

    // Restore version vector
    final savedVv = _metadataBox.get('version_vector') as Map?;
    if (savedVv != null) {
      _versionVector = VersionVector.fromMap(savedVv);
    }

    _initialized = true;
  }

  /// Generates the next monotonic [Hlc] for this node and advances internal state.
  Hlc tickHlc() {
    final nextHlc = Hlc.now(_nodeId, latestKnown: _latestHlc);
    _latestHlc = nextHlc;
    _versionVector = _versionVector.increment(_nodeId);
    unawaited(_persistClockState());
    return nextHlc;
  }

  /// Updates local clock state upon observing a remote timestamp.
  void observeRemoteHlc(Hlc remoteHlc, [VersionVector? remoteVector]) {
    final local = _latestHlc ?? Hlc.now(_nodeId);
    _latestHlc = Hlc.receive(local, remoteHlc, _nodeId);
    if (remoteVector != null) {
      _versionVector = _versionVector.merge(remoteVector);
    }
    unawaited(_persistClockState());
  }

  Future<void> _persistClockState() async {
    if (!_initialized) return;
    try {
      if (_metadataBox.isOpen) {
        if (_latestHlc != null) {
          await _metadataBox.put('latest_hlc', _latestHlc!.toJsonString());
        }
        await _metadataBox.put('version_vector', _versionVector.toMap());
      }
    } catch (_) {
      // Ignored if box was closed during teardown
    }
  }

  /// Stages a local mutation to be synchronized to the backend.
  ///
  /// Optimistically applies the mutation to the local snapshot table and
  /// appends/merges it into the pending mutation queue.
  Future<SyncMutation> stageMutation({
    required String entityId,
    required SyncEntityType entityType,
    required SyncMutationAction action,
    required Map<String, dynamic> payload,
    SyncPriority priority = SyncPriority.normal,
  }) async {
    await initialize();

    final hlc = tickHlc();

    // Check if an existing pending mutation for the same entity exists
    final existingIndex = _mutationsBox.values.toList().indexWhere(
      (m) =>
          m.entityType == entityType &&
          m.entityId == entityId &&
          m.status != SyncMutationStatus.synced,
    );

    SyncMutation mutation;
    if (existingIndex != -1) {
      final existing = _mutationsBox.getAt(existingIndex)!;
      // Merge payload according to entity conflict policy
      final policy = ConflictPolicyRegistry.getPolicy(entityType);
      final merged = policy.resolve(
        local: existing.payload,
        remote: payload,
        localHlc: existing.parsedHlc,
        remoteHlc: hlc,
      );

      existing
        ..payload = merged.resolvedData
        ..action = action
        ..hlc = hlc.toJsonString()
        ..versionVector = _versionVector.toMap()
        ..updatedAt = DateTime.now().toUtc()
        ..status = SyncMutationStatus.pending
        ..priority = priority;

      await existing.save();
      mutation = existing;
    } else {
      if (_mutationsBox.length >= maxPendingMutations) {
        // Prune oldest synced if any
        final syncedKeys = _mutationsBox.values
            .where((m) => m.status == SyncMutationStatus.synced)
            .map((m) => m.id)
            .toList();
        for (final k in syncedKeys) {
          await _mutationsBox.delete(k);
        }
      }

      mutation = SyncMutation(
        id: generateUuidV4(),
        entityId: entityId,
        entityType: entityType,
        action: action,
        payload: payload,
        hlc: hlc.toJsonString(),
        versionVector: _versionVector.toMap(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        status: SyncMutationStatus.pending,
        priority: priority,
      );
      await _mutationsBox.put(mutation.id, mutation);
    }

    // Optimistically update local snapshot
    if (action == SyncMutationAction.delete) {
      await deleteEntitySnapshot(entityType, entityId);
    } else {
      await saveEntitySnapshot(entityType, entityId, payload);
    }

    debugPrint(
      '[LocalFirstStorageService] Staged mutation for '
      '${entityType.name} ($entityId) at HLC: ${hlc.toJsonString()}',
    );

    return mutation;
  }

  /// Returns unsynced mutations ordered by priority (high first), then HLC (oldest first).
  List<SyncMutation> getPendingMutations({
    SyncPriority? priority,
    SyncEntityType? entityType,
  }) {
    if (!_initialized) return [];
    var pending = _mutationsBox.values
        .where((m) => m.status != SyncMutationStatus.synced)
        .toList();

    if (priority != null) {
      pending = pending.where((m) => m.priority == priority).toList();
    }
    if (entityType != null) {
      pending = pending.where((m) => m.entityType == entityType).toList();
    }

    pending.sort((a, b) {
      // High priority first (index 0 < index 1 < index 2)
      if (a.priority.index != b.priority.index) {
        return a.priority.index.compareTo(b.priority.index);
      }
      return a.parsedHlc.compareTo(b.parsedHlc);
    });

    return pending;
  }

  int get pendingCount =>
      _initialized
          ? _mutationsBox.values
              .where((m) => m.status != SyncMutationStatus.synced)
              .length
          : 0;

  Stream<int> watchPendingCount() async* {
    await initialize();
    yield pendingCount;
    yield* _mutationsBox.watch().map((_) => pendingCount);
  }

  Future<void> markMutationSynced(String mutationId) async {
    final mutation = _mutationsBox.get(mutationId);
    if (mutation != null) {
      mutation.status = SyncMutationStatus.synced;
      mutation.updatedAt = DateTime.now().toUtc();
      await mutation.save();
    }
  }

  Future<void> markMutationFailed(String mutationId, String error) async {
    final mutation = _mutationsBox.get(mutationId);
    if (mutation != null) {
      mutation.status = SyncMutationStatus.failed;
      mutation.retryCount += 1;
      mutation.errorMessage = error;
      mutation.updatedAt = DateTime.now().toUtc();
      await mutation.save();
    }
  }

  Future<void> deleteMutation(String mutationId) async {
    await _mutationsBox.delete(mutationId);
  }

  // ================= Entity Snapshots =================

  String _snapshotKey(SyncEntityType type, String entityId) =>
      '${type.name}:$entityId';

  Future<void> saveEntitySnapshot(
    SyncEntityType type,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    await initialize();
    await _snapshotsBox.put(_snapshotKey(type, entityId), data);
  }

  Map<String, dynamic>? getEntitySnapshot(
    SyncEntityType type,
    String entityId,
  ) {
    if (!_initialized) return null;
    final raw = _snapshotsBox.get(_snapshotKey(type, entityId));
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    return null;
  }

  List<Map<String, dynamic>> getAllEntitySnapshots(SyncEntityType type) {
    if (!_initialized) return [];
    final prefix = '${type.name}:';
    final results = <Map<String, dynamic>>[];
    for (final key in _snapshotsBox.keys) {
      if (key.toString().startsWith(prefix)) {
        final val = _snapshotsBox.get(key);
        if (val is Map) {
          results.add(val.cast<String, dynamic>());
        }
      }
    }
    return results;
  }

  Future<void> deleteEntitySnapshot(
    SyncEntityType type,
    String entityId,
  ) async {
    await initialize();
    await _snapshotsBox.delete(_snapshotKey(type, entityId));
  }

  Future<void> clearAll() async {
    await initialize();
    if (_mutationsBox.isOpen) await _mutationsBox.clear();
    if (_snapshotsBox.isOpen) await _snapshotsBox.clear();
    if (_metadataBox.isOpen) await _metadataBox.clear();
    _latestHlc = null;
    _versionVector = VersionVector();
  }

  Future<void> close() async {
    if (_initialized) {
      if (_mutationsBox.isOpen) await _mutationsBox.close();
      if (_snapshotsBox.isOpen) await _snapshotsBox.close();
      if (_metadataBox.isOpen) await _metadataBox.close();
      _initialized = false;
      _initFuture = null;
    }
  }

  static String _generateRandomNodeId() {
    final rng = Random();
    return 'node_${rng.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  static String generateUuidV4({Random? random}) {
    final rng = random ?? _random;
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static final Random _random = Random.secure();
}

/// Provider for local-first storage service.
final localFirstStorageServiceProvider =
    Provider<LocalFirstStorageService>((ref) {
  return LocalFirstStorageService();
});
