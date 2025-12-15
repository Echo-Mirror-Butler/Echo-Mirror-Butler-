/// Model representing an insight or prediction
class InsightModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime date;
  final InsightType type;
  final DateTime createdAt;

  const InsightModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.createdAt,
  });

  factory InsightModel.fromJson(Map<String, dynamic> json) {
    return InsightModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      type: InsightType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InsightType.general,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

enum InsightType {
  prediction,
  habit,
  mood,
  general,
}

