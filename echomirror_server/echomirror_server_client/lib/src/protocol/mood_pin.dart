/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class MoodPin implements _i1.SerializableModel {
  MoodPin._({
    this.id,
    required this.sentiment,
    required this.gridLat,
    required this.gridLon,
    required this.timestamp,
    required this.expiresAt,
    this.userId,
  });

  factory MoodPin({
    int? id,
    required String sentiment,
    required double gridLat,
    required double gridLon,
    required DateTime timestamp,
    required DateTime expiresAt,
    int? userId,
  }) = _MoodPinImpl;

  factory MoodPin.fromJson(Map<String, dynamic> jsonSerialization) {
    return MoodPin(
      id: jsonSerialization['id'] as int?,
      sentiment: jsonSerialization['sentiment'] as String,
      gridLat: (jsonSerialization['gridLat'] as num).toDouble(),
      gridLon: (jsonSerialization['gridLon'] as num).toDouble(),
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      userId: jsonSerialization['userId'] as int?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String sentiment;

  double gridLat;

  double gridLon;

  DateTime timestamp;

  DateTime expiresAt;

  int? userId;

  /// Returns a shallow copy of this [MoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MoodPin copyWith({
    int? id,
    String? sentiment,
    double? gridLat,
    double? gridLon,
    DateTime? timestamp,
    DateTime? expiresAt,
    int? userId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodPin',
      if (id != null) 'id': id,
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
      'timestamp': timestamp.toJson(),
      'expiresAt': expiresAt.toJson(),
      if (userId != null) 'userId': userId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MoodPinImpl extends MoodPin {
  _MoodPinImpl({
    int? id,
    required String sentiment,
    required double gridLat,
    required double gridLon,
    required DateTime timestamp,
    required DateTime expiresAt,
    int? userId,
  }) : super._(
         id: id,
         sentiment: sentiment,
         gridLat: gridLat,
         gridLon: gridLon,
         timestamp: timestamp,
         expiresAt: expiresAt,
         userId: userId,
       );

  /// Returns a shallow copy of this [MoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MoodPin copyWith({
    Object? id = _Undefined,
    String? sentiment,
    double? gridLat,
    double? gridLon,
    DateTime? timestamp,
    DateTime? expiresAt,
    Object? userId = _Undefined,
  }) {
    return MoodPin(
      id: id is int? ? id : this.id,
      sentiment: sentiment ?? this.sentiment,
      gridLat: gridLat ?? this.gridLat,
      gridLon: gridLon ?? this.gridLon,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId is int? ? userId : this.userId,
    );
  }
}
