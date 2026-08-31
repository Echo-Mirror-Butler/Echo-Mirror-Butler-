import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_models.dart';
import '../sync/conflict_policy.dart';
import '../sync/hlc.dart';
import '../sync/sync_mutation.dart';
import 'offline_storage_service.dart';

/// Outcome of a [SyncService.syncPendingEntries] run.
class SyncResult {
  const SyncResult({
    this.syncedCount = 0,
    this.failedCount = 0,
    this.rateLimited = false,
  });

  final int syncedCount;
  final int failedCount;

  /// True when the run stopped early because the server-side mood log rate
  /// limit (Postgres trigger on `log_entries`, error code PT429) was hit.
  /// Remaining entries stay queued and are retried on the next run.
  final bool rateLimited;

  bool get allSynced => failedCount == 0 && !rateLimited;
}

/// Pushes locally queued log entries to Supabase.
class SyncService {
  SyncService({required this.offlineStorage, SupabaseClient? supabase})
    : _injectedClient = supabase;

  final OfflineStorageService offlineStorage;

  /// Resolved lazily so constructing the service (e.g. from a provider in
  /// tests) doesn't require an initialized Supabase singleton.
  final SupabaseClient? _injectedClient;

  SupabaseClient get supabase => _injectedClient ?? Supabase.instance.client;

  /// Sync all pending entries, oldest first. Successfully synced entries are
  /// removed from the local queue. A failed entry is kept for the next run;
  /// failures don't block later entries unless the server rate limit is hit,
  /// in which case the run stops early (further inserts would fail too).
  Future<SyncResult> syncPendingEntries() async {
    final pendingEntries = offlineStorage.getPendingLogEntries();
    if (pendingEntries.isEmpty) return const SyncResult();

    var synced = 0;
    var failed = 0;
    for (final entry in pendingEntries) {
      try {
        await _syncLogEntry(entry);
        await offlineStorage.deleteLogEntry(entry.id);
        synced++;
      } on PostgrestException catch (e) {
        if (e.code == 'PT429') {
          debugPrint('[SyncService] rate limited, stopping sync run');
          return SyncResult(
            syncedCount: synced,
            failedCount: failed + (pendingEntries.length - synced - failed),
            rateLimited: true,
          );
        }
        debugPrint('[SyncService] failed to sync entry ${entry.id} -> $e');
        failed++;
      } catch (e) {
        debugPrint('[SyncService] failed to sync entry ${entry.id} -> $e');
        failed++;
      }
    }
    return SyncResult(syncedCount: synced, failedCount: failed);
  }

  /// Upload one entry, deduplicating against the server: if a row already
  /// exists for this user and date (e.g. logged from another device, or a
  /// previous sync run crashed after inserting), that row is updated instead
  /// of inserting a duplicate. New rows are upserted under the entry's
  /// client-generated UUID so retrying the same entry is idempotent.
  Future<void> _syncLogEntry(LocalLogEntry entry) async {
    final existing = await supabase
        .from('log_entries')
        .select('id, user_id, date, mood, habits, notes, updated_at')
        .eq('user_id', entry.userId)
        .eq('date', entry.date)
        .maybeSingle();

    if (existing != null) {
      final policy = ConflictPolicyRegistry.getPolicy(SyncEntityType.moodEntry);
      final localHlc = Hlc(
        millis: entry.updatedAt.toUtc().millisecondsSinceEpoch,
        counter: 0,
        nodeId: 'local',
      );
      final remoteUpdated = DateTime.tryParse(existing['updated_at']?.toString() ?? '') ??
          DateTime.now().toUtc();
      final remoteHlc = Hlc(
        millis: remoteUpdated.millisecondsSinceEpoch,
        counter: 0,
        nodeId: 'server',
      );

      final resolution = policy.resolve(
        local: {
          'mood': entry.mood,
          'habits': entry.habits,
          'notes': entry.notes,
          'updated_at': entry.updatedAt.toIso8601String(),
        },
        remote: existing,
        localHlc: localHlc,
        remoteHlc: remoteHlc,
      );

      final merged = resolution.resolvedData;
      await supabase
          .from('log_entries')
          .update({
            'mood': merged['mood'],
            'habits': merged['habits'] ?? [],
            'notes': merged['notes'],
            'updated_at': merged['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existing['id'] as String)
          .eq('user_id', entry.userId);
      return;
    }

    await supabase.from('log_entries').upsert({
      'id': entry.id,
      'user_id': entry.userId,
      'date': entry.date,
      'mood': entry.mood,
      'habits': entry.habits,
      'notes': entry.notes,
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
    });
  }

  Future<void> syncUserProfile(LocalUserProfile profile) async {
    await supabase.from('user_profiles').upsert({
      'user_id': profile.userId,
      'display_name': profile.displayName,
      'avatar_url': profile.avatarUrl,
      'timezone': profile.timezone,
      'overall_streak': profile.overallStreak,
    });
  }
}

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(offlineStorage: ref.watch(offlineStorageServiceProvider));
});
