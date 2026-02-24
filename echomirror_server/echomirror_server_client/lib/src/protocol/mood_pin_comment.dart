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

abstract class MoodPinComment implements _i1.SerializableModel {
  MoodPinComment._({
    this.id,
    required this.moodPinId,
    required this.text,
    required this.timestamp,
    this.userId,
  });

  factory MoodPinComment({
    int? id,
    required int moodPinId,
    required String text,
    required DateTime timestamp,
    int? userId,
  }) = _MoodPinCommentImpl;

  factory MoodPinComment.fromJson(Map<String, dynamic> jsonSerialization) {
    return MoodPinComment(
      id: jsonSerialization['id'] as int?,
      moodPinId: jsonSerialization['moodPinId'] as int,
      text: jsonSerialization['text'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      userId: jsonSerialization['userId'] as int?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int moodPinId;

  String text;

  DateTime timestamp;

  int? userId;

  /// Returns a shallow copy of this [MoodPinComment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MoodPinComment copyWith({
    int? id,
    int? moodPinId,
    String? text,
    DateTime? timestamp,
    int? userId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodPinComment',
      if (id != null) 'id': id,
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp.toJson(),
      if (userId != null) 'userId': userId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MoodPinCommentImpl extends MoodPinComment {
  _MoodPinCommentImpl({
    int? id,
    required int moodPinId,
    required String text,
    required DateTime timestamp,
    int? userId,
  }) : super._(
         id: id,
         moodPinId: moodPinId,
         text: text,
         timestamp: timestamp,
         userId: userId,
       );

  /// Returns a shallow copy of this [MoodPinComment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MoodPinComment copyWith({
    Object? id = _Undefined,
    int? moodPinId,
    String? text,
    DateTime? timestamp,
    Object? userId = _Undefined,
  }) {
    return MoodPinComment(
      id: id is int? ? id : this.id,
      moodPinId: moodPinId ?? this.moodPinId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      userId: userId is int? ? userId : this.userId,
    );
  }
}
