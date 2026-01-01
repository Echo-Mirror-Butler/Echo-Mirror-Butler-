/// Model for anonymous video post in the global feed
class VideoPostModel {
  final String id;
  final String videoUrl;
  final String moodTag; // 'happy', 'sad', 'motivated', 'reflective', 'grateful'
  final DateTime timestamp;
  final DateTime expiresAt;

  VideoPostModel({
    required this.id,
    required this.videoUrl,
    required this.moodTag,
    required this.timestamp,
    required this.expiresAt,
  });

  factory VideoPostModel.fromJson(Map<String, dynamic> json) {
    return VideoPostModel(
      id: json['id']?.toString() ?? '',
      videoUrl: json['videoUrl'] ?? '',
      moodTag: json['moodTag'] ?? 'reflective',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : DateTime.now().add(const Duration(hours: 24)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  /// Get time remaining until expiration
  Duration get timeRemaining {
    return expiresAt.difference(DateTime.now());
  }

  /// Check if video has expired
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Check if this is an image (based on URL extension)
  bool get isImage {
    final url = videoUrl.toLowerCase();
    return url.contains('.jpg') || 
           url.contains('.jpeg') || 
           url.contains('.png') || 
           url.contains('.gif') ||
           url.contains('/images/');
  }

  /// Check if this is a video (based on URL extension)
  bool get isVideo {
    return !isImage;
  }

  VideoPostModel copyWith({
    String? id,
    String? videoUrl,
    String? moodTag,
    DateTime? timestamp,
    DateTime? expiresAt,
  }) {
    return VideoPostModel(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      moodTag: moodTag ?? this.moodTag,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
