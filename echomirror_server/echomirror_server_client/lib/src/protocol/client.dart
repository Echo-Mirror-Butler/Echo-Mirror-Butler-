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
import 'package:echomirror_server_client/src/protocol/ai_insight.dart' as _i3;
import 'package:echomirror_server_client/src/protocol/log_entry.dart' as _i4;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i5;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i6;
import 'package:echomirror_server_client/src/protocol/mood_pin.dart' as _i7;
import 'dart:typed_data' as _i8;
import 'package:echomirror_server_client/src/protocol/video_post.dart' as _i9;
import 'package:echomirror_server_client/src/protocol/mood_pin_comment.dart'
    as _i10;
import 'package:echomirror_server_client/src/protocol/mood_comment_notification.dart'
    as _i11;
import 'package:echomirror_server_client/src/protocol/video_session.dart'
    as _i12;
import 'package:echomirror_server_client/src/protocol/scheduled_session.dart'
    as _i13;
import 'package:echomirror_server_client/src/protocol/story.dart' as _i14;
import 'package:echomirror_server_client/src/protocol/greeting.dart' as _i15;
import 'protocol.dart' as _i16;

/// Endpoint for AI-powered insights using Gemini
/// {@category Endpoint}
class EndpointAi extends _i1.EndpointRef {
  EndpointAi(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'ai';

  /// Generate AI insights based on recent user logs
  ///
  /// Analyzes patterns in the logs and generates:
  /// - A prediction about future outcomes
  /// - Actionable habit suggestions
  /// - A motivational letter from "future me"
  _i2.Future<_i3.AiInsight> generateInsight(List<_i4.LogEntry> recentLogs) =>
      caller.callServerEndpoint<_i3.AiInsight>(
        'ai',
        'generateInsight',
        {'recentLogs': recentLogs},
      );

  /// Generate a free-form chat response using Gemini
  /// This allows the AI butler to have natural conversations without hardcoded responses
  _i2.Future<String> generateChatResponse(
    String userMessage,
    String? context,
  ) => caller.callServerEndpoint<String>(
    'ai',
    'generateChatResponse',
    {
      'userMessage': userMessage,
      'context': context,
    },
  );
}

/// By extending [EmailIdpBaseEndpoint], the email identity provider endpoints
/// are made available on the server and enable the corresponding sign-in widget
/// on the client.
/// {@category Endpoint}
class EndpointEmailIdp extends _i5.EndpointEmailIdpBase {
  EndpointEmailIdp(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _i2.Future<_i6.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_i6.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _i2.Future<_i1.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_i1.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _i2.Future<String> verifyRegistrationCode({
    required _i1.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _i2.Future<_i6.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_i6.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _i2.Future<_i1.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_i1.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _i2.Future<String> verifyPasswordResetCode({
    required _i1.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _i2.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );
}

/// Global Mirror endpoint for anonymous mood sharing and videos
/// {@category Endpoint}
class EndpointGlobal extends _i1.EndpointRef {
  EndpointGlobal(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'global';

  /// Stream mood pins in real-time (every 5 seconds)
  _i2.Stream<List<_i7.MoodPin>> streamMoodPins() =>
      caller.callStreamingServerEndpoint<
        _i2.Stream<List<_i7.MoodPin>>,
        List<_i7.MoodPin>
      >(
        'global',
        'streamMoodPins',
        {},
        {},
      );

  /// Add a new mood pin (anonymized)
  /// Returns the pin ID if successful, null otherwise
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
    _i8.ByteData videoData,
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
    _i8.ByteData imageData,
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
  _i2.Future<List<_i9.VideoPost>> getVideoFeed(
    int offset,
    int limit,
  ) => caller.callServerEndpoint<List<_i9.VideoPost>>(
    'global',
    'getVideoFeed',
    {
      'offset': offset,
      'limit': limit,
    },
  );

  /// Get mood statistics for analytics (optional)
  _i2.Future<Map<String, int>> getMoodStatistics() =>
      caller.callServerEndpoint<Map<String, int>>(
        'global',
        'getMoodStatistics',
        {},
      );

  /// Add a comment to a mood pin
  /// Returns comment ID if successful, null otherwise
  /// For now, comments are anonymous (userId is optional)
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
  _i2.Future<List<_i10.MoodPinComment>> getCommentsForPin(int moodPinId) =>
      caller.callServerEndpoint<List<_i10.MoodPinComment>>(
        'global',
        'getCommentsForPin',
        {'moodPinId': moodPinId},
      );

  /// Get notifications for a specific user (by userId parameter)
  /// Note: For now, notifications are disabled as comments are anonymous
  /// This endpoint is prepared for future authentication implementation
  _i2.Future<List<_i11.MoodCommentNotification>> getNotifications(int userId) =>
      caller.callServerEndpoint<List<_i11.MoodCommentNotification>>(
        'global',
        'getNotifications',
        {'userId': userId},
      );

  /// Mark notification as read
  /// Note: For future authentication implementation
  _i2.Future<bool> markNotificationAsRead(int notificationId) =>
      caller.callServerEndpoint<bool>(
        'global',
        'markNotificationAsRead',
        {'notificationId': notificationId},
      );

  /// Mark all notifications as read for a user
  /// Note: For future authentication implementation
  _i2.Future<bool> markAllNotificationsAsRead(int userId) =>
      caller.callServerEndpoint<bool>(
        'global',
        'markAllNotificationsAsRead',
        {'userId': userId},
      );

  /// Delete a notification
  /// Note: For future authentication implementation
  _i2.Future<bool> deleteNotification(int notificationId) =>
      caller.callServerEndpoint<bool>(
        'global',
        'deleteNotification',
        {'notificationId': notificationId},
      );

  /// Generate cluster encouragement message for Global Mirror mood clusters
  ///
  /// Creates a short, supportive message when users tap on mood clusters
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

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _i6.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _i2.Future<_i6.AuthSuccess> refreshAccessToken({
    required String refreshToken,
  }) => caller.callServerEndpoint<_i6.AuthSuccess>(
    'jwtRefresh',
    'refreshAccessToken',
    {'refreshToken': refreshToken},
    authenticated: false,
  );
}

/// Socials endpoint for video/voice call sessions
/// {@category Endpoint}
class EndpointSocials extends _i1.EndpointRef {
  EndpointSocials(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'socials';

  /// Get all active video sessions
  _i2.Future<List<_i12.VideoSession>> getActiveSessions() =>
      caller.callServerEndpoint<List<_i12.VideoSession>>(
        'socials',
        'getActiveSessions',
        {},
      );

  /// Create a new video session
  _i2.Future<_i12.VideoSession> createSession(
    String title,
    String hostId,
    String hostName,
    String? hostAvatarUrl,
    bool isVoiceOnly,
  ) => caller.callServerEndpoint<_i12.VideoSession>(
    'socials',
    'createSession',
    {
      'title': title,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatarUrl': hostAvatarUrl,
      'isVoiceOnly': isVoiceOnly,
    },
  );

  /// Join a video session
  _i2.Future<bool> joinSession(int sessionId) =>
      caller.callServerEndpoint<bool>(
        'socials',
        'joinSession',
        {'sessionId': sessionId},
      );

  /// Leave a video session
  _i2.Future<void> leaveSession(int sessionId) =>
      caller.callServerEndpoint<void>(
        'socials',
        'leaveSession',
        {'sessionId': sessionId},
      );

  /// Get session details by ID
  _i2.Future<_i12.VideoSession?> getSession(int sessionId) =>
      caller.callServerEndpoint<_i12.VideoSession?>(
        'socials',
        'getSession',
        {'sessionId': sessionId},
      );

  /// Get Agora credentials for WebRTC with token generation
  _i2.Future<Map<String, String>> getAgoraCredentials(
    String channelName,
    int userId,
  ) => caller.callServerEndpoint<Map<String, String>>(
    'socials',
    'getAgoraCredentials',
    {
      'channelName': channelName,
      'userId': userId,
    },
  );

  /// End a session (host only)
  _i2.Future<bool> endSession(
    int sessionId,
    String hostId,
  ) => caller.callServerEndpoint<bool>(
    'socials',
    'endSession',
    {
      'sessionId': sessionId,
      'hostId': hostId,
    },
  );

  /// Create a scheduled session
  _i2.Future<_i13.ScheduledSession> createScheduledSession(
    String title,
    String hostId,
    String hostName,
    String? hostAvatarUrl,
    DateTime scheduledTime,
    String? description,
    bool isVoiceOnly,
  ) => caller.callServerEndpoint<_i13.ScheduledSession>(
    'socials',
    'createScheduledSession',
    {
      'title': title,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatarUrl': hostAvatarUrl,
      'scheduledTime': scheduledTime,
      'description': description,
      'isVoiceOnly': isVoiceOnly,
    },
  );

  /// Get upcoming scheduled sessions for a user
  _i2.Future<List<_i13.ScheduledSession>> getUpcomingScheduledSessions(
    String userId,
  ) => caller.callServerEndpoint<List<_i13.ScheduledSession>>(
    'socials',
    'getUpcomingScheduledSessions',
    {'userId': userId},
  );

  /// Get all upcoming public scheduled sessions
  _i2.Future<List<_i13.ScheduledSession>> getAllUpcomingScheduledSessions() =>
      caller.callServerEndpoint<List<_i13.ScheduledSession>>(
        'socials',
        'getAllUpcomingScheduledSessions',
        {},
      );

  /// Cancel a scheduled session
  _i2.Future<bool> cancelScheduledSession(
    int sessionId,
    String userId,
  ) => caller.callServerEndpoint<bool>(
    'socials',
    'cancelScheduledSession',
    {
      'sessionId': sessionId,
      'userId': userId,
    },
  );

  /// Start a scheduled session (converts to active session)
  _i2.Future<_i12.VideoSession?> startScheduledSession(
    int scheduledSessionId,
    String userId,
  ) => caller.callServerEndpoint<_i12.VideoSession?>(
    'socials',
    'startScheduledSession',
    {
      'scheduledSessionId': scheduledSessionId,
      'userId': userId,
    },
  );

  /// Get sessions that need notifications (within 10 minutes, not yet notified)
  _i2.Future<List<_i13.ScheduledSession>> getSessionsNeedingNotification() =>
      caller.callServerEndpoint<List<_i13.ScheduledSession>>(
        'socials',
        'getSessionsNeedingNotification',
        {},
      );

  /// Mark session as notified
  _i2.Future<bool> markSessionAsNotified(int sessionId) =>
      caller.callServerEndpoint<bool>(
        'socials',
        'markSessionAsNotified',
        {'sessionId': sessionId},
      );

  /// Upload a story image and return its public URL
  _i2.Future<String?> uploadStoryImage(
    _i8.ByteData imageData,
    String userId,
  ) => caller.callServerEndpoint<String?>(
    'socials',
    'uploadStoryImage',
    {
      'imageData': imageData,
      'userId': userId,
    },
  );

  /// Create a new story
  _i2.Future<_i14.Story> createStory(
    String userId,
    String userName,
    String? userAvatarUrl,
    List<String> imageUrls,
  ) => caller.callServerEndpoint<_i14.Story>(
    'socials',
    'createStory',
    {
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'imageUrls': imageUrls,
    },
  );

  /// Get all active stories (not expired)
  _i2.Future<List<_i14.Story>> getActiveStories() =>
      caller.callServerEndpoint<List<_i14.Story>>(
        'socials',
        'getActiveStories',
        {},
      );

  /// Get stories by user ID
  _i2.Future<List<_i14.Story>> getUserStories(String userId) =>
      caller.callServerEndpoint<List<_i14.Story>>(
        'socials',
        'getUserStories',
        {'userId': userId},
      );

  /// View a story (increment view count and add viewer)
  _i2.Future<void> viewStory(
    int storyId,
    String viewerId,
  ) => caller.callServerEndpoint<void>(
    'socials',
    'viewStory',
    {
      'storyId': storyId,
      'viewerId': viewerId,
    },
  );

  /// Delete a story
  _i2.Future<bool> deleteStory(
    int storyId,
    String userId,
  ) => caller.callServerEndpoint<bool>(
    'socials',
    'deleteStory',
    {
      'storyId': storyId,
      'userId': userId,
    },
  );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _i1.EndpointRef {
  EndpointGreeting(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _i2.Future<_i15.Greeting> hello(String name) =>
      caller.callServerEndpoint<_i15.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

/// Endpoint for logging operations - handles daily log entries
/// {@category Endpoint}
class EndpointLogging extends _i1.EndpointRef {
  EndpointLogging(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'logging';

  /// Create a new log entry
  _i2.Future<_i4.LogEntry> createEntry(
    String userId,
    DateTime date,
    int? mood,
    List<String> habits,
    String? notes,
  ) => caller.callServerEndpoint<_i4.LogEntry>(
    'logging',
    'createEntry',
    {
      'userId': userId,
      'date': date,
      'mood': mood,
      'habits': habits,
      'notes': notes,
    },
  );

  /// Get all entries for a user
  _i2.Future<List<_i4.LogEntry>> getEntries(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) => caller.callServerEndpoint<List<_i4.LogEntry>>(
    'logging',
    'getEntries',
    {
      'userId': userId,
      'startDate': startDate,
      'endDate': endDate,
    },
  );

  /// Get entry for a specific date
  _i2.Future<_i4.LogEntry?> getEntryForDate(
    String userId,
    DateTime date,
  ) => caller.callServerEndpoint<_i4.LogEntry?>(
    'logging',
    'getEntryForDate',
    {
      'userId': userId,
      'date': date,
    },
  );

  /// Update an existing entry
  _i2.Future<_i4.LogEntry> updateEntry(
    String userId,
    int entryId,
    DateTime date,
    int? mood,
    List<String> habits,
    String? notes,
  ) => caller.callServerEndpoint<_i4.LogEntry>(
    'logging',
    'updateEntry',
    {
      'userId': userId,
      'entryId': entryId,
      'date': date,
      'mood': mood,
      'habits': habits,
      'notes': notes,
    },
  );

  /// Delete an entry
  _i2.Future<void> deleteEntry(
    String userId,
    int entryId,
  ) => caller.callServerEndpoint<void>(
    'logging',
    'deleteEntry',
    {
      'userId': userId,
      'entryId': entryId,
    },
  );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _i5.Caller(client);
    serverpod_auth_core = _i6.Caller(client);
  }

  late final _i5.Caller serverpod_auth_idp;

  late final _i6.Caller serverpod_auth_core;
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
         _i16.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    ai = EndpointAi(this);
    emailIdp = EndpointEmailIdp(this);
    global = EndpointGlobal(this);
    jwtRefresh = EndpointJwtRefresh(this);
    socials = EndpointSocials(this);
    greeting = EndpointGreeting(this);
    logging = EndpointLogging(this);
    modules = Modules(this);
  }

  late final EndpointAi ai;

  late final EndpointEmailIdp emailIdp;

  late final EndpointGlobal global;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointSocials socials;

  late final EndpointGreeting greeting;

  late final EndpointLogging logging;

  late final Modules modules;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'ai': ai,
    'emailIdp': emailIdp,
    'global': global,
    'jwtRefresh': jwtRefresh,
    'socials': socials,
    'greeting': greeting,
    'logging': logging,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
