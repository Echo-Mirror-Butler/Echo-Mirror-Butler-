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

abstract class ScheduledSession implements _i1.SerializableModel {
  ScheduledSession._({
    this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    required this.title,
    this.description,
    required this.scheduledTime,
    required this.createdAt,
    required this.isVideoEnabled,
    required this.isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    this.actualSessionId,
  }) : isNotified = isNotified ?? false,
       isCancelled = isCancelled ?? false;

  factory ScheduledSession({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    String? description,
    required DateTime scheduledTime,
    required DateTime createdAt,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    String? actualSessionId,
  }) = _ScheduledSessionImpl;

  factory ScheduledSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScheduledSession(
      id: jsonSerialization['id'] as int?,
      hostId: jsonSerialization['hostId'] as String,
      hostName: jsonSerialization['hostName'] as String,
      hostAvatarUrl: jsonSerialization['hostAvatarUrl'] as String?,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String?,
      scheduledTime: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['scheduledTime'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      isVideoEnabled: jsonSerialization['isVideoEnabled'] as bool,
      isVoiceOnly: jsonSerialization['isVoiceOnly'] as bool,
      isNotified: jsonSerialization['isNotified'] as bool,
      isCancelled: jsonSerialization['isCancelled'] as bool,
      actualSessionId: jsonSerialization['actualSessionId'] as String?,
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

  String? description;

  DateTime scheduledTime;

  DateTime createdAt;

  bool isVideoEnabled;

  bool isVoiceOnly;

  bool isNotified;

  bool isCancelled;

  String? actualSessionId;

  /// Returns a shallow copy of this [ScheduledSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ScheduledSession copyWith({
    int? id,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? title,
    String? description,
    DateTime? scheduledTime,
    DateTime? createdAt,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    String? actualSessionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScheduledSession',
      if (id != null) 'id': id,
      'hostId': hostId,
      'hostName': hostName,
      if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      if (description != null) 'description': description,
      'scheduledTime': scheduledTime.toJson(),
      'createdAt': createdAt.toJson(),
      'isVideoEnabled': isVideoEnabled,
      'isVoiceOnly': isVoiceOnly,
      'isNotified': isNotified,
      'isCancelled': isCancelled,
      if (actualSessionId != null) 'actualSessionId': actualSessionId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScheduledSessionImpl extends ScheduledSession {
  _ScheduledSessionImpl({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    String? description,
    required DateTime scheduledTime,
    required DateTime createdAt,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    String? actualSessionId,
  }) : super._(
         id: id,
         hostId: hostId,
         hostName: hostName,
         hostAvatarUrl: hostAvatarUrl,
         title: title,
         description: description,
         scheduledTime: scheduledTime,
         createdAt: createdAt,
         isVideoEnabled: isVideoEnabled,
         isVoiceOnly: isVoiceOnly,
         isNotified: isNotified,
         isCancelled: isCancelled,
         actualSessionId: actualSessionId,
       );

  /// Returns a shallow copy of this [ScheduledSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ScheduledSession copyWith({
    Object? id = _Undefined,
    String? hostId,
    String? hostName,
    Object? hostAvatarUrl = _Undefined,
    String? title,
    Object? description = _Undefined,
    DateTime? scheduledTime,
    DateTime? createdAt,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    Object? actualSessionId = _Undefined,
  }) {
    return ScheduledSession(
      id: id is int? ? id : this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl is String?
          ? hostAvatarUrl
          : this.hostAvatarUrl,
      title: title ?? this.title,
      description: description is String? ? description : this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      createdAt: createdAt ?? this.createdAt,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isVoiceOnly: isVoiceOnly ?? this.isVoiceOnly,
      isNotified: isNotified ?? this.isNotified,
      isCancelled: isCancelled ?? this.isCancelled,
      actualSessionId: actualSessionId is String?
          ? actualSessionId
          : this.actualSessionId,
    );
  }
}
