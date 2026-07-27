import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/log_entry_model.dart';
import '../../data/repositories/logging_repository.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/mood_sync_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/offline_storage_service.dart';

/// Logging repository provider
final loggingRepositoryProvider = Provider<LoggingRepository>((ref) {
  return LoggingRepository();
});

/// Paginated logging list state (Issue #637).
class LoggingListState {
  const LoggingListState({
    this.entries = const [],
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<LogEntryModel> entries;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  LoggingListState copyWith({
    List<LogEntryModel>? entries,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return LoggingListState(
      entries: entries ?? this.entries,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Logging state notifier with incremental page loads.
class LoggingNotifier extends StateNotifier<AsyncValue<List<LogEntryModel>>> {
  LoggingNotifier(
    this._repository, {
    MoodSyncService? moodSync,
    ConnectivityService? connectivity,
  }) : _moodSync = moodSync,
       _connectivity = connectivity,
       super(const AsyncValue.data([])) {
    // Don't load on init - wait for userId to be provided
  }

  final LoggingRepository _repository;
  final MoodSyncService? _moodSync;
  final ConnectivityService? _connectivity;
  String? _currentUserId;
  bool _hasLoaded = false;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = LoggingRepository.defaultPageSize;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  /// Load the first page of log entries for the current user.
  Future<void> loadLogEntries({String? userId, bool force = false}) async {
    // If userId is provided and different from current, reset
    if (userId != null && userId != _currentUserId) {
      _currentUserId = userId;
      _hasLoaded = false;
      _offset = 0;
      _hasMore = true;
    }

    // Prevent concurrent calls while a fetch is already in-flight
    if (state.isLoading) return;

    // If no userId, return empty list instead of staying in loading state
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    // If already loaded for this user, don't reload unless forced (pull-to-refresh)
    if (_hasLoaded && _currentUserId != null && !force) {
      return;
    }

    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    try {
      debugPrint(
        '[LoggingNotifier] Loading log entries page for userId: $_currentUserId',
      );
      final entries = await _repository.getLogEntriesPage(
        _currentUserId!,
        offset: 0,
        limit: _pageSize,
      );
      debugPrint('[LoggingNotifier] Loaded ${entries.length} log entries');
      _hasLoaded = true;
      _offset = entries.length;
      _hasMore = entries.length >= _pageSize;
      state = AsyncValue.data(entries);
    } catch (e, stackTrace) {
      debugPrint('[LoggingNotifier] Error loading log entries: $e');
      debugPrint('[LoggingNotifier] Stack trace: $stackTrace');
      _hasLoaded = false;
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Append the next page when the list approaches the end.
  Future<void> loadMoreLogEntries() async {
    if (_currentUserId == null ||
        _currentUserId!.isEmpty ||
        !_hasMore ||
        _isLoadingMore ||
        state.isLoading) {
      return;
    }

    _isLoadingMore = true;
    try {
      final next = await _repository.getLogEntriesPage(
        _currentUserId!,
        offset: _offset,
        limit: _pageSize,
      );
      final current = state.value ?? <LogEntryModel>[];
      // Dedup by id in case of overlap
      final existingIds = current.map((e) => e.id).toSet();
      final merged = [
        ...current,
        ...next.where((e) => !existingIds.contains(e.id)),
      ];
      _offset = merged.length;
      _hasMore = next.length >= _pageSize;
      state = AsyncValue.data(merged);
    } catch (e, stackTrace) {
      debugPrint('[LoggingNotifier] Error loading more log entries: $e');
      debugPrint('[LoggingNotifier] Stack trace: $stackTrace');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Create a new log entry. When the device is offline (or the request
  /// fails because connectivity dropped mid-flight), the entry is queued
  /// locally and synced automatically once the connection is restored.
  Future<bool> createLogEntry(LogEntryModel entry) async {
    if (_moodSync != null && !await _isOnline()) {
      return _queueOffline(entry);
    }

    try {
      final created = await _repository.createLogEntry(entry);
      _upsertIntoState(created);
      await _cancelNoLogTodayNotification();
      return true;
    } catch (e) {
      // The request itself may have failed because we went offline
      // mid-flight — queue instead of surfacing an error.
      if (_moodSync != null && !await _isOnline()) {
        return _queueOffline(entry);
      }
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> _isOnline() async {
    final connectivity = _connectivity;
    if (connectivity == null) return true;
    try {
      return await connectivity.isConnected();
    } catch (_) {
      // If the connectivity check itself fails, assume online and let the
      // network request decide.
      return true;
    }
  }

  Future<bool> _queueOffline(LogEntryModel entry) async {
    final moodSync = _moodSync;
    if (moodSync == null) return false;
    try {
      final queued = await moodSync.queueMoodLog(
        userId: entry.userId,
        date: entry.date,
        mood: entry.mood,
        habits: entry.habits,
        notes: entry.notes,
      );
      debugPrint(
        '[LoggingNotifier] Offline — queued entry for ${queued.date} '
        '(pending: ${moodSync.pendingCount})',
      );
      // Reflect the queued entry in local state so calendar/list views show
      // it immediately; it gets replaced by the server copy after sync.
      _upsertIntoState(
        entry.copyWith(id: queued.id, createdAt: queued.createdAt),
      );
      await _cancelNoLogTodayNotification();
      return true;
    } on OfflineQueueFullException catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return false;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// Add [entry] to state, replacing an existing entry with the same id
  /// (re-logging a queued day reuses the queued entry's id).
  void _upsertIntoState(LogEntryModel entry) {
    final currentData = state.value ?? [];
    state = AsyncValue.data([
      entry,
      ...currentData.where((e) => e.id != entry.id),
    ]);
  }

  Future<void> _cancelNoLogTodayNotification() async {
    // Wrap notification call so platform plugin failures (e.g.
    // MissingPluginException in unit tests) do not fail the entire log entry
    // creation.
    try {
      await NotificationService().cancelNoLogTodayNotification();
    } catch (_) {
      // Ignore notification errors (e.g., in unit tests where plugins are
      // unavailable)
    }
  }

  /// Update an existing log entry
  Future<bool> updateLogEntry(LogEntryModel entry) async {
    try {
      final updated = await _repository.updateLogEntry(entry);
      final currentData = state.value;
      if (currentData == null) return false;
      final index = currentData.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        final updatedList = [...currentData];
        updatedList[index] = updated;
        state = AsyncValue.data(updatedList);
      }
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// Get log entry for a specific date
  Future<LogEntryModel?> getLogEntryForDate(DateTime date) async {
    if (_currentUserId == null) return null;
    try {
      return await _repository.getLogEntryForDate(date, _currentUserId!);
    } catch (e) {
      return null;
    }
  }

  /// Delete a log entry
  Future<bool> deleteLogEntry(String entryId, String userId) async {
    try {
      await _repository.deleteLogEntry(entryId, userId);
      final currentData = state.value;
      if (currentData == null) return false;
      state = AsyncValue.data(
        currentData.where((e) => e.id != entryId).toList(),
      );
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

/// Logging provider
final loggingProvider =
    StateNotifierProvider<LoggingNotifier, AsyncValue<List<LogEntryModel>>>((
      ref,
    ) {
      final repository = ref.watch(loggingRepositoryProvider);
      return LoggingNotifier(
        repository,
        moodSync: ref.watch(moodSyncServiceProvider),
        connectivity: ref.watch(connectivityServiceProvider),
      );
    });
