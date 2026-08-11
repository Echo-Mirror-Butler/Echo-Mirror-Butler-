import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/follow_model.dart';
import '../../data/repositories/follow_repository.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';

final isPublicProfileProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authProvider);
  final userId = authState.user?.id;
  if (userId == null) return true;
  final response = await Supabase.instance.client
      .from('profiles')
      .select('public_profile')
      .eq('id', userId)
      .maybeSingle();
  if (response != null) {
    return (response['public_profile'] as bool?) ?? true;
  }
  return true;
});

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});

final followingListProvider = FutureProvider<List<FollowModel>>((ref) async {
  final authState = ref.watch(authProvider);
  final userId = authState.user?.id;
  if (userId == null) return [];
  return ref.read(followRepositoryProvider).getFollowing(userId);
});

final friendMoodLogsProvider = FutureProvider<List<FriendMoodLog>>((ref) async {
  final authState = ref.watch(authProvider);
  final userId = authState.user?.id;
  if (userId == null) return [];
  return ref.read(followRepositoryProvider).getFriendsMoodLogs(userId);
});

final followersCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  return ref.read(followRepositoryProvider).getFollowersCount(userId);
});

final followingCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  return ref.read(followRepositoryProvider).getFollowingCount(userId);
});

final isFollowingProvider = FutureProvider.family<bool, String>((ref, targetUserId) async {
  final authState = ref.watch(authProvider);
  final userId = authState.user?.id;
  if (userId == null || userId == targetUserId) return false;
  return ref.read(followRepositoryProvider).isFollowing(userId, targetUserId);
});

/// Record a milestone encouragement when a user hits a streak milestone.
/// Inserts a system notification into gift_transactions for tracking.
Future<bool> sendStreakEncouragement({
  required String userId,
  required int streak,
}) async {
  if (streak < 3 || streak % 3 != 0) return false;
  try {
    await Supabase.instance.client.from('gift_transactions').insert({
      'sender_user_id': null,
      'recipient_user_id': userId,
      'echo_amount': 0,
      'stellar_tx_hash': null,
      'message': 'Congratulations on your $streak-day mood streak! Keep going!',
      'status': 'milestone',
    });
    return true;
  } catch (_) {
    return false;
  }
}
