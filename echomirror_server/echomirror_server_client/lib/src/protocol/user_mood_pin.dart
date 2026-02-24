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

abstract class UserMoodPin implements _i1.SerializableModel {
  UserMoodPin._({
    this.id,
    required this.userId,
    required this.moodPinId,
    required this.createdAt,
  });

  factory UserMoodPin({
    int? id,
    required int userId,
    required int moodPinId,
    required DateTime createdAt,
  }) = _UserMoodPinImpl;

  factory UserMoodPin.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserMoodPin(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      moodPinId: jsonSerialization['moodPinId'] as int,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  int moodPinId;

  DateTime createdAt;

  /// Returns a shallow copy of this [UserMoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  UserMoodPin copyWith({
    int? id,
    int? userId,
    int? moodPinId,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserMoodPin',
      if (id != null) 'id': id,
      'userId': userId,
      'moodPinId': moodPinId,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserMoodPinImpl extends UserMoodPin {
  _UserMoodPinImpl({
    int? id,
    required int userId,
    required int moodPinId,
    required DateTime createdAt,
  }) : super._(
         id: id,
         userId: userId,
         moodPinId: moodPinId,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [UserMoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  UserMoodPin copyWith({
    Object? id = _Undefined,
    int? userId,
    int? moodPinId,
    DateTime? createdAt,
  }) {
    return UserMoodPin(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      moodPinId: moodPinId ?? this.moodPinId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
