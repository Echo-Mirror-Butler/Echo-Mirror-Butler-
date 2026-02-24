import 'dart:async';
import 'dart:typed_data';
import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart' as auth;
import 'protocol.dart';

class _EndpointGift extends EndpointRef {
  _EndpointGift(EndpointCaller caller) : super(caller);

  @override
  String get name => 'gift';

  Future<double> getEchoBalance() => caller.callServerEndpoint<double>(
        'gift',
        'getEchoBalance',
        {},
      );

  Future<GiftTransaction?> sendGift(
    int recipientUserId,
    double amount,
    String? message,
  ) =>
      caller.callServerEndpoint<GiftTransaction?>(
        'gift',
        'sendGift',
        {
          'recipientUserId': recipientUserId,
          'amount': amount,
          'message': message,
        },
      );

  Future<List<GiftTransaction>> getGiftHistory() =>
      caller.callServerEndpoint<List<GiftTransaction>>(
        'gift',
        'getGiftHistory',
        {},
      );

  Future<double> awardEcho(
    int userId,
    double amount,
    String reason,
  ) =>
      caller.callServerEndpoint<double>(
        'gift',
        'awardEcho',
        {
          'userId': userId,
          'amount': amount,
          'reason': reason,
        },
      );
}

class _EndpointGlobal extends EndpointRef {
  _EndpointGlobal(EndpointCaller caller) : super(caller);

  @override
  String get name => 'global';

  Stream<List<MoodPin>> streamMoodPins() =>
      caller.callStreamingServerEndpoint<List<MoodPin>>(
        'global',
        'streamMoodPins',
        {},
        {},
      );

  Future<int?> addMoodPin(
    String sentiment,
    double latitude,
    double longitude,
  ) =>
      caller.callServerEndpoint<int?>(
        'global',
        'addMoodPin',
        {
          'sentiment': sentiment,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

  Future<String?> uploadVideo(
    ByteData videoData,
    String moodTag,
  ) =>
      caller.callServerEndpoint<String?>(
        'global',
        'uploadVideo',
        {
          'videoData': videoData,
          'moodTag': moodTag,
        },
      );

  Future<String?> uploadImage(
    ByteData imageData,
    String moodTag,
  ) =>
      caller.callServerEndpoint<String?>(
        'global',
        'uploadImage',
        {
          'imageData': imageData,
          'moodTag': moodTag,
        },
      );

  Future<List<VideoPost>> getVideoFeed(
    int offset,
    int limit,
  ) =>
      caller.callServerEndpoint<List<VideoPost>>(
        'global',
        'getVideoFeed',
        {
          'offset': offset,
          'limit': limit,
        },
      );

  Future<int?> addComment(
    int moodPinId,
    String text,
  ) =>
      caller.callServerEndpoint<int?>(
        'global',
        'addComment',
        {
          'moodPinId': moodPinId,
          'text': text,
        },
      );

  Future<List<MoodPinComment>> getCommentsForPin(int moodPinId) =>
      caller.callServerEndpoint<List<MoodPinComment>>(
        'global',
        'getCommentsForPin',
        {
          'moodPinId': moodPinId,
        },
      );

  Future<String> generateClusterEncouragement(
    String sentiment,
    int nearbyCount,
  ) =>
      caller.callServerEndpoint<String>(
        'global',
        'generateClusterEncouragement',
        {
          'sentiment': sentiment,
          'nearbyCount': nearbyCount,
        },
      );
}

class _EndpointPasswordReset extends EndpointRef {
  _EndpointPasswordReset(EndpointCaller caller) : super(caller);

  @override
  String get name => 'passwordReset';

  Future<bool> requestPasswordReset(String email) =>
      caller.callServerEndpoint<bool>(
        'passwordReset',
        'requestPasswordReset',
        {
          'email': email,
        },
      );

  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) =>
      caller.callServerEndpoint<bool>(
        'passwordReset',
        'resetPassword',
        {
          'email': email,
          'token': token,
          'newPassword': newPassword,
        },
      );

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) =>
      caller.callServerEndpoint<bool>(
        'passwordReset',
        'changePassword',
        {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
}

class Client extends ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    AuthenticationKeyManager? authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      MethodCallContext context,
      Object error,
      StackTrace stackTrace,
    )? onFailedCall,
    Function(CloseReason reason)? onSuccessfulStreamClose,
    Function(
      SessionLogEntry entry,
    )? logReceivedCall,
  }) : super(
          host,
          Protocol(),
          securityContext: securityContext,
          authenticationKeyManager: authenticationKeyManager,
          streamingConnectionTimeout: streamingConnectionTimeout,
          connectionTimeout: connectionTimeout,
          onFailedCall: onFailedCall,
          onSuccessfulStreamClose: onSuccessfulStreamClose,
          logReceivedCall: logReceivedCall,
        ) {
    gift = _EndpointGift(this);
    global = _EndpointGlobal(this);
    passwordReset = _EndpointPasswordReset(this);
    emailIdp = auth.EndpointEmailIdp(this);
  }

  late final _EndpointGift gift;
  late final _EndpointGlobal global;
  late final _EndpointPasswordReset passwordReset;
  late final auth.EndpointEmailIdp emailIdp;

  @override
  Map<String, EndpointRef> get endpointRefLookup => {
        'gift': gift,
        'global': global,
        'passwordReset': passwordReset,
        'emailIdp': emailIdp,
      };
}
