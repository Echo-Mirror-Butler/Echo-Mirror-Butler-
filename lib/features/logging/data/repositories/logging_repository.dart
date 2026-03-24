import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/log_entry_model.dart';

/// Repository for logging operations
/// Backed by Supabase — full implementation pending migration phase
class LoggingRepository {
  LoggingRepository() {
    debugPrint('[LoggingRepository] Initialized');
  }

  /// Check if a string is a UUID format
  bool _isUuid(String? str) {
    if (str == null || str.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(str);
  }

  /// Create a new log entry
  Future<LogEntryModel> createLogEntry(LogEntryModel entry) async {
    debugPrint('[LoggingRepository] createLogEntry -> ${entry.toJson()}');
    throw UnimplementedError(
      'Logging endpoints not yet implemented for Supabase. '
      'Implement using supabase_flutter client against the log_entries table.',
    );
  }

  /// Update an existing log entry
  Future<LogEntryModel> updateLogEntry(LogEntryModel entry) async {
    debugPrint('[LoggingRepository] updateLogEntry -> ${entry.id}');
    throw UnimplementedError(
      'Logging endpoints not yet implemented for Supabase.',
    );
  }

  /// Get log entry for a specific date
  Future<LogEntryModel?> getLogEntryForDate(
    DateTime date,
    String userId,
  ) async {
    try {
      debugPrint(
        '[LoggingRepository] getLogEntryForDate -> date: $date, userId: $userId',
      );
      return null;
    } catch (e) {
      debugPrint('[LoggingRepository] getLogEntryForDate error -> $e');
      return null;
    }
  }

  /// Get all log entries for a user
  Future<List<LogEntryModel>> getLogEntries(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('[LoggingRepository] getLogEntries -> userId: $userId');

      if (_isUuid(userId)) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email');
        debugPrint(
          '[LoggingRepository] UUID userId detected, email: ${email ?? "not found"}',
        );
      }

      return [];
    } catch (e) {
      debugPrint('[LoggingRepository] getLogEntries error -> $e');
      return [];
    }
  }

  /// Delete a log entry
  Future<void> deleteLogEntry(String entryId, String userId) async {
    debugPrint('[LoggingRepository] deleteLogEntry -> $entryId');
    throw UnimplementedError(
      'Logging endpoints not yet implemented for Supabase.',
    );
  }
}
