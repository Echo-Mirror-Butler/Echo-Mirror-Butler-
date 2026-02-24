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
import '../endpoints/ai_endpoint.dart' as _i2;
import '../endpoints/email_idp_endpoint.dart' as _i3;
import '../endpoints/global_endpoint.dart' as _i4;
import '../endpoints/jwt_refresh_endpoint.dart' as _i5;
import '../endpoints/socials_endpoint.dart' as _i6;
import '../greeting_endpoint.dart' as _i7;
import '../logging_endpoint.dart' as _i8;
import 'package:echomirror_server_server/src/generated/log_entry.dart' as _i9;
import 'dart:typed_data' as _i10;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i11;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i12;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'ai': _i2.AiEndpoint()..initialize(server, 'ai', null),
      'emailIdp': _i3.EmailIdpEndpoint()..initialize(server, 'emailIdp', null),
      'global': _i4.GlobalEndpoint()..initialize(server, 'global', null),
      'jwtRefresh': _i5.JwtRefreshEndpoint()
        ..initialize(server, 'jwtRefresh', null),
      'socials': _i6.SocialsEndpoint()..initialize(server, 'socials', null),
      'greeting': _i7.GreetingEndpoint()..initialize(server, 'greeting', null),
      'logging': _i8.LoggingEndpoint()..initialize(server, 'logging', null),
    };
    connectors['ai'] = _i1.EndpointConnector(
      name: 'ai',
      endpoint: endpoints['ai']!,
      methodConnectors: {
        'generateInsight': _i1.MethodConnector(
          name: 'generateInsight',
          params: {
            'recentLogs': _i1.ParameterDescription(
              name: 'recentLogs',
              type: _i1.getType<List<_i9.LogEntry>>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['ai'] as _i2.AiEndpoint).generateInsight(
                session,
                params['recentLogs'],
              ),
        ),
        'generateChatResponse': _i1.MethodConnector(
          name: 'generateChatResponse',
          params: {
            'userMessage': _i1.ParameterDescription(
              name: 'userMessage',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'context': _i1.ParameterDescription(
              name: 'context',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['ai'] as _i2.AiEndpoint).generateChatResponse(
                session,
                params['userMessage'],
                params['context'],
              ),
        ),
      },
    );
    connectors['emailIdp'] = _i1.EndpointConnector(
      name: 'emailIdp',
      endpoint: endpoints['emailIdp']!,
      methodConnectors: {
        'login': _i1.MethodConnector(
          name: 'login',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _i3.EmailIdpEndpoint).login(
                session,
                email: params['email'],
                password: params['password'],
              ),
        ),
        'startRegistration': _i1.MethodConnector(
          name: 'startRegistration',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _i3.EmailIdpEndpoint).startRegistration(
                session,
                email: params['email'],
              ),
        ),
        'verifyRegistrationCode': _i1.MethodConnector(
          name: 'verifyRegistrationCode',
          params: {
            'accountRequestId': _i1.ParameterDescription(
              name: 'accountRequestId',
              type: _i1.getType<_i1.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _i1.ParameterDescription(
              name: 'verificationCode',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .verifyRegistrationCode(
                    session,
                    accountRequestId: params['accountRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishRegistration': _i1.MethodConnector(
          name: 'finishRegistration',
          params: {
            'registrationToken': _i1.ParameterDescription(
              name: 'registrationToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .finishRegistration(
                    session,
                    registrationToken: params['registrationToken'],
                    password: params['password'],
                  ),
        ),
        'startPasswordReset': _i1.MethodConnector(
          name: 'startPasswordReset',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .startPasswordReset(session, email: params['email']),
        ),
        'verifyPasswordResetCode': _i1.MethodConnector(
          name: 'verifyPasswordResetCode',
          params: {
            'passwordResetRequestId': _i1.ParameterDescription(
              name: 'passwordResetRequestId',
              type: _i1.getType<_i1.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _i1.ParameterDescription(
              name: 'verificationCode',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .verifyPasswordResetCode(
                    session,
                    passwordResetRequestId: params['passwordResetRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishPasswordReset': _i1.MethodConnector(
          name: 'finishPasswordReset',
          params: {
            'finishPasswordResetToken': _i1.ParameterDescription(
              name: 'finishPasswordResetToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'newPassword': _i1.ParameterDescription(
              name: 'newPassword',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .finishPasswordReset(
                    session,
                    finishPasswordResetToken:
                        params['finishPasswordResetToken'],
                    newPassword: params['newPassword'],
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
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).addMoodPin(
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
              type: _i1.getType<_i10.ByteData>(),
              nullable: false,
            ),
            'moodTag': _i1.ParameterDescription(
              name: 'moodTag',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).uploadVideo(
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
              type: _i1.getType<_i10.ByteData>(),
              nullable: false,
            ),
            'moodTag': _i1.ParameterDescription(
              name: 'moodTag',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).uploadImage(
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
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).getVideoFeed(
                session,
                params['offset'],
                params['limit'],
              ),
        ),
        'getMoodStatistics': _i1.MethodConnector(
          name: 'getMoodStatistics',
          params: {},
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).getMoodStatistics(
                session,
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
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).addComment(
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
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).getCommentsForPin(
                session,
                params['moodPinId'],
              ),
        ),
        'getNotifications': _i1.MethodConnector(
          name: 'getNotifications',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).getNotifications(
                session,
                params['userId'],
              ),
        ),
        'markNotificationAsRead': _i1.MethodConnector(
          name: 'markNotificationAsRead',
          params: {
            'notificationId': _i1.ParameterDescription(
              name: 'notificationId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint)
                  .markNotificationAsRead(session, params['notificationId']),
        ),
        'markAllNotificationsAsRead': _i1.MethodConnector(
          name: 'markAllNotificationsAsRead',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint)
                  .markAllNotificationsAsRead(session, params['userId']),
        ),
        'deleteNotification': _i1.MethodConnector(
          name: 'deleteNotification',
          params: {
            'notificationId': _i1.ParameterDescription(
              name: 'notificationId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint).deleteNotification(
                session,
                params['notificationId'],
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
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['global'] as _i4.GlobalEndpoint)
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
              ) => (endpoints['global'] as _i4.GlobalEndpoint).streamMoodPins(
                session,
              ),
        ),
      },
    );
    connectors['jwtRefresh'] = _i1.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _i1.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _i1.ParameterDescription(
              name: 'refreshToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['jwtRefresh'] as _i5.JwtRefreshEndpoint)
                  .refreshAccessToken(
                    session,
                    refreshToken: params['refreshToken'],
                  ),
        ),
      },
    );
    connectors['socials'] = _i1.EndpointConnector(
      name: 'socials',
      endpoint: endpoints['socials']!,
      methodConnectors: {
        'getActiveSessions': _i1.MethodConnector(
          name: 'getActiveSessions',
          params: {},
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).getActiveSessions(
                session,
              ),
        ),
        'createSession': _i1.MethodConnector(
          name: 'createSession',
          params: {
            'title': _i1.ParameterDescription(
              name: 'title',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'hostId': _i1.ParameterDescription(
              name: 'hostId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'hostName': _i1.ParameterDescription(
              name: 'hostName',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'hostAvatarUrl': _i1.ParameterDescription(
              name: 'hostAvatarUrl',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'isVoiceOnly': _i1.ParameterDescription(
              name: 'isVoiceOnly',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).createSession(
                session,
                params['title'],
                params['hostId'],
                params['hostName'],
                params['hostAvatarUrl'],
                params['isVoiceOnly'],
              ),
        ),
        'joinSession': _i1.MethodConnector(
          name: 'joinSession',
          params: {
            'sessionId': _i1.ParameterDescription(
              name: 'sessionId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).joinSession(
                session,
                params['sessionId'],
              ),
        ),
        'leaveSession': _i1.MethodConnector(
          name: 'leaveSession',
          params: {
            'sessionId': _i1.ParameterDescription(
              name: 'sessionId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).leaveSession(
                session,
                params['sessionId'],
              ),
        ),
        'getSession': _i1.MethodConnector(
          name: 'getSession',
          params: {
            'sessionId': _i1.ParameterDescription(
              name: 'sessionId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).getSession(
                session,
                params['sessionId'],
              ),
        ),
        'getAgoraCredentials': _i1.MethodConnector(
          name: 'getAgoraCredentials',
          params: {
            'channelName': _i1.ParameterDescription(
              name: 'channelName',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).getAgoraCredentials(
                session,
                params['channelName'],
                params['userId'],
              ),
        ),
        'endSession': _i1.MethodConnector(
          name: 'endSession',
          params: {
            'sessionId': _i1.ParameterDescription(
              name: 'sessionId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'hostId': _i1.ParameterDescription(
              name: 'hostId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).endSession(
                session,
                params['sessionId'],
                params['hostId'],
              ),
        ),
        'createScheduledSession': _i1.MethodConnector(
          name: 'createScheduledSession',
          params: {
            'title': _i1.ParameterDescription(
              name: 'title',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'hostId': _i1.ParameterDescription(
              name: 'hostId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'hostName': _i1.ParameterDescription(
              name: 'hostName',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'hostAvatarUrl': _i1.ParameterDescription(
              name: 'hostAvatarUrl',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'scheduledTime': _i1.ParameterDescription(
              name: 'scheduledTime',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
            'description': _i1.ParameterDescription(
              name: 'description',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'isVoiceOnly': _i1.ParameterDescription(
              name: 'isVoiceOnly',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint)
                  .createScheduledSession(
                    session,
                    params['title'],
                    params['hostId'],
                    params['hostName'],
                    params['hostAvatarUrl'],
                    params['scheduledTime'],
                    params['description'],
                    params['isVoiceOnly'],
                  ),
        ),
        'getUpcomingScheduledSessions': _i1.MethodConnector(
          name: 'getUpcomingScheduledSessions',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint)
                  .getUpcomingScheduledSessions(session, params['userId']),
        ),
        'getAllUpcomingScheduledSessions': _i1.MethodConnector(
          name: 'getAllUpcomingScheduledSessions',
          params: {},
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint)
                  .getAllUpcomingScheduledSessions(session),
        ),
        'cancelScheduledSession': _i1.MethodConnector(
          name: 'cancelScheduledSession',
          params: {
            'sessionId': _i1.ParameterDescription(
              name: 'sessionId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint)
                  .cancelScheduledSession(
                    session,
                    params['sessionId'],
                    params['userId'],
                  ),
        ),
        'startScheduledSession': _i1.MethodConnector(
          name: 'startScheduledSession',
          params: {
            'scheduledSessionId': _i1.ParameterDescription(
              name: 'scheduledSessionId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint)
                  .startScheduledSession(
                    session,
                    params['scheduledSessionId'],
                    params['userId'],
                  ),
        ),
        'getSessionsNeedingNotification': _i1.MethodConnector(
          name: 'getSessionsNeedingNotification',
          params: {},
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint)
                  .getSessionsNeedingNotification(session),
        ),
        'markSessionAsNotified': _i1.MethodConnector(
          name: 'markSessionAsNotified',
          params: {
            'sessionId': _i1.ParameterDescription(
              name: 'sessionId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint)
                  .markSessionAsNotified(session, params['sessionId']),
        ),
        'uploadStoryImage': _i1.MethodConnector(
          name: 'uploadStoryImage',
          params: {
            'imageData': _i1.ParameterDescription(
              name: 'imageData',
              type: _i1.getType<_i10.ByteData>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).uploadStoryImage(
                session,
                params['imageData'],
                params['userId'],
              ),
        ),
        'createStory': _i1.MethodConnector(
          name: 'createStory',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userName': _i1.ParameterDescription(
              name: 'userName',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userAvatarUrl': _i1.ParameterDescription(
              name: 'userAvatarUrl',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'imageUrls': _i1.ParameterDescription(
              name: 'imageUrls',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).createStory(
                session,
                params['userId'],
                params['userName'],
                params['userAvatarUrl'],
                params['imageUrls'],
              ),
        ),
        'getActiveStories': _i1.MethodConnector(
          name: 'getActiveStories',
          params: {},
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).getActiveStories(
                session,
              ),
        ),
        'getUserStories': _i1.MethodConnector(
          name: 'getUserStories',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).getUserStories(
                session,
                params['userId'],
              ),
        ),
        'viewStory': _i1.MethodConnector(
          name: 'viewStory',
          params: {
            'storyId': _i1.ParameterDescription(
              name: 'storyId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'viewerId': _i1.ParameterDescription(
              name: 'viewerId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).viewStory(
                session,
                params['storyId'],
                params['viewerId'],
              ),
        ),
        'deleteStory': _i1.MethodConnector(
          name: 'deleteStory',
          params: {
            'storyId': _i1.ParameterDescription(
              name: 'storyId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['socials'] as _i6.SocialsEndpoint).deleteStory(
                session,
                params['storyId'],
                params['userId'],
              ),
        ),
      },
    );
    connectors['greeting'] = _i1.EndpointConnector(
      name: 'greeting',
      endpoint: endpoints['greeting']!,
      methodConnectors: {
        'hello': _i1.MethodConnector(
          name: 'hello',
          params: {
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['greeting'] as _i7.GreetingEndpoint).hello(
                session,
                params['name'],
              ),
        ),
      },
    );
    connectors['logging'] = _i1.EndpointConnector(
      name: 'logging',
      endpoint: endpoints['logging']!,
      methodConnectors: {
        'createEntry': _i1.MethodConnector(
          name: 'createEntry',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'date': _i1.ParameterDescription(
              name: 'date',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
            'mood': _i1.ParameterDescription(
              name: 'mood',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'habits': _i1.ParameterDescription(
              name: 'habits',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
            'notes': _i1.ParameterDescription(
              name: 'notes',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['logging'] as _i8.LoggingEndpoint).createEntry(
                session,
                params['userId'],
                params['date'],
                params['mood'],
                params['habits'],
                params['notes'],
              ),
        ),
        'getEntries': _i1.MethodConnector(
          name: 'getEntries',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'startDate': _i1.ParameterDescription(
              name: 'startDate',
              type: _i1.getType<DateTime?>(),
              nullable: true,
            ),
            'endDate': _i1.ParameterDescription(
              name: 'endDate',
              type: _i1.getType<DateTime?>(),
              nullable: true,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['logging'] as _i8.LoggingEndpoint).getEntries(
                session,
                params['userId'],
                startDate: params['startDate'],
                endDate: params['endDate'],
              ),
        ),
        'getEntryForDate': _i1.MethodConnector(
          name: 'getEntryForDate',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'date': _i1.ParameterDescription(
              name: 'date',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['logging'] as _i8.LoggingEndpoint).getEntryForDate(
                session,
                params['userId'],
                params['date'],
              ),
        ),
        'updateEntry': _i1.MethodConnector(
          name: 'updateEntry',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'entryId': _i1.ParameterDescription(
              name: 'entryId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'date': _i1.ParameterDescription(
              name: 'date',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
            'mood': _i1.ParameterDescription(
              name: 'mood',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'habits': _i1.ParameterDescription(
              name: 'habits',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
            'notes': _i1.ParameterDescription(
              name: 'notes',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['logging'] as _i8.LoggingEndpoint).updateEntry(
                session,
                params['userId'],
                params['entryId'],
                params['date'],
                params['mood'],
                params['habits'],
                params['notes'],
              ),
        ),
        'deleteEntry': _i1.MethodConnector(
          name: 'deleteEntry',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'entryId': _i1.ParameterDescription(
              name: 'entryId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call: (_i1.Session session, Map<String, dynamic> params) async =>
              (endpoints['logging'] as _i8.LoggingEndpoint).deleteEntry(
                session,
                params['userId'],
                params['entryId'],
              ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _i11.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _i12.Endpoints()
      ..initializeEndpoints(server);
  }
}
