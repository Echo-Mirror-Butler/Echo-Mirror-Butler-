class FollowModel {
  final int id;
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  const FollowModel({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  factory FollowModel.fromJson(Map<String, dynamic> json) {
    return FollowModel(
      id: json['id'] as int,
      followerId: json['follower_id'] as String,
      followingId: json['following_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class FriendMoodLog {
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final int? mood;
  final DateTime date;
  final bool hasPublicProfile;

  const FriendMoodLog({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.mood,
    required this.date,
    required this.hasPublicProfile,
  });

  factory FriendMoodLog.fromJson(Map<String, dynamic> json) {
    return FriendMoodLog(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      mood: json['mood'] as int?,
      date: DateTime.parse(json['date'] as String),
      hasPublicProfile: json['has_public_profile'] as bool,
    );
  }
}
