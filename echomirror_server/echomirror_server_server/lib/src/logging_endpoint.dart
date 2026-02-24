import 'generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

/// Endpoint for logging operations - handles daily log entries
class LoggingEndpoint extends Endpoint {
  /// Create a new log entry
  Future<LogEntry> createEntry(
    Session session,
    String userId,
    DateTime date,
    int? mood,
    List<String> habits,
    String? notes,
  ) async {
    final entry = LogEntry(
      userId: userId,
      date: date,
      mood: mood,
      habits: habits,
      notes: notes,
      createdAt: DateTime.now(),
    );

    return await LogEntry.db.insertRow(session, entry);
  }

  /// Get all entries for a user
  Future<List<LogEntry>> getEntries(
    Session session,
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Get all entries for the user
    final entries = await LogEntry.db.find(
      session,
      where: (t) => t.userId.equals(userId),
    );

    // Filter by date range if provided
    var filteredEntries = entries;
    if (startDate != null) {
      filteredEntries = filteredEntries
          .where(
            (entry) =>
                entry.date.isAfter(
                  startDate.subtract(const Duration(seconds: 1)),
                ) ||
                entry.date.isAtSameMomentAs(startDate),
          )
          .toList();
    }
    if (endDate != null) {
      filteredEntries = filteredEntries
          .where(
            (entry) =>
                entry.date.isBefore(endDate.add(const Duration(days: 1))) ||
                entry.date.isAtSameMomentAs(endDate),
          )
          .toList();
    }

    return filteredEntries;
  }

  /// Get entry for a specific date
  Future<LogEntry?> getEntryForDate(
    Session session,
    String userId,
    DateTime date,
  ) async {
    // Normalize date to start of day for comparison
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final entries = await LogEntry.db.find(
      session,
      where: (t) => t.userId.equals(userId),
    );

    // Find entry for the specific date
    for (final entry in entries) {
      final entryDate = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      if (entryDate.isAtSameMomentAs(normalizedDate)) {
        return entry;
      }
    }

    return null;
  }

  /// Update an existing entry
  Future<LogEntry> updateEntry(
    Session session,
    String userId,
    int entryId,
    DateTime date,
    int? mood,
    List<String> habits,
    String? notes,
  ) async {
    final entry = await LogEntry.db.findById(session, entryId);
    if (entry == null || entry.userId != userId) {
      throw Exception('Entry not found or unauthorized');
    }

    final updated = entry.copyWith(
      date: date,
      mood: mood,
      habits: habits,
      notes: notes,
      updatedAt: DateTime.now(),
    );

    return await LogEntry.db.updateRow(session, updated);
  }

  /// Delete an entry
  Future<void> deleteEntry(Session session, String userId, int entryId) async {
    final entry = await LogEntry.db.findById(session, entryId);
    if (entry == null || entry.userId != userId) {
      throw Exception('Entry not found or unauthorized');
    }

    await LogEntry.db.deleteRow(session, entry);
  }
}
