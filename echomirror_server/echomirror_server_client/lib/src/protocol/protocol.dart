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
import 'ai_insight.dart' as _i2;
import 'greeting.dart' as _i3;
import 'log_entry.dart' as _i4;
import 'mood_comment_notification.dart' as _i5;
import 'mood_pin.dart' as _i6;
import 'mood_pin_comment.dart' as _i7;
import 'scheduled_session.dart' as _i8;
import 'story.dart' as _i9;
import 'user_mood_pin.dart' as _i10;
import 'video_post.dart' as _i11;
import 'video_session.dart' as _i12;
import 'package:echomirror_server_client/src/protocol/log_entry.dart' as _i13;
import 'package:echomirror_server_client/src/protocol/mood_pin.dart' as _i14;
import 'package:echomirror_server_client/src/protocol/video_post.dart' as _i15;
import 'package:echomirror_server_client/src/protocol/mood_pin_comment.dart'
    as _i16;
import 'package:echomirror_server_client/src/protocol/mood_comment_notification.dart'
    as _i17;
import 'package:echomirror_server_client/src/protocol/video_session.dart'
    as _i18;
import 'package:echomirror_server_client/src/protocol/scheduled_session.dart'
    as _i19;
import 'package:echomirror_server_client/src/protocol/story.dart' as _i20;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i21;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i22;
export 'ai_insight.dart';
export 'greeting.dart';
export 'log_entry.dart';
export 'mood_comment_notification.dart';
export 'mood_pin.dart';
export 'mood_pin_comment.dart';
export 'scheduled_session.dart';
export 'story.dart';
export 'user_mood_pin.dart';
export 'video_post.dart';
export 'video_session.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i2.AiInsight) {
      return _i2.AiInsight.fromJson(data) as T;
    }
    if (t == _i3.Greeting) {
      return _i3.Greeting.fromJson(data) as T;
    }
    if (t == _i4.LogEntry) {
      return _i4.LogEntry.fromJson(data) as T;
    }
    if (t == _i5.MoodCommentNotification) {
      return _i5.MoodCommentNotification.fromJson(data) as T;
    }
    if (t == _i6.MoodPin) {
      return _i6.MoodPin.fromJson(data) as T;
    }
    if (t == _i7.MoodPinComment) {
      return _i7.MoodPinComment.fromJson(data) as T;
    }
    if (t == _i8.ScheduledSession) {
      return _i8.ScheduledSession.fromJson(data) as T;
    }
    if (t == _i9.Story) {
      return _i9.Story.fromJson(data) as T;
    }
    if (t == _i10.UserMoodPin) {
      return _i10.UserMoodPin.fromJson(data) as T;
    }
    if (t == _i11.VideoPost) {
      return _i11.VideoPost.fromJson(data) as T;
    }
    if (t == _i12.VideoSession) {
      return _i12.VideoSession.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.AiInsight?>()) {
      return (data != null ? _i2.AiInsight.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.Greeting?>()) {
      return (data != null ? _i3.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.LogEntry?>()) {
      return (data != null ? _i4.LogEntry.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.MoodCommentNotification?>()) {
      return (data != null ? _i5.MoodCommentNotification.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i6.MoodPin?>()) {
      return (data != null ? _i6.MoodPin.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.MoodPinComment?>()) {
      return (data != null ? _i7.MoodPinComment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.ScheduledSession?>()) {
      return (data != null ? _i8.ScheduledSession.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.Story?>()) {
      return (data != null ? _i9.Story.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.UserMoodPin?>()) {
      return (data != null ? _i10.UserMoodPin.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.VideoPost?>()) {
      return (data != null ? _i11.VideoPost.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.VideoSession?>()) {
      return (data != null ? _i12.VideoSession.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _i1.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == List<_i13.LogEntry>) {
      return (data as List).map((e) => deserialize<_i13.LogEntry>(e)).toList()
          as T;
    }
    if (t == List<_i14.MoodPin>) {
      return (data as List).map((e) => deserialize<_i14.MoodPin>(e)).toList()
          as T;
    }
    if (t == List<_i15.VideoPost>) {
      return (data as List).map((e) => deserialize<_i15.VideoPost>(e)).toList()
          as T;
    }
    if (t == Map<String, int>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<int>(v)),
          )
          as T;
    }
    if (t == List<_i16.MoodPinComment>) {
      return (data as List)
              .map((e) => deserialize<_i16.MoodPinComment>(e))
              .toList()
          as T;
    }
    if (t == List<_i17.MoodCommentNotification>) {
      return (data as List)
              .map((e) => deserialize<_i17.MoodCommentNotification>(e))
              .toList()
          as T;
    }
    if (t == List<_i18.VideoSession>) {
      return (data as List)
              .map((e) => deserialize<_i18.VideoSession>(e))
              .toList()
          as T;
    }
    if (t == Map<String, String>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<String>(v)),
          )
          as T;
    }
    if (t == List<_i19.ScheduledSession>) {
      return (data as List)
              .map((e) => deserialize<_i19.ScheduledSession>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i20.Story>) {
      return (data as List).map((e) => deserialize<_i20.Story>(e)).toList()
          as T;
    }
    try {
      return _i21.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i22.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.AiInsight => 'AiInsight',
      _i3.Greeting => 'Greeting',
      _i4.LogEntry => 'LogEntry',
      _i5.MoodCommentNotification => 'MoodCommentNotification',
      _i6.MoodPin => 'MoodPin',
      _i7.MoodPinComment => 'MoodPinComment',
      _i8.ScheduledSession => 'ScheduledSession',
      _i9.Story => 'Story',
      _i10.UserMoodPin => 'UserMoodPin',
      _i11.VideoPost => 'VideoPost',
      _i12.VideoSession => 'VideoSession',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'echomirror_server.',
        '',
      );
    }

    switch (data) {
      case _i2.AiInsight():
        return 'AiInsight';
      case _i3.Greeting():
        return 'Greeting';
      case _i4.LogEntry():
        return 'LogEntry';
      case _i5.MoodCommentNotification():
        return 'MoodCommentNotification';
      case _i6.MoodPin():
        return 'MoodPin';
      case _i7.MoodPinComment():
        return 'MoodPinComment';
      case _i8.ScheduledSession():
        return 'ScheduledSession';
      case _i9.Story():
        return 'Story';
      case _i10.UserMoodPin():
        return 'UserMoodPin';
      case _i11.VideoPost():
        return 'VideoPost';
      case _i12.VideoSession():
        return 'VideoSession';
    }
    className = _i21.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i22.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_core.$className';
    }
    if (data is List<_i14.MoodPin>) {
      return 'List<MoodPin>';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AiInsight') {
      return deserialize<_i2.AiInsight>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i3.Greeting>(data['data']);
    }
    if (dataClassName == 'LogEntry') {
      return deserialize<_i4.LogEntry>(data['data']);
    }
    if (dataClassName == 'MoodCommentNotification') {
      return deserialize<_i5.MoodCommentNotification>(data['data']);
    }
    if (dataClassName == 'MoodPin') {
      return deserialize<_i6.MoodPin>(data['data']);
    }
    if (dataClassName == 'MoodPinComment') {
      return deserialize<_i7.MoodPinComment>(data['data']);
    }
    if (dataClassName == 'ScheduledSession') {
      return deserialize<_i8.ScheduledSession>(data['data']);
    }
    if (dataClassName == 'Story') {
      return deserialize<_i9.Story>(data['data']);
    }
    if (dataClassName == 'UserMoodPin') {
      return deserialize<_i10.UserMoodPin>(data['data']);
    }
    if (dataClassName == 'VideoPost') {
      return deserialize<_i11.VideoPost>(data['data']);
    }
    if (dataClassName == 'VideoSession') {
      return deserialize<_i12.VideoSession>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i21.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i22.Protocol().deserializeByClassName(data);
    }
    if (dataClassName == 'List<MoodPin>') {
      return deserialize<List<_i14.MoodPin>>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
