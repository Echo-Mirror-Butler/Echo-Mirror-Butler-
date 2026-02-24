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
import 'echo_wallet.dart' as _i2;
import 'gift_transaction.dart' as _i3;
import 'mood_pin.dart' as _i4;
import 'mood_pin_comment.dart' as _i5;
import 'video_post.dart' as _i6;
import 'package:echomirror_server_client/src/protocol/gift_transaction.dart'
    as _i7;
import 'package:echomirror_server_client/src/protocol/mood_pin.dart' as _i8;
import 'package:echomirror_server_client/src/protocol/video_post.dart' as _i9;
import 'package:echomirror_server_client/src/protocol/mood_pin_comment.dart'
    as _i10;
import 'package:serverpod_auth_client/serverpod_auth_client.dart' as _i11;
export 'echo_wallet.dart';
export 'gift_transaction.dart';
export 'mood_pin.dart';
export 'mood_pin_comment.dart';
export 'video_post.dart';
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

    if (t == _i2.EchoWallet) {
      return _i2.EchoWallet.fromJson(data) as T;
    }
    if (t == _i3.GiftTransaction) {
      return _i3.GiftTransaction.fromJson(data) as T;
    }
    if (t == _i4.MoodPin) {
      return _i4.MoodPin.fromJson(data) as T;
    }
    if (t == _i5.MoodPinComment) {
      return _i5.MoodPinComment.fromJson(data) as T;
    }
    if (t == _i6.VideoPost) {
      return _i6.VideoPost.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.EchoWallet?>()) {
      return (data != null ? _i2.EchoWallet.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.GiftTransaction?>()) {
      return (data != null ? _i3.GiftTransaction.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.MoodPin?>()) {
      return (data != null ? _i4.MoodPin.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.MoodPinComment?>()) {
      return (data != null ? _i5.MoodPinComment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.VideoPost?>()) {
      return (data != null ? _i6.VideoPost.fromJson(data) : null) as T;
    }
    if (t == List<_i7.GiftTransaction>) {
      return (data as List)
              .map((e) => deserialize<_i7.GiftTransaction>(e))
              .toList()
          as T;
    }
    if (t == List<_i8.MoodPin>) {
      return (data as List).map((e) => deserialize<_i8.MoodPin>(e)).toList()
          as T;
    }
    if (t == List<_i9.VideoPost>) {
      return (data as List).map((e) => deserialize<_i9.VideoPost>(e)).toList()
          as T;
    }
    if (t == List<_i10.MoodPinComment>) {
      return (data as List)
              .map((e) => deserialize<_i10.MoodPinComment>(e))
              .toList()
          as T;
    }
    try {
      return _i11.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.EchoWallet => 'EchoWallet',
      _i3.GiftTransaction => 'GiftTransaction',
      _i4.MoodPin => 'MoodPin',
      _i5.MoodPinComment => 'MoodPinComment',
      _i6.VideoPost => 'VideoPost',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('echomirror.', '');
    }

    switch (data) {
      case _i2.EchoWallet():
        return 'EchoWallet';
      case _i3.GiftTransaction():
        return 'GiftTransaction';
      case _i4.MoodPin():
        return 'MoodPin';
      case _i5.MoodPinComment():
        return 'MoodPinComment';
      case _i6.VideoPost():
        return 'VideoPost';
    }
    className = _i11.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth.$className';
    }
    if (data is List<_i8.MoodPin>) {
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
    if (dataClassName == 'EchoWallet') {
      return deserialize<_i2.EchoWallet>(data['data']);
    }
    if (dataClassName == 'GiftTransaction') {
      return deserialize<_i3.GiftTransaction>(data['data']);
    }
    if (dataClassName == 'MoodPin') {
      return deserialize<_i4.MoodPin>(data['data']);
    }
    if (dataClassName == 'MoodPinComment') {
      return deserialize<_i5.MoodPinComment>(data['data']);
    }
    if (dataClassName == 'VideoPost') {
      return deserialize<_i6.VideoPost>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth.')) {
      data['className'] = dataClassName.substring(15);
      return _i11.Protocol().deserializeByClassName(data);
    }
    if (dataClassName == 'List<MoodPin>') {
      return deserialize<List<_i8.MoodPin>>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i11.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
