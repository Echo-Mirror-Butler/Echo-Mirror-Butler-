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
import 'dart:async' as _i2;
import 'package:echomirror_server_client/src/protocol/gift_transaction.dart'
    as _i3;
import 'package:echomirror_server_client/src/protocol/mood_pin.dart' as _i4;
import 'dart:typed_data' as _i5;
import 'package:echomirror_server_client/src/protocol/video_post.dart' as _i6;
import 'package:echomirror_server_client/src/protocol/mood_pin_comment.dart'
    as _i7;
import 'package:serverpod_auth_client/serverpod_auth_client.dart' as _i8;
import 'protocol.dart' as _i9;

/// {@category Endpoint}
class EndpointGift extends _i1.EndpointRef {
  EndpointGift(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'gift';

  _i2.Future<double> getEchoBalance() => caller.callServerEndpoint<double>(
    'gift',
    'getEchoBalance',
    {},
  );

  _i2.Future<_i3.GiftTransaction?> sendGift(
    int recipientUserId,
    double amount,
    String? message,
  ) => caller.callServerEndpoint<_i3.GiftTransaction?>(
    'gift',
    'sendGift',
    {
      'recipientUserId': recipientUserId,
      'amount': amount,
      'message': message,
    },
  );

  _i2.Future<List<_i3.GiftTransaction>> getGiftHistory() =>
      caller.callServerEndpoint<List<_i3.GiftTransaction>>(
        'gift',
        'getGiftHistory',
        {},
      );

  _i2.Future<double> awardEcho(
    int userId,
    double amount,
    String reason,
  ) => caller.callServerEndpoint<double>(
    'gift',
    'awardEcho',
    {
      'userId': userId,
      'amount': amount,
      'reason': reason,
    },
  );
}

/// {@category Endpoint}
class EndpointGlobal extends _i1.EndpointRef {
  EndpointGlobal(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'global';

  /// Stream mood pins in real-time
  _i2.Stream<List<_i4.MoodPin>> streamMoodPins() =>
      caller.callStreamingServerEndpoint<
        _i2.Stream<List<_i4.MoodPin>>,
        List<_i4.MoodPin>
      >(
        'global',
        'streamMoodPins',
        {},
        {},
      );

  /// Add a mood pin with anonymized location
  _i2.Future<int?> addMoodPin(
    String sentiment,
    double latitude,
    double longitude,
  ) => caller.callServerEndpoint<int?>(
    'global',
    'addMoodPin',
    {
      'sentiment': sentiment,
      'latitude': latitude,
      'longitude': longitude,
    },
  );

  /// Upload video and create post
  _i2.Future<String?> uploadVideo(
    _i5.ByteData videoData,
    String moodTag,
  ) => caller.callServerEndpoint<String?>(
    'global',
    'uploadVideo',
    {
      'videoData': videoData,
      'moodTag': moodTag,
    },
  );

  /// Upload image and create post
  _i2.Future<String?> uploadImage(
    _i5.ByteData imageData,
    String moodTag,
  ) => caller.callServerEndpoint<String?>(
    'global',
    'uploadImage',
    {
      'imageData': imageData,
      'moodTag': moodTag,
    },
  );

  /// Get video feed (paginated)
  _i2.Future<List<_i6.VideoPost>> getVideoFeed(
    int offset,
    int limit,
  ) => caller.callServerEndpoint<List<_i6.VideoPost>>(
    'global',
    'getVideoFeed',
    {
      'offset': offset,
      'limit': limit,
    },
  );

  /// Add a comment to a mood pin
  _i2.Future<int?> addComment(
    int moodPinId,
    String text,
  ) => caller.callServerEndpoint<int?>(
    'global',
    'addComment',
    {
      'moodPinId': moodPinId,
      'text': text,
    },
  );

  /// Get comments for a mood pin
  _i2.Future<List<_i7.MoodPinComment>> getCommentsForPin(int moodPinId) =>
      caller.callServerEndpoint<List<_i7.MoodPinComment>>(
        'global',
        'getCommentsForPin',
        {'moodPinId': moodPinId},
      );

  /// Generate cluster encouragement message
  _i2.Future<String> generateClusterEncouragement(
    String sentiment,
    int nearbyCount,
  ) => caller.callServerEndpoint<String>(
    'global',
    'generateClusterEncouragement',
    {
      'sentiment': sentiment,
      'nearbyCount': nearbyCount,
    },
  );
}

/// {@category Endpoint}
class EndpointPasswordReset extends _i1.EndpointRef {
  EndpointPasswordReset(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'passwordReset';

  _i2.Future<bool> requestPasswordReset(String email) =>
      caller.callServerEndpoint<bool>(
        'passwordReset',
        'requestPasswordReset',
        {'email': email},
      );

  _i2.Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) => caller.callServerEndpoint<bool>(
    'passwordReset',
    'resetPassword',
    {
      'email': email,
      'token': token,
      'newPassword': newPassword,
    },
  );

  _i2.Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) => caller.callServerEndpoint<bool>(
    'passwordReset',
    'changePassword',
    {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    },
  );
}

class Modules {
  Modules(Client client) {
    auth = _i8.Caller(client);
  }

  late final _i8.Caller auth;
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i9.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    gift = EndpointGift(this);
    global = EndpointGlobal(this);
    passwordReset = EndpointPasswordReset(this);
    modules = Modules(this);
  }

  late final EndpointGift gift;

  late final EndpointGlobal global;

  late final EndpointPasswordReset passwordReset;

  late final Modules modules;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'gift': gift,
    'global': global,
    'passwordReset': passwordReset,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {
    'auth': modules.auth,
  };
}
