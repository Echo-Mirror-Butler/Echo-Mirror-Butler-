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
    this.userId,
    required this.text,
    required this.timestamp,
  });

  factory MoodPinComment({
    int? id,
    required int moodPinId,
    int? userId,
    required String text,
    required DateTime timestamp,
  }) = _MoodPinCommentImpl;

  factory MoodPinComment.fromJson(Map<String, dynamic> jsonSerialization) {
    return MoodPinComment(
      id: jsonSerialization['id'] as int?,
      moodPinId: jsonSerialization['moodPinId'] as int,
      userId: jsonSerialization['userId'] as int?,
      text: jsonSerialization['text'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int moodPinId;

  int? userId;

  String text;

  DateTime timestamp;

  /// Returns a shallow copy of this [MoodPinComment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MoodPinComment copyWith({
    int? id,
    int? moodPinId,
    int? userId,
    String? text,
    DateTime? timestamp,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodPinComment',
      if (id != null) 'id': id,
      'moodPinId': moodPinId,
      if (userId != null) 'userId': userId,
      'text': text,
      'timestamp': timestamp.toJson(),
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
    int? userId,
    required String text,
    required DateTime timestamp,
  }) : super._(
         id: id,
         moodPinId: moodPinId,
         userId: userId,
         text: text,
         timestamp: timestamp,
       );

  /// Returns a shallow copy of this [MoodPinComment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MoodPinComment copyWith({
    Object? id = _Undefined,
    int? moodPinId,
    Object? userId = _Undefined,
    String? text,
    DateTime? timestamp,
  }) {
    return MoodPinComment(
      id: id is int? ? id : this.id,
      moodPinId: moodPinId ?? this.moodPinId,
      userId: userId is int? ? userId : this.userId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
