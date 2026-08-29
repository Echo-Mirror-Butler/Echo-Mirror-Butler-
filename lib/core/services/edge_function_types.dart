/// Shared contract types for Supabase Edge Functions.
///
/// These types document the expected request payload and response shape
/// for every deployed Edge Function. Both the web (frontend/src/) and
/// Flutter (lib/) clients should conform to these contracts.
///
/// When adding or modifying an Edge Function, update this file and the
/// corresponding TypeScript mirror in frontend/src/types/edge-functions.ts.

// ── create-stellar-wallet ─────────────────────────────────────────────────────
// Creates a Stellar wallet for the authenticated user.
// Auth: JWT (user extracted from auth header)
// Request body: empty (user is identified via JWT)
class CreateStellarWalletResponse {
  final String? message;
  final String? publicKey;
  final String? error;
  final String? details;

  CreateStellarWalletResponse({
    this.message,
    this.publicKey,
    this.error,
    this.details,
  });

  factory CreateStellarWalletResponse.fromJson(Map<String, dynamic> json) {
    return CreateStellarWalletResponse(
      message: json['message'] as String?,
      publicKey: json['publicKey'] as String?,
      error: json['error'] as String?,
      details: json['details'] as String?,
    );
  }
}

// ── send-echo ─────────────────────────────────────────────────────────────────
// Sends ECHO tokens from the authenticated user to a recipient.
// Auth: JWT
class SendEchoRequest {
  final String recipientId;
  final double amount;
  final String? message;

  SendEchoRequest({
    required this.recipientId,
    required this.amount,
    this.message,
  });

  Map<String, dynamic> toJson() => {
    'recipient_id': recipientId,
    'amount': amount,
    if (message != null) 'message': message,
  };
}

class SendEchoResponse {
  final bool? success;
  final String? transactionId;
  final String? error;

  SendEchoResponse({this.success, this.transactionId, this.error});

  factory SendEchoResponse.fromJson(Map<String, dynamic> json) {
    return SendEchoResponse(
      success: json['success'] as bool?,
      transactionId: json['transactionId'] as String?,
      error: json['error'] as String?,
    );
  }
}

// ── generate-insight ──────────────────────────────────────────────────────────
// Generates AI insights from recent mood logs.
// Supports both privacy-preserving on-device embedding payloads and legacy payloads.
// Auth: JWT
class GenerateInsightRequest {
  final List<Map<String, dynamic>>? recentLogs;
  final bool privacyMode;
  final Map<String, dynamic>? moodTrend;
  final Map<String, int>? habitFrequencies;
  final Map<String, double>? habitMoodCorrelations;
  final Map<String, dynamic>? temporalPatterns;
  final List<Map<String, dynamic>>? sanitizedLogs;
  final List<Map<String, dynamic>>? clusters;
  final List<Map<String, dynamic>>? similarityHighlights;
  final Map<String, int>? previousFollowThroughRate;

  GenerateInsightRequest({
    this.recentLogs,
    this.privacyMode = false,
    this.moodTrend,
    this.habitFrequencies,
    this.habitMoodCorrelations,
    this.temporalPatterns,
    this.sanitizedLogs,
    this.clusters,
    this.similarityHighlights,
    this.previousFollowThroughRate,
  });

  Map<String, dynamic> toJson() => {
    if (recentLogs != null) 'recentLogs': recentLogs,
    'privacyMode': privacyMode,
    if (moodTrend != null) 'moodTrend': moodTrend,
    if (habitFrequencies != null) 'habitFrequencies': habitFrequencies,
    if (habitMoodCorrelations != null)
      'habitMoodCorrelations': habitMoodCorrelations,
    if (temporalPatterns != null) 'temporalPatterns': temporalPatterns,
    if (sanitizedLogs != null) 'sanitizedLogs': sanitizedLogs,
    if (clusters != null) 'clusters': clusters,
    if (similarityHighlights != null)
      'similarityHighlights': similarityHighlights,
    if (previousFollowThroughRate != null)
      'previousFollowThroughRate': previousFollowThroughRate,
  };
}

class GenerateInsightResponse {
  final String prediction;
  final List<String> suggestions;
  final String futureLetter;
  final int stressLevel;
  final String? calmingMessage;
  final List<String>? musicRecommendations;
  final List<MoodDriver> moodDrivers;
  final String bestTimeOfDay;
  final String worstTimeOfDay;
  final List<String> recommendations;
  final int moodScore;

  GenerateInsightResponse({
    required this.prediction,
    required this.suggestions,
    required this.futureLetter,
    required this.stressLevel,
    this.calmingMessage,
    this.musicRecommendations,
    required this.moodDrivers,
    required this.bestTimeOfDay,
    required this.worstTimeOfDay,
    required this.recommendations,
    required this.moodScore,
  });

