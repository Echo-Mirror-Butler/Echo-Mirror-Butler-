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
import 'package:serverpod/serverpod.dart' as _i1;
import '../endpoints/gift_endpoint.dart' as _i2;
import '../endpoints/global_endpoint.dart' as _i3;
import '../endpoints/password_reset_endpoint.dart' as _i4;
import 'dart:typed_data' as _i5;
import 'package:serverpod_auth_server/serverpod_auth_server.dart' as _i6;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'gift': _i2.GiftEndpoint()
        ..initialize(
          server,
          'gift',
          null,
        ),
      'global': _i3.GlobalEndpoint()
        ..initialize(
          server,
          'global',
          null,
        ),
      'passwordReset': _i4.PasswordResetEndpoint()
        ..initialize(
          server,
          'passwordReset',
          null,
        ),
    };
    connectors['gift'] = _i1.EndpointConnector(
      name: 'gift',
      endpoint: endpoints['gift']!,
      methodConnectors: {
        'getEchoBalance': _i1.MethodConnector(
          name: 'getEchoBalance',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['gift'] as _i2.GiftEndpoint).getEchoBalance(
                session,
              ),
        ),
        'sendGift': _i1.MethodConnector(
          name: 'sendGift',
          params: {
            'recipientUserId': _i1.ParameterDescription(
              name: 'recipientUserId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'amount': _i1.ParameterDescription(
              name: 'amount',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'message': _i1.ParameterDescription(
              name: 'message',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['gift'] as _i2.GiftEndpoint).sendGift(
                session,
                params['recipientUserId'],
                params['amount'],
                params['message'],
              ),
        ),
        'getGiftHistory': _i1.MethodConnector(
          name: 'getGiftHistory',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['gift'] as _i2.GiftEndpoint).getGiftHistory(
                session,
              ),
        ),
        'awardEcho': _i1.MethodConnector(
          name: 'awardEcho',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'amount': _i1.ParameterDescription(
              name: 'amount',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'reason': _i1.ParameterDescription(
              name: 'reason',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['gift'] as _i2.GiftEndpoint).awardEcho(
                session,
                params['userId'],
                params['amount'],
                params['reason'],
              ),
        ),
      },
    );
    connectors['global'] = _i1.EndpointConnector(
      name: 'global',
      endpoint: endpoints['global']!,
      methodConnectors: {
        'addMoodPin': _i1.MethodConnector(
          name: 'addMoodPin',
          params: {
            'sentiment': _i1.ParameterDescription(
              name: 'sentiment',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'latitude': _i1.ParameterDescription(
              name: 'latitude',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'longitude': _i1.ParameterDescription(
              name: 'longitude',
              type: _i1.getType<double>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['global'] as _i3.GlobalEndpoint).addMoodPin(
                session,
                params['sentiment'],
                params['latitude'],
                params['longitude'],
              ),
        ),
        'uploadVideo': _i1.MethodConnector(
          name: 'uploadVideo',
          params: {
            'videoData': _i1.ParameterDescription(
              name: 'videoData',
              type: _i1.getType<_i5.ByteData>(),
              nullable: false,
            ),
            'moodTag': _i1.ParameterDescription(
              name: 'moodTag',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['global'] as _i3.GlobalEndpoint).uploadVideo(
                    session,
                    params['videoData'],
                    params['moodTag'],
                  ),
        ),
        'uploadImage': _i1.MethodConnector(
          name: 'uploadImage',
          params: {
            'imageData': _i1.ParameterDescription(
              name: 'imageData',
              type: _i1.getType<_i5.ByteData>(),
              nullable: false,
            ),
            'moodTag': _i1.ParameterDescription(
              name: 'moodTag',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['global'] as _i3.GlobalEndpoint).uploadImage(
                    session,
                    params['imageData'],
                    params['moodTag'],
                  ),
        ),
        'getVideoFeed': _i1.MethodConnector(
          name: 'getVideoFeed',
          params: {
            'offset': _i1.ParameterDescription(
              name: 'offset',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'limit': _i1.ParameterDescription(
              name: 'limit',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['global'] as _i3.GlobalEndpoint).getVideoFeed(
                    session,
                    params['offset'],
                    params['limit'],
                  ),
        ),
        'addComment': _i1.MethodConnector(
          name: 'addComment',
          params: {
            'moodPinId': _i1.ParameterDescription(
              name: 'moodPinId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'text': _i1.ParameterDescription(
              name: 'text',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['global'] as _i3.GlobalEndpoint).addComment(
                session,
                params['moodPinId'],
                params['text'],
              ),
        ),
        'getCommentsForPin': _i1.MethodConnector(
          name: 'getCommentsForPin',
          params: {
            'moodPinId': _i1.ParameterDescription(
              name: 'moodPinId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['global'] as _i3.GlobalEndpoint).getCommentsForPin(
                    session,
                    params['moodPinId'],
                  ),
        ),
        'generateClusterEncouragement': _i1.MethodConnector(
          name: 'generateClusterEncouragement',
          params: {
            'sentiment': _i1.ParameterDescription(
              name: 'sentiment',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'nearbyCount': _i1.ParameterDescription(
              name: 'nearbyCount',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['global'] as _i3.GlobalEndpoint)
                  .generateClusterEncouragement(
                    session,
                    params['sentiment'],
                    params['nearbyCount'],
                  ),
        ),
        'streamMoodPins': _i1.MethodStreamConnector(
          name: 'streamMoodPins',
          params: {},
          streamParams: {},
          returnType: _i1.MethodStreamReturnType.streamType,
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['global'] as _i3.GlobalEndpoint).streamMoodPins(
                session,
              ),
        ),
      },
    );
    connectors['passwordReset'] = _i1.EndpointConnector(
      name: 'passwordReset',
      endpoint: endpoints['passwordReset']!,
      methodConnectors: {
        'requestPasswordReset': _i1.MethodConnector(
          name: 'requestPasswordReset',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['passwordReset'] as _i4.PasswordResetEndpoint)
                      .requestPasswordReset(
                        session,
                        params['email'],
                      ),
        ),
        'resetPassword': _i1.MethodConnector(
          name: 'resetPassword',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'token': _i1.ParameterDescription(
              name: 'token',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'newPassword': _i1.ParameterDescription(
              name: 'newPassword',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['passwordReset'] as _i4.PasswordResetEndpoint)
                      .resetPassword(
                        session,
                        params['email'],
                        params['token'],
                        params['newPassword'],
                      ),
        ),
        'changePassword': _i1.MethodConnector(
          name: 'changePassword',
          params: {
            'currentPassword': _i1.ParameterDescription(
              name: 'currentPassword',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'newPassword': _i1.ParameterDescription(
              name: 'newPassword',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['passwordReset'] as _i4.PasswordResetEndpoint)
                      .changePassword(
                        session,
                        params['currentPassword'],
                        params['newPassword'],
                      ),
        ),
      },
    );
    modules['serverpod_auth'] = _i6.Endpoints()..initializeEndpoints(server);
  }
}
