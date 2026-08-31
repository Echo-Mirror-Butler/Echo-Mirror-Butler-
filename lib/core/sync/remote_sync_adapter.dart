import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_mutation.dart';

/// Abstract adapter for communicating entity mutations with remote backend systems.
abstract class RemoteSyncAdapter {
  /// Fetches the latest remote state for an entity, or null if it doesn't exist remotely.
  Future<Map<String, dynamic>?> fetchRemoteEntity(
    SyncEntityType type,
    String entityId,
    Map<String, dynamic> payload,
  );

  /// Pushes a resolved mutation to the remote backend.
  Future<void> pushMutation(
    SyncMutation mutation,
    Map<String, dynamic> payload,
  );

  /// Pulls remote updates since [since] timestamp.
  Future<List<Map<String, dynamic>>> pullRemoteChanges(
    SyncEntityType type, {
    DateTime? since,
    int? limit,
  });
}

/// Supabase implementation of [RemoteSyncAdapter].
class SupabaseRemoteSyncAdapter implements RemoteSyncAdapter {
  SupabaseRemoteSyncAdapter({SupabaseClient? client})
      : _injectedClient = client;

  final SupabaseClient? _injectedClient;

  SupabaseClient get _supabase =>
      _injectedClient ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>?> fetchRemoteEntity(
    SyncEntityType type,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    try {
      switch (type) {
        case SyncEntityType.moodEntry:
          final userId = payload['user_id']?.toString() ?? '';
          final date = payload['date']?.toString() ?? '';
          if (userId.isNotEmpty && date.isNotEmpty) {
            final row = await _supabase
                .from('log_entries')
                .select()
                .eq('user_id', userId)
                .eq('date', date)
                .maybeSingle();
            return row;
          }
          final row = await _supabase
              .from('log_entries')
              .select()
              .eq('id', entityId)
              .maybeSingle();
          return row;

        case SyncEntityType.habitLog:
          final userId = payload['user_id']?.toString() ?? '';
          final date = payload['date']?.toString() ?? '';
          if (userId.isNotEmpty && date.isNotEmpty) {
            return await _supabase
                .from('log_entries')
                .select('id, user_id, date, habits, updated_at')
                .eq('user_id', userId)
                .eq('date', date)
                .maybeSingle();
          }
          return null;

        case SyncEntityType.follow:
          final followerId = payload['follower_id']?.toString() ?? '';
          final followingId = payload['following_id']?.toString() ?? '';
          if (followerId.isNotEmpty && followingId.isNotEmpty) {
            return await _supabase
                .from('user_follows')
                .select()
                .eq('follower_id', followerId)
                .eq('following_id', followingId)
                .maybeSingle();
          }
          return null;

        case SyncEntityType.story:
          return await _supabase
              .from('stories')
              .select()
              .eq('id', entityId)
              .maybeSingle();

        case SyncEntityType.gift:
          return await _supabase
              .from('gift_transactions')
              .select()
              .eq('id', entityId)
              .maybeSingle();

        case SyncEntityType.moodPin:
          return await _supabase
              .from('mood_pins')
              .select()
              .eq('id', entityId)
              .maybeSingle();

        case SyncEntityType.moodComment:
          return await _supabase
              .from('mood_pin_comments')
              .select()
              .eq('id', entityId)
              .maybeSingle();
      }
    } catch (e) {
      debugPrint('[SupabaseRemoteSyncAdapter] Error fetching remote $type ($entityId): $e');
      return null;
    }
  }

  @override
  Future<void> pushMutation(
    SyncMutation mutation,
    Map<String, dynamic> payload,
  ) async {
    switch (mutation.entityType) {
      case SyncEntityType.moodEntry:
        await _pushMoodEntry(mutation, payload);
        break;

      case SyncEntityType.habitLog:
        await _pushHabitLog(mutation, payload);
        break;

      case SyncEntityType.follow:
        await _pushFollow(mutation, payload);
        break;

      case SyncEntityType.story:
        await _pushStory(mutation, payload);
        break;

      case SyncEntityType.gift:
        await _pushGift(mutation, payload);
        break;

      case SyncEntityType.moodPin:
        await _pushMoodPin(mutation, payload);
        break;

      case SyncEntityType.moodComment:
        await _pushMoodComment(mutation, payload);
        break;
    }
  }

