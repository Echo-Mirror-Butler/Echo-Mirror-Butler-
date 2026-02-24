/// Model for notifications when someone comments on your mood pin
class MoodCommentNotificationModel {
  final String id;
  final String moodPinId; // ID of the mood pin that was commented on
  final String commentId; // ID of the comment
  final String commentText; // Preview of the comment
  final String sentiment; // Sentiment of the mood pin
  final DateTime timestamp;
  final bool isRead;

  MoodCommentNotificationModel({
    required this.id,
    required this.moodPinId,
    required this.commentId,
    required this.commentText,
    required this.sentiment,
    required this.timestamp,
    this.isRead = false,
  });

  factory MoodCommentNotificationModel.fromJson(Map<String, dynamic> json) {
    return MoodCommentNotificationModel(
      id: json['id']?.toString() ?? '',
      moodPinId: json['moodPinId']?.toString() ?? '',
      commentId: json['commentId']?.toString() ?? '',
      commentText: json['commentText'] ?? '',
      sentiment: json['sentiment'] ?? 'neutral',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'moodPinId': moodPinId,
      'commentId': commentId,
      'commentText': commentText,
      'sentiment': sentiment,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  MoodCommentNotificationModel copyWith({
    String? id,
    String? moodPinId,
    String? commentId,
    String? commentText,
    String? sentiment,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return MoodCommentNotificationModel(
      id: id ?? this.id,
      moodPinId: moodPinId ?? this.moodPinId,
      commentId: commentId ?? this.commentId,
      commentText: commentText ?? this.commentText,
      sentiment: sentiment ?? this.sentiment,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
