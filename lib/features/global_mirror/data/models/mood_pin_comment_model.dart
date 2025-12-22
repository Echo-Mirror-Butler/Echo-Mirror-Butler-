/// Model for comments on mood pins
class MoodPinCommentModel {
  final String id;
  final String moodPinId; // ID of the mood pin this comment is on
  final String text; // Comment text
  final DateTime timestamp;
  final String? userId; // Optional: for tracking if comment is from current user

  MoodPinCommentModel({
    required this.id,
    required this.moodPinId,
    required this.text,
    required this.timestamp,
    this.userId,
  });

  factory MoodPinCommentModel.fromJson(Map<String, dynamic> json) {
    return MoodPinCommentModel(
      id: json['id']?.toString() ?? '',
      moodPinId: json['moodPinId']?.toString() ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      userId: json['userId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  MoodPinCommentModel copyWith({
    String? id,
    String? moodPinId,
    String? text,
    DateTime? timestamp,
    String? userId,
  }) {
    return MoodPinCommentModel(
      id: id ?? this.id,
      moodPinId: moodPinId ?? this.moodPinId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}

