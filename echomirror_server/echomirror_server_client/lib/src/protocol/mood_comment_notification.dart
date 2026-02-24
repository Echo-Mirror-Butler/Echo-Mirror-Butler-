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

abstract class MoodCommentNotification implements _i1.SerializableModel {
  MoodCommentNotification._({
    this.id,
    required this.userId,
    required this.moodPinId,
    required this.commentId,
    required this.commentText,
    required this.sentiment,
    required this.timestamp,
    required this.isRead,
  });

  factory MoodCommentNotification({
    int? id,
    required int userId,
    required int moodPinId,
    required int commentId,
    required String commentText,
    required String sentiment,
    required DateTime timestamp,
    required bool isRead,
  }) = _MoodCommentNotificationImpl;

  factory MoodCommentNotification.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return MoodCommentNotification(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      moodPinId: jsonSerialization['moodPinId'] as int,
      commentId: jsonSerialization['commentId'] as int,
      commentText: jsonSerialization['commentText'] as String,
      sentiment: jsonSerialization['sentiment'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      isRead: jsonSerialization['isRead'] as bool,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  int moodPinId;

  int commentId;

  String commentText;

  String sentiment;

  DateTime timestamp;

  bool isRead;

  /// Returns a shallow copy of this [MoodCommentNotification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MoodCommentNotification copyWith({
    int? id,
    int? userId,
    int? moodPinId,
    int? commentId,
    String? commentText,
    String? sentiment,
    DateTime? timestamp,
    bool? isRead,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodCommentNotification',
      if (id != null) 'id': id,
      'userId': userId,
      'moodPinId': moodPinId,
      'commentId': commentId,
      'commentText': commentText,
      'sentiment': sentiment,
      'timestamp': timestamp.toJson(),
      'isRead': isRead,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MoodCommentNotificationImpl extends MoodCommentNotification {
  _MoodCommentNotificationImpl({
    int? id,
    required int userId,
    required int moodPinId,
    required int commentId,
    required String commentText,
    required String sentiment,
    required DateTime timestamp,
    required bool isRead,
  }) : super._(
         id: id,
         userId: userId,
         moodPinId: moodPinId,
         commentId: commentId,
         commentText: commentText,
         sentiment: sentiment,
         timestamp: timestamp,
         isRead: isRead,
       );

  /// Returns a shallow copy of this [MoodCommentNotification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MoodCommentNotification copyWith({
    Object? id = _Undefined,
    int? userId,
    int? moodPinId,
    int? commentId,
    String? commentText,
    String? sentiment,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return MoodCommentNotification(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      moodPinId: moodPinId ?? this.moodPinId,
      commentId: commentId ?? this.commentId,
      commentText: commentText ?? this.commentText,
      sentiment: sentiment ?? this.sentiment,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
