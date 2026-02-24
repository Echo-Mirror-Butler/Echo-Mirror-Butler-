import 'package:serverpod/serverpod.dart';
import '../endpoints/gift_endpoint.dart';
import '../endpoints/global_endpoint.dart';
import '../endpoints/password_reset_endpoint.dart';

class Endpoints extends EndpointDispatch {
  @override
  void initializeEndpoints(Server server) {
    var endpoints = <String, Endpoint>{
      'gift': GiftEndpoint()..initialize(server, 'gift', null),
      'global': GlobalEndpoint()..initialize(server, 'global', null),
      'passwordReset': PasswordResetEndpoint()
        ..initialize(server, 'passwordReset', null),
    };

    connectors['gift'] = EndpointConnector(
      name: 'gift',
      endpoint: endpoints['gift']!,
      methodConnectors: {
        'getEchoBalance': MethodConnector(
          name: 'getEchoBalance',
          params: {},
          call: (session, params) async {
            return (endpoints['gift'] as GiftEndpoint).getEchoBalance(session);
          },
        ),
        'sendGift': MethodConnector(
          name: 'sendGift',
          params: {
            'recipientUserId': ParameterDescription(
              name: 'recipientUserId',
              type: int,
              nullable: false,
            ),
            'amount': ParameterDescription(
              name: 'amount',
              type: double,
              nullable: false,
            ),
            'message': ParameterDescription(
              name: 'message',
              type: String,
              nullable: true,
            ),
          },
          call: (session, params) async {
            return (endpoints['gift'] as GiftEndpoint).sendGift(
              session,
              params['recipientUserId'],
              params['amount'],
              params['message'],
            );
          },
        ),
        'getGiftHistory': MethodConnector(
          name: 'getGiftHistory',
          params: {},
          call: (session, params) async {
            return (endpoints['gift'] as GiftEndpoint).getGiftHistory(session);
          },
        ),
        'awardEcho': MethodConnector(
          name: 'awardEcho',
          params: {
            'userId': ParameterDescription(
              name: 'userId',
              type: int,
              nullable: false,
            ),
            'amount': ParameterDescription(
              name: 'amount',
              type: double,
              nullable: false,
            ),
            'reason': ParameterDescription(
              name: 'reason',
              type: String,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['gift'] as GiftEndpoint).awardEcho(
              session,
              params['userId'],
              params['amount'],
              params['reason'],
            );
          },
        ),
      },
    );

    connectors['global'] = EndpointConnector(
      name: 'global',
      endpoint: endpoints['global']!,
      methodConnectors: {
        'streamMoodPins': MethodStreamConnector(
          name: 'streamMoodPins',
          params: {},
          streamParams: {},
          call: (session, params, streamParams) async* {
            yield* (endpoints['global'] as GlobalEndpoint).streamMoodPins(
              session,
            );
          },
        ),
        'addMoodPin': MethodConnector(
          name: 'addMoodPin',
          params: {
            'sentiment': ParameterDescription(
              name: 'sentiment',
              type: String,
              nullable: false,
            ),
            'latitude': ParameterDescription(
              name: 'latitude',
              type: double,
              nullable: false,
            ),
            'longitude': ParameterDescription(
              name: 'longitude',
              type: double,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['global'] as GlobalEndpoint).addMoodPin(
              session,
              params['sentiment'],
              params['latitude'],
              params['longitude'],
            );
          },
        ),
        'uploadVideo': MethodConnector(
          name: 'uploadVideo',
          params: {
            'videoData': ParameterDescription(
              name: 'videoData',
              type: dynamic,
              nullable: false,
            ),
            'moodTag': ParameterDescription(
              name: 'moodTag',
              type: String,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['global'] as GlobalEndpoint).uploadVideo(
              session,
              params['videoData'],
              params['moodTag'],
            );
          },
        ),
        'uploadImage': MethodConnector(
          name: 'uploadImage',
          params: {
            'imageData': ParameterDescription(
              name: 'imageData',
              type: dynamic,
              nullable: false,
            ),
            'moodTag': ParameterDescription(
              name: 'moodTag',
              type: String,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['global'] as GlobalEndpoint).uploadImage(
              session,
              params['imageData'],
              params['moodTag'],
            );
          },
        ),
        'getVideoFeed': MethodConnector(
          name: 'getVideoFeed',
          params: {
            'offset': ParameterDescription(
              name: 'offset',
              type: int,
              nullable: false,
            ),
            'limit': ParameterDescription(
              name: 'limit',
              type: int,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['global'] as GlobalEndpoint).getVideoFeed(
              session,
              params['offset'],
              params['limit'],
            );
          },
        ),
        'addComment': MethodConnector(
          name: 'addComment',
          params: {
            'moodPinId': ParameterDescription(
              name: 'moodPinId',
              type: int,
              nullable: false,
            ),
            'text': ParameterDescription(
              name: 'text',
              type: String,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['global'] as GlobalEndpoint).addComment(
              session,
              params['moodPinId'],
              params['text'],
            );
          },
        ),
        'getCommentsForPin': MethodConnector(
          name: 'getCommentsForPin',
          params: {
            'moodPinId': ParameterDescription(
              name: 'moodPinId',
              type: int,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['global'] as GlobalEndpoint).getCommentsForPin(
              session,
              params['moodPinId'],
            );
          },
        ),
        'generateClusterEncouragement': MethodConnector(
          name: 'generateClusterEncouragement',
          params: {
            'sentiment': ParameterDescription(
              name: 'sentiment',
              type: String,
              nullable: false,
            ),
            'nearbyCount': ParameterDescription(
              name: 'nearbyCount',
              type: int,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['global'] as GlobalEndpoint)
                .generateClusterEncouragement(
                  session,
                  params['sentiment'],
                  params['nearbyCount'],
                );
          },
        ),
      },
    );

    connectors['passwordReset'] = EndpointConnector(
      name: 'passwordReset',
      endpoint: endpoints['passwordReset']!,
      methodConnectors: {
        'requestPasswordReset': MethodConnector(
          name: 'requestPasswordReset',
          params: {
            'email': ParameterDescription(
              name: 'email',
              type: String,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['passwordReset'] as PasswordResetEndpoint)
                .requestPasswordReset(session, params['email']);
          },
        ),
        'resetPassword': MethodConnector(
          name: 'resetPassword',
          params: {
            'email': ParameterDescription(
              name: 'email',
              type: String,
              nullable: false,
            ),
            'token': ParameterDescription(
              name: 'token',
              type: String,
              nullable: false,
            ),
            'newPassword': ParameterDescription(
              name: 'newPassword',
              type: String,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['passwordReset'] as PasswordResetEndpoint)
                .resetPassword(
                  session,
                  params['email'],
                  params['token'],
                  params['newPassword'],
                );
          },
        ),
        'changePassword': MethodConnector(
          name: 'changePassword',
          params: {
            'currentPassword': ParameterDescription(
              name: 'currentPassword',
              type: String,
              nullable: false,
            ),
            'newPassword': ParameterDescription(
              name: 'newPassword',
              type: String,
              nullable: false,
            ),
          },
          call: (session, params) async {
            return (endpoints['passwordReset'] as PasswordResetEndpoint)
                .changePassword(
                  session,
                  params['currentPassword'],
                  params['newPassword'],
                );
          },
        ),
      },
    );
  }
}
