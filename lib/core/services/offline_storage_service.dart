import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/local_models.dart';

/// Thrown when the offline mood log queue already holds
/// [OfflineStorageService.maxPendingLogEntries] unsynced entries.
class OfflineQueueFullException implements Exception {
  const OfflineQueueFullException();

  @override
  String toString() =>
      'Offline queue is full '
      '(max ${OfflineStorageService.maxPendingLogEntries} pending entries)';
}

/// Local Hive-backed storage for offline support: the pending mood log queue,
/// plus cached user profile and dashboard snapshots.
class OfflineStorageService {
  OfflineStorageService({Future<void> Function()? initializeHive})
    : _initializeHive = initializeHive ?? Hive.initFlutter;

  static const String logEntriesBoxName = 'local_log_entries';
  static const String userProfileBoxName = 'local_user_profile';
  static const String dashboardBoxName = 'local_dashboard_snapshot';

  /// Maximum number of unsynced log entries kept in the offline queue.
  static const int maxPendingLogEntries = 50;

  final Future<void> Function() _initializeHive;

  late Box<LocalLogEntry> _logEntriesBox;
  late Box<LocalUserProfile> _userProfileBox;
  late Box<LocalDashboardSnapshot> _dashboardBox;

  Future<void>? _initFuture;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Idempotent — safe to call from multiple providers; the first call wins
  /// and later calls await the same future.
  Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    await _initializeHive();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LocalLogEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LocalUserProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LocalDashboardSnapshotAdapter());
    }
    _logEntriesBox = await Hive.openBox<LocalLogEntry>(logEntriesBoxName);
    _userProfileBox = await Hive.openBox<LocalUserProfile>(userProfileBoxName);
    _dashboardBox = await Hive.openBox<LocalDashboardSnapshot>(
      dashboardBoxName,
    );
    _initialized = true;
  }

  /// Queue a log entry for later sync.
  ///
  /// If a pending entry already exists for the same user and date it is
  /// overwritten in place (one log per day, matching the server convention),
  /// so re-logging the same day offline never consumes extra queue slots.
  /// Throws [OfflineQueueFullException] when the queue holds
  /// [maxPendingLogEntries] entries for other dates.
  Future<LocalLogEntry> queueLogEntry(LocalLogEntry entry) async {
    final existing = _findPendingByDate(entry.userId, entry.date);
    if (existing != null) {
      existing
        ..mood = entry.mood
        ..habits = entry.habits
        ..notes = entry.notes
        ..updatedAt = entry.updatedAt;
      await existing.save();
      return existing;
    }
    if (pendingLogEntryCount >= maxPendingLogEntries) {
      throw const OfflineQueueFullException();
    }
    await _logEntriesBox.put(entry.id, entry);
    return entry;
  }

  LocalLogEntry? _findPendingByDate(String userId, String date) {
    for (final entry in _logEntriesBox.values) {
      if (!entry.synced && entry.userId == userId && entry.date == date) {
        return entry;
      }
    }
    return null;
  }

  Future<void> saveLogEntry(LocalLogEntry entry) async {
    await _logEntriesBox.put(entry.id, entry);
  }

  /// Unsynced entries, oldest first — the order they must be synced in.
  List<LocalLogEntry> getPendingLogEntries() {
    final pending = _logEntriesBox.values.where((e) => !e.synced).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  List<LocalLogEntry> getAllLogEntries() {
    return _logEntriesBox.values.toList();
  }

  int get pendingLogEntryCount =>
      _initialized ? _logEntriesBox.values.where((e) => !e.synced).length : 0;

  /// Emits the current pending count immediately, then again after every
  /// change to the queue box.
  Stream<int> watchPendingLogEntryCount() async* {
    await initialize();
    yield pendingLogEntryCount;
    yield* _logEntriesBox.watch().map((_) => pendingLogEntryCount);
  }

  Future<void> markEntrySynced(String entryId) async {
    final entry = _logEntriesBox.get(entryId);
    if (entry != null) {
      entry.synced = true;
      await entry.save();
    }
  }

  Future<void> deleteLogEntry(String entryId) async {
    await _logEntriesBox.delete(entryId);
  }

  Future<void> saveUserProfile(LocalUserProfile profile) async {
    await _userProfileBox.put(profile.userId, profile);
  }

  LocalUserProfile? getUserProfile(String userId) {
    return _userProfileBox.get(userId);
  }

  Future<void> saveDashboardSnapshot(LocalDashboardSnapshot snapshot) async {
    await _dashboardBox.put(snapshot.userId, snapshot);
  }

  LocalDashboardSnapshot? getDashboardSnapshot(String userId) {
    final snapshot = _dashboardBox.get(userId);
    if (snapshot != null && snapshot.isExpired()) {
      return null;
    }
    return snapshot;
  }

  Future<void> clearAll() async {
    await _logEntriesBox.clear();
    await _userProfileBox.clear();
    await _dashboardBox.clear();
  }
}

/// Offline storage service provider
final offlineStorageServiceProvider = Provider<OfflineStorageService>((ref) {
  return OfflineStorageService();
});
