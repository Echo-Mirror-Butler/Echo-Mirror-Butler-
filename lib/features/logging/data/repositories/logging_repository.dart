import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/field_encryption_service.dart';
import '../../../../core/services/supabase_client_service.dart';
import '../models/log_entry_model.dart';

/// Thrown when the server-side mood log rate limit (max 10 logs per user per
/// hour, enforced by a Postgres trigger on `log_entries`) is exceeded.
class MoodLogRateLimitException implements Exception {
  MoodLogRateLimitException(this.retryAfterSeconds);

  final int retryAfterSeconds;

  @override
  String toString() =>
      'rate_limit_exceeded: retry after $retryAfterSeconds seconds';
}

/// Repository for logging operations
/// Handles all Supabase table queries for daily logging with Field-Level Encryption (FLE)
class LoggingRepository {
  LoggingRepository({
    SupabaseClient? supabaseClient,
    FieldEncryptionService? encryptionService,
  })  : _injectedClient = supabaseClient,
        _encryptionService = encryptionService ?? FieldEncryptionService.instance {
    debugPrint(
      supabaseClient == null
          ? '[LoggingRepository] Using shared Supabase client'
          : '[LoggingRepository] Using injected Supabase client',
    );
  }

  final SupabaseClient? _injectedClient;
  final FieldEncryptionService _encryptionService;

  SupabaseClient get _supabase =>
      _injectedClient ?? SupabaseClientService.instance.client;

