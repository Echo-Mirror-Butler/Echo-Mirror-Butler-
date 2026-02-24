part of 'protocol.dart';

class MoodPin extends SerializableModel {
  MoodPin({
    this.id,
    required this.sentiment,
    required this.gridLat,
    required this.gridLon,
    required this.timestamp,
    required this.expiresAt,
    this.userId,
  });

  factory MoodPin.fromJson(Map<String, dynamic> json) {
    return MoodPin(
      id: json['id'] as int?,
      sentiment: json['sentiment'] as String,
      gridLat: (json['gridLat'] as num).toDouble(),
      gridLon: (json['gridLon'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      userId: json['userId'] as int?,
    );
  }

  int? id;
  String sentiment;
  double gridLat;
  double gridLon;
  DateTime timestamp;
  DateTime expiresAt;
  int? userId;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  MoodPin copyWith({
    int? id,
    String? sentiment,
    double? gridLat,
    double? gridLon,
    DateTime? timestamp,
    DateTime? expiresAt,
    int? userId,
  }) {
    return MoodPin(
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
