library protocol;

import 'package:serverpod_client/serverpod_client.dart';

part 'echo_wallet.dart';
part 'gift_transaction.dart';
part 'mood_pin.dart';
part 'video_post.dart';
part 'mood_pin_comment.dart';

class Protocol extends SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    if (t == EchoWallet) {
      return EchoWallet.fromJson(data) as T;
    }
    if (t == GiftTransaction) {
      return GiftTransaction.fromJson(data) as T;
    }
    if (t == MoodPin) {
      return MoodPin.fromJson(data) as T;
    }
    if (t == VideoPost) {
      return VideoPost.fromJson(data) as T;
    }
    if (t == MoodPinComment) {
      return MoodPinComment.fromJson(data) as T;
    }
    if (t == _i1.getType<EchoWallet?>()) {
      return (data != null ? EchoWallet.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<GiftTransaction?>()) {
      return (data != null ? GiftTransaction.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<MoodPin?>()) {
      return (data != null ? MoodPin.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<VideoPost?>()) {
      return (data != null ? VideoPost.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<MoodPinComment?>()) {
      return (data != null ? MoodPinComment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<List<MoodPin>>()) {
      return (data as List).map((e) => deserialize<MoodPin>(e)).toList() as T;
    }
    if (t == _i1.getType<List<VideoPost>>()) {
      return (data as List).map((e) => deserialize<VideoPost>(e)).toList() as T;
    }
    if (t == _i1.getType<List<GiftTransaction>>()) {
      return (data as List).map((e) => deserialize<GiftTransaction>(e)).toList()
          as T;
    }
    if (t == _i1.getType<List<MoodPinComment>>()) {
      return (data as List).map((e) => deserialize<MoodPinComment>(e)).toList()
          as T;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;
    if (data is EchoWallet) {
      return 'EchoWallet';
    }
    if (data is GiftTransaction) {
      return 'GiftTransaction';
    }
    if (data is MoodPin) {
      return 'MoodPin';
    }
    if (data is VideoPost) {
      return 'VideoPost';
    }
    if (data is MoodPinComment) {
      return 'MoodPinComment';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var className = data['className'];
    if (className == 'EchoWallet') {
      return deserialize<EchoWallet>(data['data']);
    }
    if (className == 'GiftTransaction') {
      return deserialize<GiftTransaction>(data['data']);
    }
    if (className == 'MoodPin') {
      return deserialize<MoodPin>(data['data']);
    }
    if (className == 'VideoPost') {
      return deserialize<VideoPost>(data['data']);
    }
    if (className == 'MoodPinComment') {
      return deserialize<MoodPinComment>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}

class _i1 {
  static Type getType<T>() => T;
}