  String _toDateString(DateTime date) {
    final utcDate = date.isUtc
        ? date
        : DateTime.utc(date.year, date.month, date.day);
    final year = utcDate.year.toString().padLeft(4, '0');
    final month = utcDate.month.toString().padLeft(2, '0');
    final day = utcDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses the `{"error":"rate_limit_exceeded","retry_after_seconds":N}`
  /// payload the `enforce_mood_log_rate_limit` trigger sends as the
  /// PostgrestException message, defaulting to 3600s if it can't be parsed.
  int _parseRetryAfterSeconds(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map && decoded['retry_after_seconds'] is int) {
        return decoded['retry_after_seconds'] as int;
      }
    } catch (_) {
      // Fall through to default below.
    }
    return 3600;
  }

  /// Encrypts notes field for an entry if present
  Future<String?> _encryptNotes(String? notes, String userId) async {
    if (notes == null || notes.isEmpty) return notes;
    return _encryptionService.encrypt(notes, userId: userId);
  }

  /// Decrypts notes field from a raw database record
  Future<LogEntryModel> _mapAndDecryptRecord(Map<String, dynamic> record) async {
    final rawNotes = record['notes'] as String?;
    final decryptedNotes = rawNotes != null && rawNotes.isNotEmpty
        ? await _encryptionService.decrypt(
            rawNotes,
            userId: (record['user_id'] ?? record['userId'])?.toString(),
          )
        : rawNotes;

    final decryptedRecord = Map<String, dynamic>.from(record);
    decryptedRecord['notes'] = decryptedNotes;
    return LogEntryModel.fromJson(decryptedRecord);
  }

  /// Create a new log entry with field-level encryption for private notes
  Future<LogEntryModel> createLogEntry(LogEntryModel entry) async {
    try {
      debugPrint('[LoggingRepository] createLogEntry -> ${entry.toJson()}');
      final encryptedNotes = await _encryptNotes(entry.notes, entry.userId);

      final result = await _supabase
          .from('log_entries')
          .insert({
            'user_id': entry.userId,
            'date': _toDateString(entry.date),
            'mood': entry.mood,
            'habits': entry.habits,
            'notes': encryptedNotes,
          })
          .select()
          .single();

      debugPrint('[LoggingRepository] createLogEntry success');
      return await _mapAndDecryptRecord(result);
    } on PostgrestException catch (e) {
      if (e.code == 'PT429') {
        final retryAfter = _parseRetryAfterSeconds(e.message);
        debugPrint(
          '[LoggingRepository] createLogEntry rate limited, retryAfterSeconds=$retryAfter',
        );
        throw MoodLogRateLimitException(retryAfter);
      }
      debugPrint('[LoggingRepository] createLogEntry error -> $e');
      throw Exception('Failed to create log entry: ${e.toString()}');
    } catch (e, stackTrace) {
      debugPrint('[LoggingRepository] createLogEntry error -> $e');
      debugPrint(
        '[LoggingRepository] createLogEntry stackTrace -> $stackTrace',
      );
      throw Exception('Failed to create log entry: ${e.toString()}');
    }
  }

  /// Update an existing log entry with field-level encryption
  Future<LogEntryModel> updateLogEntry(LogEntryModel entry) async {
    try {
      debugPrint('[LoggingRepository] updateLogEntry -> ${entry.id}');
      final encryptedNotes = await _encryptNotes(entry.notes, entry.userId);

      final result = await _supabase
          .from('log_entries')
          .update({
            'date': _toDateString(entry.date),
            'mood': entry.mood,
            'habits': entry.habits,
            'notes': encryptedNotes,
          })
          .eq('id', entry.id)
          .eq('user_id', entry.userId)
          .select()
          .single();

      debugPrint('[LoggingRepository] updateLogEntry success');
      return await _mapAndDecryptRecord(result);
    } catch (e, stackTrace) {
      debugPrint('[LoggingRepository] updateLogEntry error -> $e');
      debugPrint(
        '[LoggingRepository] updateLogEntry stackTrace -> $stackTrace',
      );
      throw Exception('Failed to update log entry: ${e.toString()}');
    }
  }

  /// Get log entry for a specific date
  Future<LogEntryModel?> getLogEntryForDate(
    DateTime date,
    String userId,
  ) async {
    try {
      final normalizedDate = _toDateString(date);
      debugPrint(
        '[LoggingRepository] getLogEntryForDate -> date: $normalizedDate, userId: $userId',
      );
      final result = await _supabase
          .from('log_entries')
          .select()
          .eq('user_id', userId)
          .eq('date', normalizedDate)
          .maybeSingle();

      if (result == null) {
        debugPrint('[LoggingRepository] getLogEntryForDate -> no entry found');
        return null;
      }

      debugPrint('[LoggingRepository] getLogEntryForDate success');
      return await _mapAndDecryptRecord(result);
    } catch (e) {
      debugPrint('[LoggingRepository] getLogEntryForDate error -> $e');
      return null;
    }
  }

  /// Default page size for paginated log list fetches (Issue #637).
  static const int defaultPageSize = 30;

  /// Get log entries for a user.
  ///
  /// When [limit] is provided (or defaults via [offset]), results are bounded
  /// with `.range` so the logging screen never loads an unbounded result set.
  /// Pass [limit] = null and [offset] = null only for callers that truly need
  /// a date-windowed full fetch (prefer providing [startDate]/[endDate]).
  Future<List<LogEntryModel>> getLogEntries(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    int? offset,
    int? limit,
  }) async {
    try {
      final effectiveLimit = limit ?? (offset != null ? defaultPageSize : null);
      debugPrint(
        '[LoggingRepository] getLogEntries -> userId: $userId '
        'offset: $offset limit: $effectiveLimit',
      );
      var query = _supabase.from('log_entries').select().eq('user_id', userId);
      if (startDate != null) {
        query = query.gte('date', _toDateString(startDate));
      }
      if (endDate != null) {
        query = query.lte('date', _toDateString(endDate));
      }

      final ordered = query.order('date', ascending: false);
      final results = effectiveLimit != null
          ? await ordered.range(
              offset ?? 0,
              (offset ?? 0) + effectiveLimit - 1,
            )
          : await ordered;
      debugPrint(
        '[LoggingRepository] getLogEntries success -> ${results.length} entries',
      );
      final entries = await Future.wait(
        (results as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(_mapAndDecryptRecord),
      );
      return entries;
    } catch (e, stackTrace) {
      debugPrint('[LoggingRepository] getLogEntries error -> $e');
      debugPrint('[LoggingRepository] getLogEntries stackTrace -> $stackTrace');
      return [];
    }
  }

  /// Paginated fetch used by the logging list (Issue #637).
  Future<List<LogEntryModel>> getLogEntriesPage(
    String userId, {
    int offset = 0,
    int limit = defaultPageSize,
  }) {
    return getLogEntries(userId, offset: offset, limit: limit);
  }

  /// Delete a log entry
  Future<void> deleteLogEntry(String entryId, String userId) async {
    try {
      debugPrint('[LoggingRepository] deleteLogEntry -> $entryId');
      await _supabase
          .from('log_entries')
          .delete()
          .eq('id', entryId)
          .eq('user_id', userId);

      debugPrint('[LoggingRepository] deleteLogEntry success');
    } catch (e, stackTrace) {
      debugPrint('[LoggingRepository] deleteLogEntry error -> $e');
      debugPrint(
        '[LoggingRepository] deleteLogEntry stackTrace -> $stackTrace',
      );
      throw Exception('Failed to delete log entry: ${e.toString()}');
    }
  }
}
