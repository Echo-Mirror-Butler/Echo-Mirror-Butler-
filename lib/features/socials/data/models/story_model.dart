import 'package:echomirror_server_client/echomirror_server_client.dart' as serverpod;

/// Story model for Instagram-style stories
class StoryModel {
  final int id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final List<String> viewedBy;
  final bool isActive;

  StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.imageUrls,
    required this.createdAt,
    required this.expiresAt,
    required this.viewCount,
    required this.viewedBy,
    required this.isActive,
  });

  factory StoryModel.fromServerpod(serverpod.Story story) {
    return StoryModel(
      id: story.id!,
      userId: story.userId,
      userName: story.userName,
      userAvatarUrl: story.userAvatarUrl,
      imageUrls: story.imageUrls,
      createdAt: story.createdAt,
      expiresAt: story.expiresAt,
      viewCount: story.viewCount,
      viewedBy: story.viewedBy,
      isActive: story.isActive,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasViewed => false; // Will be set based on current user
}

