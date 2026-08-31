import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/sync/local_first_storage_service.dart';
import '../../../../core/sync/sync_mutation.dart';
import '../models/follow_model.dart';

class FollowRepository {
  FollowRepository({
    SupabaseClient? client,
    LocalFirstStorageService? localFirstStorage,
  })  : _injectedClient = client,
        _localFirstStorage = localFirstStorage;

  final SupabaseClient? _injectedClient;
  final LocalFirstStorageService? _localFirstStorage;

  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  Future<List<FollowModel>> getFollowing(String userId) async {
    try {
      final response = await _supabase
          .from('user_follows')
          .select()
          .eq('follower_id', userId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => FollowModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final storage = _localFirstStorage;
      if (storage != null && storage.isInitialized) {
        final snapshots = storage.getAllEntitySnapshots(SyncEntityType.follow);
        return snapshots
            .where((s) => s['follower_id'] == userId)
            .map((s) => FollowModel.fromJson(s))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<FollowModel>> getFollowers(String userId) async {
    final response = await _supabase
        .from('user_follows')
        .select()
        .eq('following_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => FollowModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    final storage = _localFirstStorage;
    if (storage != null && storage.isInitialized) {
      final snapshot = storage.getEntitySnapshot(
        SyncEntityType.follow,
        '$followerId:$followingId',
      );
      if (snapshot != null) {
        return true;
      }
    }

    final response = await _supabase
        .from('user_follows')
        .select('id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return response != null;
  }

  Future<void> follow(String followerId, String followingId) async {
    final storage = _localFirstStorage;
    final payload = {
      'follower_id': followerId,
      'following_id': followingId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (storage != null) {
      await storage.stageMutation(
        entityId: '$followerId:$followingId',
        entityType: SyncEntityType.follow,
        action: SyncMutationAction.create,
        payload: payload,
        priority: SyncPriority.high,
      );
    }

    try {
      await _supabase.from('user_follows').insert(payload);
    } catch (e) {
      if (storage == null) rethrow;
    }
  }

  Future<void> unfollow(String followerId, String followingId) async {
    final storage = _localFirstStorage;
    if (storage != null) {
      await storage.stageMutation(
        entityId: '$followerId:$followingId',
        entityType: SyncEntityType.follow,
        action: SyncMutationAction.delete,
        payload: {
          'follower_id': followerId,
          'following_id': followingId,
        },
        priority: SyncPriority.high,
      );
    }

    try {
      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } catch (e) {
      if (storage == null) rethrow;
    }
  }

  Future<List<FriendMoodLog>> getFriendsMoodLogs(
    String userId, {
    int days = 1,
  }) async {
    final response = await Supabase.instance.client
        .rpc('get_friends_mood_logs', params: {
      'p_user_id': userId,
      'p_days': days,
    });
    return (response as List)
        .map((json) => FriendMoodLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<int> getFollowersCount(String userId) async {
    final response = await Supabase.instance.client
        .rpc('get_followers_count', params: {'p_user_id': userId});
    return (response as int);
  }

  Future<int> getFollowingCount(String userId) async {
    final response = await Supabase.instance.client
        .rpc('get_following_count', params: {'p_user_id': userId});
    return (response as int);
  }
}
