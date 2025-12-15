import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/log_entry_model.dart';

/// Repository for logging operations
/// Handles all Serverpod backend calls for daily logging
class LoggingRepository {
  LoggingRepository() {
    debugPrint(
      '[LoggingRepository] Initialized client -> ${ApiConstants.serverUrl}',
    );
  }

  final Client _client = Client(ApiConstants.serverUrl);

  /// Check if error is a 404 (endpoint not found)
  bool _isNotFoundError(dynamic error) {
    if (error is ServerpodClientException) {
      return error.statusCode == 404;
    }
    final errorString = error.toString();
    return errorString.contains('404') || 
           errorString.contains('Not found') ||
           errorString.contains('statusCode = 404');
  }

  /// Create a new log entry
  Future<LogEntryModel> createLogEntry(LogEntryModel entry) async {
    try {
      debugPrint('[LoggingRepository] createLogEntry -> ${entry.toJson()}');
      
      // Call Serverpod endpoint
      final result = await _client.logging.createEntry(
        entry.userId,
        entry.date,
        entry.mood,
        entry.habits,
        entry.notes,
      );
      
      debugPrint('[LoggingRepository] createLogEntry success -> $result');
      
      // Convert Serverpod LogEntry to LogEntryModel
      return LogEntryModel(
        id: result.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: result.userId,
        date: result.date,
        mood: result.mood,
        habits: result.habits,
        notes: result.notes,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
    } catch (e, stackTrace) {
      if (_isNotFoundError(e)) {
        debugPrint(
          '[LoggingRepository] createLogEntry -> Logging endpoints not available on server (404). '
          'Please ensure logging endpoints are deployed on the server.',
        );
        throw Exception(
          'Logging feature is not available. The server endpoints have not been deployed yet.',
        );
      }
      debugPrint('[LoggingRepository] createLogEntry error -> $e');
      debugPrint('[LoggingRepository] createLogEntry stackTrace -> $stackTrace');
      throw Exception('Failed to create log entry: ${e.toString()}');
    }
  }

  /// Update an existing log entry
  Future<LogEntryModel> updateLogEntry(LogEntryModel entry) async {
    try {
      debugPrint('[LoggingRepository] updateLogEntry -> ${entry.id}');
      
      // Ensure date is in UTC format
      final utcDate = entry.date.isUtc 
          ? entry.date 
          : DateTime.utc(entry.date.year, entry.date.month, entry.date.day);
      
      final result = await _client.logging.updateEntry(
        entry.userId,
        int.parse(entry.id),
        utcDate,
        entry.mood,
        entry.habits,
        entry.notes,
      );
      
      debugPrint('[LoggingRepository] updateLogEntry success -> $result');
      
      return LogEntryModel(
        id: result.id?.toString() ?? entry.id,
        userId: result.userId,
        date: result.date,
        mood: result.mood,
        habits: result.habits,
        notes: result.notes,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
    } catch (e, stackTrace) {
      if (_isNotFoundError(e)) {
        debugPrint(
          '[LoggingRepository] updateLogEntry -> Logging endpoints not available on server (404). '
          'Please ensure logging endpoints are deployed on the server.',
        );
        throw Exception(
          'Logging feature is not available. The server endpoints have not been deployed yet.',
        );
      }
      debugPrint('[LoggingRepository] updateLogEntry error -> $e');
      debugPrint('[LoggingRepository] updateLogEntry stackTrace -> $stackTrace');
      throw Exception('Failed to update log entry: ${e.toString()}');
    }
  }

  /// Get log entry for a specific date
  Future<LogEntryModel?> getLogEntryForDate(DateTime date, String userId) async {
    try {
      // Normalize date to UTC to match how dates are stored
      final utcDate = date.isUtc 
          ? date 
          : DateTime.utc(date.year, date.month, date.day);
      debugPrint('[LoggingRepository] getLogEntryForDate -> date: $utcDate, userId: $userId');
      
      final result = await _client.logging.getEntryForDate(userId, utcDate);
      
      if (result == null) {
        debugPrint('[LoggingRepository] getLogEntryForDate -> no entry found');
        return null;
      }
      
      debugPrint('[LoggingRepository] getLogEntryForDate success -> $result');
      
      return LogEntryModel(
        id: result.id?.toString() ?? '',
        userId: result.userId,
        date: result.date,
        mood: result.mood,
        habits: result.habits,
        notes: result.notes,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
    } catch (e, stackTrace) {
      if (_isNotFoundError(e)) {
        debugPrint(
          '[LoggingRepository] getLogEntryForDate -> Logging endpoints not available on server (404).',
        );
        return null;
      }
      debugPrint('[LoggingRepository] getLogEntryForDate error -> $e');
      debugPrint('[LoggingRepository] getLogEntryForDate stackTrace -> $stackTrace');
      return null;
    }
  }

  /// Get all log entries for a user
  Future<List<LogEntryModel>> getLogEntries(String userId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      debugPrint('[LoggingRepository] getLogEntries -> userId: $userId');
      
      final results = await _client.logging.getEntries(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      
      debugPrint('[LoggingRepository] getLogEntries success -> ${results.length} entries');
      
      return results.map((result) {
        return LogEntryModel(
          id: result.id?.toString() ?? '',
          userId: result.userId,
          date: result.date,
          mood: result.mood,
          habits: result.habits,
          notes: result.notes,
          createdAt: result.createdAt,
          updatedAt: result.updatedAt,
        );
      }).toList();
    } catch (e, stackTrace) {
      if (_isNotFoundError(e)) {
        // Log once, not repeatedly
        debugPrint(
          '[LoggingRepository] getLogEntries -> Logging endpoints not available on server (404). '
          'Returning empty list. Please ensure logging endpoints are deployed on the server.',
        );
        // Return empty list for 404 errors (endpoints not deployed)
        return [];
      }
      debugPrint('[LoggingRepository] getLogEntries error -> $e');
      debugPrint('[LoggingRepository] getLogEntries stackTrace -> $stackTrace');
      // Return empty list on error instead of throwing
      return [];
    }
  }

  /// Delete a log entry
  Future<void> deleteLogEntry(String entryId, String userId) async {
    try {
      debugPrint('[LoggingRepository] deleteLogEntry -> $entryId');
      
      await _client.logging.deleteEntry(userId, int.parse(entryId));
      
      debugPrint('[LoggingRepository] deleteLogEntry success');
    } catch (e, stackTrace) {
      if (_isNotFoundError(e)) {
        debugPrint(
          '[LoggingRepository] deleteLogEntry -> Logging endpoints not available on server (404). '
          'Please ensure logging endpoints are deployed on the server.',
        );
        throw Exception(
          'Logging feature is not available. The server endpoints have not been deployed yet.',
        );
      }
      debugPrint('[LoggingRepository] deleteLogEntry error -> $e');
      debugPrint('[LoggingRepository] deleteLogEntry stackTrace -> $stackTrace');
      throw Exception('Failed to delete log entry: ${e.toString()}');
    }
  }
}
