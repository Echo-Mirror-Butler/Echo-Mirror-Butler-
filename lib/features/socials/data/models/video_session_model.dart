/// Model representing a video/voice call session
class VideoSessionModel {
  final String id;
  final String hostId;
  final String hostName;
  final String? hostAvatarUrl;
  final String title;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int participantCount;
  final bool isVideoEnabled;
  final bool isVoiceOnly;
  final bool isActive;

  const VideoSessionModel({
    required this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    required this.title,
    required this.createdAt,
    this.expiresAt,
    required this.participantCount,
    this.isVideoEnabled = true,
    this.isVoiceOnly = false,
    required this.isActive,
  });

  factory VideoSessionModel.fromJson(Map<String, dynamic> json) {
    return VideoSessionModel(
      id: json['id'] as String,
      hostId: json['hostId'] as String,
      hostName: json['hostName'] as String,
      hostAvatarUrl: json['hostAvatarUrl'] as String?,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      participantCount: json['participantCount'] as int? ?? 0,
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? true,
      isVoiceOnly: json['isVoiceOnly'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'participantCount': participantCount,
      'isVideoEnabled': isVideoEnabled,
      'isVoiceOnly': isVoiceOnly,
      'isActive': isActive,
    };
  }

  VideoSessionModel copyWith({
    String? id,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? title,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? participantCount,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isActive,
  }) {
    return VideoSessionModel(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      participantCount: participantCount ?? this.participantCount,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isVoiceOnly: isVoiceOnly ?? this.isVoiceOnly,
      isActive: isActive ?? this.isActive,
    );
  }
}
