part of 'protocol.dart';

class VideoPost extends SerializableModel {
  VideoPost({
    this.id,
    required this.videoUrl,
    required this.moodTag,
    required this.timestamp,
    required this.expiresAt,
    this.userId,
  });

  factory VideoPost.fromJson(Map<String, dynamic> json) {
    return VideoPost(
      id: json['id'] as int?,
      videoUrl: json['videoUrl'] as String,
      moodTag: json['moodTag'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      userId: json['userId'] as int?,
    );
  }

  int? id;
  String videoUrl;
  String moodTag;
  DateTime timestamp;
  DateTime expiresAt;
  int? userId;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  VideoPost copyWith({
    int? id,
    String? videoUrl,
    String? moodTag,
    DateTime? timestamp,
    DateTime? expiresAt,
    int? userId,
  }) {
    return VideoPost(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      moodTag: moodTag ?? this.moodTag,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
    );
  }
}
