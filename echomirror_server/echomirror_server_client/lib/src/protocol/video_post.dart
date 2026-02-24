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

abstract class VideoPost implements _i1.SerializableModel {
  VideoPost._({
    this.id,
    required this.videoUrl,
    required this.moodTag,
    required this.timestamp,
    required this.expiresAt,
  });

  factory VideoPost({
    int? id,
    required String videoUrl,
    required String moodTag,
    required DateTime timestamp,
    required DateTime expiresAt,
  }) = _VideoPostImpl;

  factory VideoPost.fromJson(Map<String, dynamic> jsonSerialization) {
    return VideoPost(
      id: jsonSerialization['id'] as int?,
      videoUrl: jsonSerialization['videoUrl'] as String,
      moodTag: jsonSerialization['moodTag'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String videoUrl;

  String moodTag;

  DateTime timestamp;

  DateTime expiresAt;

  /// Returns a shallow copy of this [VideoPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  VideoPost copyWith({
    int? id,
    String? videoUrl,
    String? moodTag,
    DateTime? timestamp,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VideoPost',
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VideoPostImpl extends VideoPost {
  _VideoPostImpl({
    int? id,
    required String videoUrl,
    required String moodTag,
    required DateTime timestamp,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         videoUrl: videoUrl,
         moodTag: moodTag,
         timestamp: timestamp,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [VideoPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  VideoPost copyWith({
    Object? id = _Undefined,
    String? videoUrl,
    String? moodTag,
    DateTime? timestamp,
    DateTime? expiresAt,
  }) {
    return VideoPost(
      id: id is int? ? id : this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      moodTag: moodTag ?? this.moodTag,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
