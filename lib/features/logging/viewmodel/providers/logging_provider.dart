import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/log_entry_model.dart';
import '../../data/repositories/logging_repository.dart';

/// Logging repository provider
final loggingRepositoryProvider = Provider<LoggingRepository>((ref) {
  return LoggingRepository();
});

/// Logging state notifier
class LoggingNotifier extends StateNotifier<AsyncValue<List<LogEntryModel>>> {
  LoggingNotifier(this._repository) : super(const AsyncValue.data([])) {
    // Don't load on init - wait for userId to be provided
  }

  final LoggingRepository _repository;
  String? _currentUserId;
  bool _hasLoaded = false;

  /// Load all log entries for the current user
  Future<void> loadLogEntries({String? userId}) async {
    // If userId is provided and different from current, reset
    if (userId != null && userId != _currentUserId) {
      _currentUserId = userId;
      _hasLoaded = false;
    }
    
    // If no userId, return empty list instead of staying in loading state
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    // If already loaded for this user, don't reload
    if (_hasLoaded && _currentUserId != null) {
      return;
    }

    state = const AsyncValue.loading();
    try {
      final entries = await _repository.getLogEntries(_currentUserId!);
      _hasLoaded = true;
      state = AsyncValue.data(entries);
    } catch (e, stackTrace) {
      _hasLoaded = false;
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Create a new log entry
  Future<bool> createLogEntry(LogEntryModel entry) async {
    try {
      final created = await _repository.createLogEntry(entry);
      final currentData = state.value ?? [];
      state = AsyncValue.data([...currentData, created]);
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
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
final loggingProvider = StateNotifierProvider<LoggingNotifier, AsyncValue<List<LogEntryModel>>>((ref) {
  final repository = ref.watch(loggingRepositoryProvider);
  return LoggingNotifier(repository);
});

