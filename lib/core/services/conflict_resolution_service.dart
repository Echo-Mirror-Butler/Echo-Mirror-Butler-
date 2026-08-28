import 'package:flutter/foundation.dart';
import '../models/local_models.dart';

/// Strategy for resolving conflicts between locally queued edits and server state.
enum ConflictResolutionStrategy {
  /// Intelligently merges field-by-field:
  /// - Mood: Last-write-wins based on timestamp
  /// - Habits: Non-destructive set union
  /// - Notes: Non-destructive concatenation if both sides diverged
  smartFieldMerge,

  /// Server state strictly takes precedence over local offline edits.
  serverWins,

  /// Local offline edits strictly overwrite server state.
  clientWins,
}

/// Result of a conflict resolution evaluation.
class ConflictResolutionResult {
  const ConflictResolutionResult({
    required this.hadConflict,
    required this.resolvedPayload,
    required this.strategyUsed,
    this.conflictSummary,
  });

  final bool hadConflict;
  final Map<String, dynamic> resolvedPayload;
  final ConflictResolutionStrategy strategyUsed;
  final String? conflictSummary;
}

/// Generic service for detecting and resolving data divergence between
/// offline-queued mutations and remote server state (Issue #702).
class ConflictResolutionService {
  const ConflictResolutionService({
    this.defaultStrategy = ConflictResolutionStrategy.smartFieldMerge,
  });

  final ConflictResolutionStrategy defaultStrategy;

  static const ConflictResolutionService instance = ConflictResolutionService();

  /// Resolves divergence between a local [LocalLogEntry] and a server-side log entry row.
  ConflictResolutionResult resolveLogEntry({
    required LocalLogEntry local,
    required Map<String, dynamic> server,
    ConflictResolutionStrategy? strategyOverride,
  }) {
    final strategy = strategyOverride ?? defaultStrategy;

    final rawServerUpdatedAt = server['updated_at'] ?? server['updatedAt'];
    final serverUpdatedAt = rawServerUpdatedAt != null
        ? (rawServerUpdatedAt is DateTime
            ? rawServerUpdatedAt
            : DateTime.tryParse(rawServerUpdatedAt.toString()))
        : null;

    final rawServerCreatedAt = server['created_at'] ?? server['createdAt'];
    final serverCreatedAt = rawServerCreatedAt != null
        ? (rawServerCreatedAt is DateTime
            ? rawServerCreatedAt
            : DateTime.tryParse(rawServerCreatedAt.toString()))
        : null;

    final serverReferenceTime = serverUpdatedAt ?? serverCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    // Detect if server state was modified after the local entry's initial base timestamp
    final serverDiverged = serverUpdatedAt != null &&
        serverUpdatedAt.isAfter(local.createdAt.add(const Duration(seconds: 1)));

    if (!serverDiverged) {
      // Clean local update: no divergence on server
      return ConflictResolutionResult(
        hadConflict: false,
        strategyUsed: strategy,
        resolvedPayload: {
          'mood': local.mood,
          'habits': local.habits,
          'notes': local.notes,
          'updated_at': local.updatedAt.toIso8601String(),
        },
      );
    }

    debugPrint(
      '[ConflictResolutionService] Conflict detected for entry ${local.id} (date: ${local.date}). '
      'Server updated at: $serverReferenceTime, Local updated at: ${local.updatedAt}',
    );

    switch (strategy) {
      case ConflictResolutionStrategy.serverWins:
        return ConflictResolutionResult(
          hadConflict: true,
          strategyUsed: strategy,
          conflictSummary: 'Server state preserved (serverWins strategy)',
          resolvedPayload: {
            'mood': server['mood'],
            'habits': List<String>.from(server['habits'] as List? ?? []),
            'notes': server['notes'],
            'updated_at': serverReferenceTime.toIso8601String(),
          },
        );

      case ConflictResolutionStrategy.clientWins:
        return ConflictResolutionResult(
          hadConflict: true,
          strategyUsed: strategy,
          conflictSummary: 'Local edit overwritten server (clientWins strategy)',
          resolvedPayload: {
            'mood': local.mood,
            'habits': local.habits,
            'notes': local.notes,
            'updated_at': local.updatedAt.toIso8601String(),
          },
        );

      case ConflictResolutionStrategy.smartFieldMerge:
        // 1. Mood Resolution: Last-Write-Wins based on explicit modification timestamp
        final int? resolvedMood;
        if (local.updatedAt.isAfter(serverReferenceTime)) {
          resolvedMood = local.mood ?? (server['mood'] as int?);
        } else {
          resolvedMood = (server['mood'] as int?) ?? local.mood;
        }

        // 2. Habits Resolution: Non-destructive Set Union
        final serverHabits = List<String>.from(server['habits'] as List? ?? []);
        final resolvedHabits = (Set<String>.from(serverHabits)..addAll(local.habits)).toList();

        // 3. Notes Resolution: Smart Text Merge
        final serverNotes = (server['notes'] as String?)?.trim();
        final localNotes = local.notes?.trim();

        final String? resolvedNotes;
        if (serverNotes == null || serverNotes.isEmpty) {
          resolvedNotes = localNotes;
        } else if (localNotes == null || localNotes.isEmpty) {
          resolvedNotes = serverNotes;
        } else if (serverNotes == localNotes) {
          resolvedNotes = localNotes;
        } else {
          // Both sides edited notes: preserve both non-destructively
          resolvedNotes = '$serverNotes\n\n[Offline update]:\n$localNotes';
        }

        return ConflictResolutionResult(
          hadConflict: true,
          strategyUsed: strategy,
          conflictSummary: 'Smart merged mood (LWW), habits (union), and notes (preserved)',
          resolvedPayload: {
            'mood': resolvedMood,
            'habits': resolvedHabits,
            'notes': resolvedNotes,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
    }
  }
}
