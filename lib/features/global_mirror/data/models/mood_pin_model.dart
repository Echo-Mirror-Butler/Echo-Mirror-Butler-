/// Model for anonymous mood pin on the global map
class MoodPinModel {
  final String id;
  final String
  sentiment; // 'positive', 'neutral', 'negative', 'excited', 'calm', 'anxious'
  final double gridLat; // Anonymized latitude (rounded to 0.1 degrees)
  final double gridLon; // Anonymized longitude (rounded to 0.1 degrees)
  final DateTime timestamp;
  final DateTime? expiresAt;
  // Optional: non-null only when the pin owner has opted into gifting
  final int? userId;

  MoodPinModel({
    required this.id,
    required this.sentiment,
    required this.gridLat,
    required this.gridLon,
    required this.timestamp,
    this.expiresAt,
    this.userId,
  });

  factory MoodPinModel.fromJson(Map<String, dynamic> json) {
    return MoodPinModel(
      id: json['id']?.toString() ?? '',
      sentiment: json['sentiment'] ?? 'neutral',
      gridLat: (json['gridLat'] ?? 0.0).toDouble(),
      gridLon: (json['gridLon'] ?? 0.0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      userId: json['userId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  /// Anonymize coordinates by rounding to 0.1 degrees (~11km precision)
  static double anonymizeCoordinate(double coordinate) {
    return (coordinate * 10).round() / 10;
  }

  MoodPinModel copyWith({
    String? id,
    String? sentiment,
    double? gridLat,
    double? gridLon,
    DateTime? timestamp,
    DateTime? expiresAt,
    int? userId,
  }) {
    return MoodPinModel(
      id: id ?? this.id,
      sentiment: sentiment ?? this.sentiment,
      gridLat: gridLat ?? this.gridLat,
      gridLon: gridLon ?? this.gridLon,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
    );
  }
}
