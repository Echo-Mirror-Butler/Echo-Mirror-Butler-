import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/follow_model.dart';

class FollowRepository {
  Future<List<FollowModel>> getFollowing(String userId) async {
    final response = await Supabase.instance.client
        .from('user_follows')
        .select()
        .eq('follower_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => FollowModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<FollowModel>> getFollowers(String userId) async {
    final response = await Supabase.instance.client
        .from('user_follows')
        .select()
        .eq('following_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => FollowModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isFollowing(String followerId, String followingId) async {
    final response = await Supabase.instance.client
        .from('user_follows')
        .select('id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return response != null;
  }

  Future<void> follow(String followerId, String followingId) async {
    await Supabase.instance.client.from('user_follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  Future<void> unfollow(String followerId, String followingId) async {
    await Supabase.instance.client
        .from('user_follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
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
