part of 'protocol.dart';

class MoodPinComment extends SerializableModel {
  MoodPinComment({
    this.id,
    required this.moodPinId,
    required this.text,
    required this.timestamp,
    this.userId,
  });

  factory MoodPinComment.fromJson(Map<String, dynamic> json) {
    return MoodPinComment(
      id: json['id'] as int?,
      moodPinId: json['moodPinId'] as int,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as int?,
    );
  }

  int? id;
  int moodPinId;
  String text;
  DateTime timestamp;
  int? userId;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  MoodPinComment copyWith({
    int? id,
    int? moodPinId,
    String? text,
    DateTime? timestamp,
    int? userId,
  }) {
    return MoodPinComment(
      id: id ?? this.id,
      moodPinId: moodPinId ?? this.moodPinId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}