  factory GenerateInsightResponse.fromJson(Map<String, dynamic> json) {
    return GenerateInsightResponse(
      prediction: json['prediction'] as String? ?? '',
      suggestions:
          (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      futureLetter: json['futureLetter'] as String? ?? '',
      stressLevel: json['stressLevel'] as int? ?? 0,
      calmingMessage: json['calmingMessage'] as String?,
      musicRecommendations: (json['musicRecommendations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      moodDrivers:
          (json['moodDrivers'] as List<dynamic>?)
              ?.map((e) => MoodDriver.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bestTimeOfDay: json['bestTimeOfDay'] as String? ?? '',
      worstTimeOfDay: json['worstTimeOfDay'] as String? ?? '',
      recommendations:
          (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      moodScore: json['moodScore'] as int? ?? 0,
    );
  }
}

class MoodDriver {
  final String label;
  final int percentage;

  MoodDriver({required this.label, required this.percentage});

  factory MoodDriver.fromJson(Map<String, dynamic> json) {
    return MoodDriver(
      label: json['label'] as String? ?? '',
      percentage: json['percentage'] as int? ?? 0,
    );
  }
}

// ── generate-chat-response ────────────────────────────────────────────────────
// Generates a free-form chat response using Gemini.
// Auth: JWT
class GenerateChatResponseRequest {
  final String userMessage;
  final String? context;

  GenerateChatResponseRequest({required this.userMessage, this.context});

  Map<String, dynamic> toJson() => {
    'userMessage': userMessage,
    if (context != null) 'context': context,
  };
}

class GenerateChatResponseResponse {
  final String response;
  final String? error;

  GenerateChatResponseResponse({required this.response, this.error});

  factory GenerateChatResponseResponse.fromJson(Map<String, dynamic> json) {
    return GenerateChatResponseResponse(
      response: json['response'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

// ── generate-encouragement ────────────────────────────────────────────────────
// Generates an encouraging message for a mood cluster.
// Auth: JWT
class GenerateEncouragementRequest {
  final String sentiment;
  final int nearbyCount;

  GenerateEncouragementRequest({
    required this.sentiment,
    required this.nearbyCount,
  });

  Map<String, dynamic> toJson() => {
    'sentiment': sentiment,
    'nearbyCount': nearbyCount,
  };
}

class GenerateEncouragementResponse {
  final String message;
  final String? error;

  GenerateEncouragementResponse({required this.message, this.error});

  factory GenerateEncouragementResponse.fromJson(Map<String, dynamic> json) {
    return GenerateEncouragementResponse(
      message: json['message'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

// ── save-future-letter ────────────────────────────────────────────────────────
// Persists a future letter for the user.
// Auth: JWT
class SaveFutureLetterRequest {
  final String userId;
  final String content;
  final String generatedAt;

  SaveFutureLetterRequest({
    required this.userId,
    required this.content,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'content': content,
    'generatedAt': generatedAt,
  };
}

class SaveFutureLetterResponse {
  final String? id;
  final String? error;

  SaveFutureLetterResponse({this.id, this.error});

  factory SaveFutureLetterResponse.fromJson(Map<String, dynamic> json) {
    return SaveFutureLetterResponse(
      id: json['id'] as String?,
      error: json['error'] as String?,
    );
  }
}

// ── get-agora-credentials ─────────────────────────────────────────────────────
// Gets Agora video call credentials.
// Auth: JWT
class GetAgoraCredentialsRequest {
  final String sessionId;
  final String userId;

  GetAgoraCredentialsRequest({required this.sessionId, required this.userId});

  Map<String, dynamic> toJson() => {'sessionId': sessionId, 'userId': userId};
}

class GetAgoraCredentialsResponse {
  final String token;
  final String appId;
  final String? error;

  GetAgoraCredentialsResponse({
    required this.token,
    required this.appId,
    this.error,
  });

  factory GetAgoraCredentialsResponse.fromJson(Map<String, dynamic> json) {
    return GetAgoraCredentialsResponse(
      token: json['token'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

// ── export-user-data ──────────────────────────────────────────────────────────
// Exports all user data as CSV.
// Auth: JWT (service role key used internally)
class ExportUserDataResponse {
  final String? csv;
  final String? error;

  ExportUserDataResponse({this.csv, this.error});

  factory ExportUserDataResponse.fromJson(Map<String, dynamic> json) {
    return ExportUserDataResponse(
      csv: json['csv'] as String?,
      error: json['error'] as String?,
    );
  }
}

// ── send-daily-reminder ───────────────────────────────────────────────────────
// Scheduled function that sends push notifications to users due for a reminder.
// Auth: Service role key (called by cron)
// Request body: empty (reads from DB)
class SendDailyReminderResponse {
  final int sent;
  final int failed;
  final String? error;

  SendDailyReminderResponse({
    required this.sent,
    required this.failed,
    this.error,
  });

  factory SendDailyReminderResponse.fromJson(Map<String, dynamic> json) {
    return SendDailyReminderResponse(
      sent: json['sent'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}
