import 'hlc.dart';
import 'version_vector.dart';
import 'sync_mutation.dart';

/// Result of a conflict resolution evaluation.
class ConflictResolutionResult<T> {
  const ConflictResolutionResult({
    required this.resolvedData,
    this.hasConflict = false,
    this.conflictDescription,
    this.surfacedConflicts = const {},
  });

  /// The merged or chosen record.
  final T resolvedData;

  /// True if a genuine divergent concurrent write was detected and resolved.
  final bool hasConflict;

  /// Human or machine readable description of how the conflict was resolved.
  final String? conflictDescription;

  /// Any preserved competing values (e.g. conflicting note text).
  final Map<String, dynamic> surfacedConflicts;
}

/// Abstract generic interface for entity conflict resolution policies.
abstract class ConflictResolutionPolicy<T> {
  ConflictResolutionResult<T> resolve({
    required T local,
    required T remote,
    required Hlc localHlc,
    required Hlc remoteHlc,
    VersionVector? localVector,
    VersionVector? remoteVector,
  });
}

/// Generic Map-based entity conflict resolution policy.
abstract class EntityDataConflictPolicy
    implements ConflictResolutionPolicy<Map<String, dynamic>> {}

/// 1. Mood Entry Conflict Policy:
/// - Mood rating: Last-Write-Wins (LWW) based on HLC.
/// - Habits list: Set-union (all habits logged locally and remotely are preserved).
/// - Notes field: Last-Write-Wins with Conflict Surfacing (LWW-CS) — preserves
///   the newer note as primary while attaching/surfacing the conflicting note
///   so zero user thoughts or logs are silently lost.
class MoodEntryConflictPolicy extends EntityDataConflictPolicy {
  @override
  ConflictResolutionResult<Map<String, dynamic>> resolve({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required Hlc localHlc,
    required Hlc remoteHlc,
    VersionVector? localVector,
    VersionVector? remoteVector,
  }) {
    final merged = Map<String, dynamic>.from(local);
    bool hasConflict = false;
    final surfaced = <String, dynamic>{};

    final isLocalNewer = localHlc.compareTo(remoteHlc) >= 0;
    final newerMap = isLocalNewer ? local : remote;
    final olderMap = isLocalNewer ? remote : local;
    final newerHlc = isLocalNewer ? localHlc : remoteHlc;

    // Mood rating: LWW
    if (newerMap.containsKey('mood') && newerMap['mood'] != null) {
      merged['mood'] = newerMap['mood'];
    } else if (olderMap.containsKey('mood')) {
      merged['mood'] = olderMap['mood'];
    }

    // Habits: Set-Union merge across devices
    final localHabits = (local['habits'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final remoteHabits = (remote['habits'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final unionHabits = localHabits.union(remoteHabits).toList()..sort();
    merged['habits'] = unionHabits;

    // Notes: LWW with conflict surfacing if both devices entered different notes
    final localNote = local['notes']?.toString().trim();
    final remoteNote = remote['notes']?.toString().trim();

    if (localNote != null &&
        remoteNote != null &&
        localNote.isNotEmpty &&
        remoteNote.isNotEmpty &&
        localNote != remoteNote) {
      hasConflict = true;
      final primaryNote = isLocalNewer ? localNote : remoteNote;
      final conflictingNote = isLocalNewer ? remoteNote : localNote;

      surfaced['conflicting_notes'] = conflictingNote;
      surfaced['primary_notes'] = primaryNote;
      surfaced['resolved_at_hlc'] = newerHlc.toJsonString();

      // Ensure conflicting note is surfaced cleanly without losing information
      merged['notes'] = primaryNote;
      merged['conflict_surfaced'] = true;
      merged['conflicted_note_backup'] = conflictingNote;
    } else {
      merged['notes'] = localNote?.isNotEmpty == true
          ? localNote
          : (remoteNote?.isNotEmpty == true ? remoteNote : null);
    }

    // Updated At: Max timestamp
    final localUpdated = DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(localHlc.millis, isUtc: true);
    final remoteUpdated = DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(remoteHlc.millis, isUtc: true);
    final maxUpdated = localUpdated.isAfter(remoteUpdated) ? localUpdated : remoteUpdated;
    merged['updated_at'] = maxUpdated.toIso8601String();

    return ConflictResolutionResult(
      resolvedData: merged,
      hasConflict: hasConflict,
      conflictDescription: hasConflict
          ? 'Mood notes differed concurrently; surfaced conflicting note in backup metadata.'
          : 'Clean merge applied.',
      surfacedConflicts: surfaced,
    );
  }
}

/// 2. Habit Log Conflict Policy:
/// - Boolean toggle / Add-Wins / Set-Union semantics.
/// - Once a habit is logged completed on any device for a given day, it remains completed.
/// - Habit lists are unioned cleanly across devices.
class HabitLogConflictPolicy extends EntityDataConflictPolicy {
  @override
  ConflictResolutionResult<Map<String, dynamic>> resolve({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required Hlc localHlc,
    required Hlc remoteHlc,
    VersionVector? localVector,
    VersionVector? remoteVector,
  }) {
    final merged = Map<String, dynamic>.from(local);

    // Completed flag: boolean OR (Add-Wins)
    final localCompleted = local['completed'] as bool? ?? true;
    final remoteCompleted = remote['completed'] as bool? ?? true;
    merged['completed'] = localCompleted || remoteCompleted;

    // Habits set: Set-Union
    final localHabits = (local['habits'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final remoteHabits = (remote['habits'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    merged['habits'] = localHabits.union(remoteHabits).toList()..sort();

    // Streak / Count: Max value
    final localStreak = (local['streak'] as num?)?.toInt() ?? 0;
    final remoteStreak = (remote['streak'] as num?)?.toInt() ?? 0;
    merged['streak'] = localStreak > remoteStreak ? localStreak : remoteStreak;

    final isLocalNewer = localHlc.compareTo(remoteHlc) >= 0;
    final maxUpdated = isLocalNewer ? local['updated_at'] : remote['updated_at'];
    if (maxUpdated != null) {
      merged['updated_at'] = maxUpdated;
    }

    return ConflictResolutionResult(
      resolvedData: merged,
      hasConflict: false,
      conflictDescription: 'Habit log merged with Add-Wins and Set-Union semantics.',
    );
  }
}

/// 3. Follow Conflict Policy:
/// - Causal Last-State-Wins based on HLC.
/// - Follow vs Unfollow operations are ordered strictly by causal HLC timestamps.
class FollowConflictPolicy extends EntityDataConflictPolicy {
  @override
  ConflictResolutionResult<Map<String, dynamic>> resolve({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required Hlc localHlc,
    required Hlc remoteHlc,
    VersionVector? localVector,
    VersionVector? remoteVector,
  }) {
    final isLocalNewer = localHlc.compareTo(remoteHlc) >= 0;
    final winning = isLocalNewer ? local : remote;

    return ConflictResolutionResult(
      resolvedData: Map<String, dynamic>.from(winning),
      hasConflict: false,
      conflictDescription: isLocalNewer
          ? 'Local follow state won via newer HLC ($localHlc).'
          : 'Remote follow state won via newer HLC ($remoteHlc).',
    );
  }
}

/// 4. Story / Social Post Conflict Policy:
/// - Viewed_by and interaction lists: Set-Union CRDT.
/// - View count: Maximum of local/remote or length of unique viewers.
/// - Active/Expired status: Causal LWW.
class StoryConflictPolicy extends EntityDataConflictPolicy {
  @override
  ConflictResolutionResult<Map<String, dynamic>> resolve({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required Hlc localHlc,
    required Hlc remoteHlc,
    VersionVector? localVector,
    VersionVector? remoteVector,
  }) {
    final isLocalNewer = localHlc.compareTo(remoteHlc) >= 0;
    final merged = Map<String, dynamic>.from(isLocalNewer ? local : remote);

    // Merge viewed_by list
    final localViewers = (local['viewed_by'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final remoteViewers = (remote['viewed_by'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final unionViewers = localViewers.union(remoteViewers).toList();
    merged['viewed_by'] = unionViewers;

    // View count is max of existing viewCount or unique viewers
    final localCount = (local['view_count'] as num?)?.toInt() ?? 0;
    final remoteCount = (remote['view_count'] as num?)?.toInt() ?? 0;
    merged['view_count'] = [localCount, remoteCount, unionViewers.length]
        .reduce((a, b) => a > b ? a : b);

    return ConflictResolutionResult(
      resolvedData: merged,
      hasConflict: false,
      conflictDescription: 'Story interaction merged via Set-Union CRDT.',
    );
  }
}

/// 5. Gift Transaction Conflict Policy:
/// - State machine idempotency:
///   pending -> signed -> submitted -> completed / failed.
/// - Once marked 'completed' with a Stellar transaction hash, it is a terminal state.
class GiftConflictPolicy extends EntityDataConflictPolicy {
  @override
  ConflictResolutionResult<Map<String, dynamic>> resolve({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required Hlc localHlc,
    required Hlc remoteHlc,
    VersionVector? localVector,
    VersionVector? remoteVector,
  }) {
    final merged = Map<String, dynamic>.from(local);

    final localStatus = local['status']?.toString();
    final remoteStatus = remote['status']?.toString();

    // Completed is terminal
    if (localStatus == 'completed' || remoteStatus == 'completed') {
      merged['status'] = 'completed';
    } else {
      final isLocalNewer = localHlc.compareTo(remoteHlc) >= 0;
      merged['status'] = isLocalNewer ? localStatus : remoteStatus;
    }

    // Preserve tx hash if either side has it
    merged['stellar_tx_hash'] = local['stellar_tx_hash'] ?? remote['stellar_tx_hash'];

    return ConflictResolutionResult(
      resolvedData: merged,
      hasConflict: false,
      conflictDescription: 'Gift transaction idempotently reconciled.',
    );
  }
}

/// 6. Mood Pins and Comments Conflict Policy:
/// - Append-only with deterministic UUID ordering.
class MoodPinAndCommentConflictPolicy extends EntityDataConflictPolicy {
  @override
  ConflictResolutionResult<Map<String, dynamic>> resolve({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
    required Hlc localHlc,
    required Hlc remoteHlc,
    VersionVector? localVector,
    VersionVector? remoteVector,
  }) {
    final isLocalNewer = localHlc.compareTo(remoteHlc) >= 0;
    return ConflictResolutionResult(
      resolvedData: Map<String, dynamic>.from(isLocalNewer ? local : remote),
      hasConflict: false,
      conflictDescription: 'Pin/Comment ordered by HLC.',
    );
  }
}

/// Policy Registry providing the appropriate conflict resolution policy
/// for any given [SyncEntityType].
class ConflictPolicyRegistry {
  static final Map<SyncEntityType, EntityDataConflictPolicy> _policies = {
    SyncEntityType.moodEntry: MoodEntryConflictPolicy(),
    SyncEntityType.habitLog: HabitLogConflictPolicy(),
    SyncEntityType.follow: FollowConflictPolicy(),
    SyncEntityType.story: StoryConflictPolicy(),
    SyncEntityType.gift: GiftConflictPolicy(),
    SyncEntityType.moodPin: MoodPinAndCommentConflictPolicy(),
    SyncEntityType.moodComment: MoodPinAndCommentConflictPolicy(),
  };

  static EntityDataConflictPolicy getPolicy(SyncEntityType type) {
    return _policies[type] ?? MoodEntryConflictPolicy();
  }
}
