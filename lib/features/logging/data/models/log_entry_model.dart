/// Model representing a daily log entry
class LogEntryModel {
  final String id;
  final String userId;
  final DateTime date;
  final int? mood; // 1-5 scale
  final List<String> habits;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LogEntryModel({
    required this.id,
    required this.userId,
    required this.date,
    this.mood,
    this.habits = const [],
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory LogEntryModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final parsedDate = rawDate is DateTime
        ? rawDate
        : DateTime.parse(rawDate as String);

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final parsedCreatedAt = rawCreatedAt is DateTime
        ? rawCreatedAt
        : DateTime.parse(rawCreatedAt as String);

    final rawUpdatedAt = json['updated_at'] ?? json['updatedAt'];
    final parsedUpdatedAt = rawUpdatedAt == null
        ? null
        : (rawUpdatedAt is DateTime
              ? rawUpdatedAt
              : DateTime.parse(rawUpdatedAt as String));

    return LogEntryModel(
      id: json['id'].toString(),
      userId: (json['user_id'] ?? json['userId']) as String,
      date: parsedDate,
      mood: json['mood'] as int?,
      habits: List<String>.from(json['habits'] as List? ?? []),
      notes: json['notes'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'mood': mood,
      'habits': habits,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  LogEntryModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    int? mood,
    List<String>? habits,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LogEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      habits: habits ?? this.habits,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
