import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_models.dart';
import 'offline_storage_service.dart';

part 'sync_service.g.dart';

class SyncService {
  final OfflineStorageService offlineStorage;
  final SupabaseClient supabase;

  SyncService({
    required this.offlineStorage,
    required this.supabase,
  });

  Future<bool> syncPendingEntries() async {
    try {
      final pendingEntries = offlineStorage.getPendingLogEntries();
      if (pendingEntries.isEmpty) return true;

      for (final entry in pendingEntries) {
        await _syncLogEntry(entry);
        await offlineStorage.markEntrySynced(entry.id);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _syncLogEntry(LocalLogEntry entry) async {
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

@riverpod
SyncService syncService(SyncServiceRef ref) {
  final offlineStorage = ref.watch(offlineStorageServiceProvider);
  final supabase = Supabase.instance.client;
  return SyncService(
    offlineStorage: offlineStorage,
    supabase: supabase,
  );
}
