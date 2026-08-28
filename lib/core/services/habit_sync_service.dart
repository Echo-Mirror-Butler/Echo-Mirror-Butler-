import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/local_models.dart';
import 'connectivity_service.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';

/// Coordinates the offline habit log queue: queues entries while offline and
/// auto-syncs them (oldest first) when connectivity is restored.
///
/// Follows the same pattern as MoodSyncService to provide consistent
/// offline behavior across mood and habit logging.
class HabitSyncService {
  HabitSyncService({
    required this.offlineStorage,
    required this.syncService,
    required this.connectivity,
  });

  final OfflineStorageService offlineStorage;
  final SyncService syncService;
  final ConnectivityService connectivity;

  StreamSubscription<bool>? _connectivitySub;
  bool _started = false;
  bool _syncInProgress = false;
  bool _syncRequestedWhileRunning = false;

  /// Open local storage and begin watching connectivity. On every
  /// offline→online transition (and once at startup if already online) any
  /// queued habit entries are pushed to the server. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await offlineStorage.initialize();

    _connectivitySub = connectivity.onStatusChange.listen((online) {
      if (online) {
        unawaited(syncPending());
      }
    });

    if (await connectivity.isConnected()) {
      unawaited(syncPending());
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _started = false;
  }

  /// Queue a habit log locally for later sync.
  ///
  /// Re-logging a date that is already queued overwrites the queued entry.
  /// Throws [OfflineQueueFullException] when the queue already holds
  /// [OfflineStorageService.maxPendingLogEntries] entries.
  Future<LocalLogEntry> queueHabitLog({
    required String userId,
    required DateTime date,
    required List<String> habits,
    int? mood,
    String? notes,
  }) async {
    await offlineStorage.initialize();
    final now = DateTime.now();
    final entry = LocalLogEntry(
      id: generateUuidV4(),
      userId: userId,
      date: dateKey(date),
      mood: mood,
      habits: List<String>.from(habits),
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    final queued = await offlineStorage.queueLogEntry(entry);
    debugPrint(
      '[HabitSyncService] queued habit log for ${queued.date} '
      '(pending: $pendingCount)',
    );
    return queued;
  }

  /// Number of entries waiting to be synced (for the pending badge).
  int get pendingCount => offlineStorage.pendingLogEntryCount;

  /// Emits the pending count immediately and after every queue change.
  Stream<int> watchPendingCount() => offlineStorage.watchPendingLogEntryCount();

  /// Push queued entries to the server, oldest first. Concurrent calls are
  /// coalesced: a call made while a run is in flight schedules one follow-up
  /// run instead of racing it.
  Future<SyncResult> syncPending() async {
    if (_syncInProgress) {
      _syncRequestedWhileRunning = true;
      return const SyncResult();
    }
    _syncInProgress = true;
    try {
      var result = await syncService.syncPendingEntries();
      while (_syncRequestedWhileRunning) {
        _syncRequestedWhileRunning = false;
        result = await syncService.syncPendingEntries();
      }
      if (result.syncedCount > 0 || result.failedCount > 0) {
        debugPrint(
          '[HabitSyncService] sync finished: ${result.syncedCount} synced, '
          '${result.failedCount} failed'
          '${result.rateLimited ? ' (rate limited)' : ''}',
        );
      }
      return result;
    } finally {
      _syncInProgress = false;
    }
  }

  /// Date-only key in `YYYY-MM-DD` (UTC), matching the `log_entries.date`
  /// convention used by LoggingRepository.
  static String dateKey(DateTime date) {
    final utcDate = date.isUtc
        ? date
        : DateTime.utc(date.year, date.month, date.day);
    final year = utcDate.year.toString().padLeft(4, '0');
    final month = utcDate.month.toString().padLeft(2, '0');
    final day = utcDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// RFC 4122 version 4 UUID. Hand-rolled to avoid a dependency on the
  /// `uuid` package; entry ids must be valid UUIDs because `log_entries.id`
  /// is a Postgres uuid column.
  static String generateUuidV4({Random? random}) {
    final rng = random ?? _random;
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static final Random _random = Random.secure();
}

/// Habit sync service provider (kept alive for the app's lifetime so the
/// connectivity subscription survives).
final habitSyncServiceProvider = Provider<HabitSyncService>((ref) {
  final service = HabitSyncService(
    offlineStorage: ref.watch(offlineStorageServiceProvider),
    syncService: ref.watch(syncServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Starts the habit sync service (open storage + watch connectivity).
/// Watched once from the app root, mirroring moodSyncInitProvider.
final habitSyncInitProvider = FutureProvider<void>((ref) {
  return ref.watch(habitSyncServiceProvider).start();
});

/// Pending (unsynced) habit log count, for the badge UI.
final pendingHabitLogCountProvider = StreamProvider<int>((ref) {
  return ref.watch(habitSyncServiceProvider).watchPendingCount();
});