  Future<void> _pushMoodEntry(SyncMutation mutation, Map<String, dynamic> payload) async {
    if (mutation.action == SyncMutationAction.delete) {
      final userId = payload['user_id']?.toString() ?? '';
      await _supabase
          .from('log_entries')
          .delete()
          .eq('id', mutation.entityId)
          .eq('user_id', userId);
      return;
    }

    final userId = payload['user_id']?.toString() ?? '';
    final date = payload['date']?.toString() ?? '';

    final existing = await _supabase
        .from('log_entries')
        .select('id')
        .eq('user_id', userId)
        .eq('date', date)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('log_entries')
          .update({
            'mood': payload['mood'],
            'habits': payload['habits'] ?? [],
            'notes': payload['notes'],
            'updated_at': payload['updated_at'] ?? DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id'] as String)
          .eq('user_id', userId);
    } else {
      await _supabase.from('log_entries').upsert({
        'id': mutation.entityId,
        'user_id': userId,
        'date': date,
        'mood': payload['mood'],
        'habits': payload['habits'] ?? [],
        'notes': payload['notes'],
        'created_at': payload['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': payload['updated_at'] ?? DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _pushHabitLog(SyncMutation mutation, Map<String, dynamic> payload) async {
    final userId = payload['user_id']?.toString() ?? '';
    final date = payload['date']?.toString() ?? '';

    final existing = await _supabase
        .from('log_entries')
        .select('id, habits')
        .eq('user_id', userId)
        .eq('date', date)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('log_entries')
          .update({
            'habits': payload['habits'] ?? [],
            'updated_at': payload['updated_at'] ?? DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id'] as String);
    } else {
      await _supabase.from('log_entries').upsert({
        'id': mutation.entityId,
        'user_id': userId,
        'date': date,
        'habits': payload['habits'] ?? [],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _pushFollow(SyncMutation mutation, Map<String, dynamic> payload) async {
    final followerId = payload['follower_id']?.toString() ?? '';
    final followingId = payload['following_id']?.toString() ?? '';

    if (mutation.action == SyncMutationAction.delete) {
      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } else {
      await _supabase.from('user_follows').upsert({
        'follower_id': followerId,
        'following_id': followingId,
        'created_at': payload['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _pushStory(SyncMutation mutation, Map<String, dynamic> payload) async {
    if (mutation.action == SyncMutationAction.delete) {
      await _supabase
          .from('stories')
          .delete()
          .eq('id', mutation.entityId);
    } else {
      await _supabase.from('stories').upsert(payload);
    }
  }

  Future<void> _pushGift(SyncMutation mutation, Map<String, dynamic> payload) async {
    await _supabase.from('gift_transactions').upsert(payload);
  }

  Future<void> _pushMoodPin(SyncMutation mutation, Map<String, dynamic> payload) async {
    await _supabase.from('mood_pins').upsert(payload);
  }

  Future<void> _pushMoodComment(SyncMutation mutation, Map<String, dynamic> payload) async {
    await _supabase.from('mood_pin_comments').upsert(payload);
  }

  @override
  Future<List<Map<String, dynamic>>> pullRemoteChanges(
    SyncEntityType type, {
    DateTime? since,
    int? limit,
  }) async {
    final table = switch (type) {
      SyncEntityType.moodEntry => 'log_entries',
      SyncEntityType.habitLog => 'log_entries',
      SyncEntityType.follow => 'user_follows',
      SyncEntityType.story => 'stories',
      SyncEntityType.gift => 'gift_transactions',
      SyncEntityType.moodPin => 'mood_pins',
      SyncEntityType.moodComment => 'mood_pin_comments',
    };

    PostgrestTransformBuilder<PostgrestList> transformQuery;
    if (since != null) {
      final filter = _supabase
          .from(table)
          .select()
          .gt('updated_at', since.toIso8601String());
      transformQuery = limit != null ? filter.limit(limit) : filter;
    } else {
      final selectQuery = _supabase.from(table).select();
      transformQuery = limit != null ? selectQuery.limit(limit) : selectQuery;
    }

    final response = await transformQuery;
    return (response as List).cast<Map<String, dynamic>>();
  }
}
