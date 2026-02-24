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

abstract class VideoSession implements _i1.SerializableModel {
  VideoSession._({
    this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    required this.title,
    required this.createdAt,
    required this.expiresAt,
    required this.participantCount,
    required this.isVideoEnabled,
    required this.isVoiceOnly,
    required this.isActive,
  });

  factory VideoSession({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    required DateTime createdAt,
    required DateTime expiresAt,
    required int participantCount,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    required bool isActive,
  }) = _VideoSessionImpl;

  factory VideoSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return VideoSession(
      id: jsonSerialization['id'] as int?,
      hostId: jsonSerialization['hostId'] as String,
      hostName: jsonSerialization['hostName'] as String,
      hostAvatarUrl: jsonSerialization['hostAvatarUrl'] as String?,
      title: jsonSerialization['title'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      participantCount: jsonSerialization['participantCount'] as int,
      isVideoEnabled: jsonSerialization['isVideoEnabled'] as bool,
      isVoiceOnly: jsonSerialization['isVoiceOnly'] as bool,
      isActive: jsonSerialization['isActive'] as bool,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String hostId;

  String hostName;

  String? hostAvatarUrl;

  String title;

  DateTime createdAt;

  DateTime expiresAt;

  int participantCount;

  bool isVideoEnabled;

  bool isVoiceOnly;

  bool isActive;

  /// Returns a shallow copy of this [VideoSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  VideoSession copyWith({
    int? id,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? title,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? participantCount,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isActive,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VideoSession',
      if (id != null) 'id': id,
      'hostId': hostId,
      'hostName': hostName,
      if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'participantCount': participantCount,
      'isVideoEnabled': isVideoEnabled,
      'isVoiceOnly': isVoiceOnly,
      'isActive': isActive,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VideoSessionImpl extends VideoSession {
  _VideoSessionImpl({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    required DateTime createdAt,
    required DateTime expiresAt,
    required int participantCount,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    required bool isActive,
  }) : super._(
         id: id,
         hostId: hostId,
         hostName: hostName,
         hostAvatarUrl: hostAvatarUrl,
         title: title,
         createdAt: createdAt,
         expiresAt: expiresAt,
         participantCount: participantCount,
         isVideoEnabled: isVideoEnabled,
         isVoiceOnly: isVoiceOnly,
         isActive: isActive,
       );

  /// Returns a shallow copy of this [VideoSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  VideoSession copyWith({
    Object? id = _Undefined,
    String? hostId,
    String? hostName,
    Object? hostAvatarUrl = _Undefined,
    String? title,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? participantCount,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isActive,
  }) {
    return VideoSession(
      id: id is int? ? id : this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl is String?
          ? hostAvatarUrl
          : this.hostAvatarUrl,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      participantCount: participantCount ?? this.participantCount,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isVoiceOnly: isVoiceOnly ?? this.isVoiceOnly,
      isActive: isActive ?? this.isActive,
    );
  }
}
