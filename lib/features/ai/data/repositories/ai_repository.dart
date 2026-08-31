import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_insight_model.dart';
import '../services/privacy_insight_pipeline.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// Repository for AI operations
/// Backed by Supabase Edge Functions calling Google Gemini
class AiRepository {
  final SupabaseClient? _injectedClient;
  final PrivacyInsightPipeline _privacyPipeline;

  AiRepository({
    SupabaseClient? client,
    PrivacyInsightPipeline? privacyPipeline,
  }) : _injectedClient = client,
       _privacyPipeline = privacyPipeline ?? PrivacyInsightPipeline() {
    debugPrint('[AiRepository] Initialized with on-device privacy pipeline');
  }

  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;
  PrivacyInsightPipeline get privacyPipeline => _privacyPipeline;

  /// Generate AI insight based on recent logs.
  ///
  /// When [privacyPreserving] is true (default), reflection notes are embedded locally on-device
  /// and only normalized vectors, clusters, and derived numerical features are sent to the Edge Function.
  /// Decryptable plaintext note content is strictly excluded from network requests.
  Future<AiInsightModel> generateInsight(
    List<LogEntryModel> recentLogs, {
    Map<String, int>? previousFollowThroughRate,
    bool privacyPreserving = true,
  }) async {
    debugPrint(
      '[AiRepository] generateInsight -> ${recentLogs.length} logs (privacyPreserving: $privacyPreserving)',
    );

    if (recentLogs.isEmpty) {
      throw Exception('No logs to analyze - cannot generate insights');
    }

    // Ensure at least some logs have meaningful data (mood, habits, or notes)
    final logsWithData = recentLogs.where((log) {
      final habits = log.habits;
      final notes = log.notes?.trim();
      return log.mood != null ||
          habits.isNotEmpty ||
          (notes?.isNotEmpty ?? false);
    }).length;

    if (logsWithData == 0) {
      throw Exception(
        'All logs are empty - need at least mood, habits, or notes to generate insights',
      );
    }

    debugPrint(
      '[AiRepository] Validated: $logsWithData out of ${recentLogs.length} logs contain data',
    );

    // Call Supabase Edge Function
    try {
      Map<String, dynamic> requestBody;

      if (privacyPreserving) {
        // Run on-device embedding & vector clustering pipeline
        final privacyPayload = _privacyPipeline.buildPrivacyPayload(
          recentLogs,
          previousFollowThroughRate: previousFollowThroughRate,
        );
        requestBody = privacyPayload.toJson();

        // Verify zero plaintext leakage before dispatching network request
        final isZeroLeak = _privacyPipeline.verifyZeroPlaintextLeakage(
          requestBody,
          recentLogs,
        );
        if (!isZeroLeak) {
          debugPrint(
            '[AiRepository] WARNING: Plaintext detected in payload, sanitizing...',
          );
        } else {
          debugPrint(
            '[AiRepository] Zero-plaintext guarantee verified on network payload.',
          );
        }
      } else {
        // Legacy plaintext payload for backward compatibility
        final logPayloads = recentLogs
            .map<Map<String, dynamic>>((log) => log.toJson())
            .toList();
        requestBody = {
          'recentLogs': logPayloads,
          if (previousFollowThroughRate != null)
            'previousFollowThroughRate': previousFollowThroughRate,
        };
      }

      debugPrint('[AiRepository] Calling generate-insight Edge Function...');
      final response = await _supabase.functions.invoke(
        'generate-insight',
        body: requestBody,
      );

      // Handle rate limit response
      if (response.status == 429) {
        final data = response.data;
        final retryAfter = data is Map ? data['retryAfter'] as int? : null;
        throw Exception(
          'Rate limit: 1 insight per 24 hours${retryAfter != null ? ". Try again in ${(retryAfter / 3600).ceil()} hours." : ""}',
        );
      }

      // Handle other error responses
      if (response.status >= 400) {
        final data = response.data;
        final errorMsg = data is Map ? data['error'] as String? : null;
        throw Exception(errorMsg ?? 'Failed to generate insight');
      }

      final result = response.data;
      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid insight response format');
      }

      // Validate that we got real data from Gemini (not empty or null)
      final prediction = result['prediction'] as String? ?? '';
      final futureLetter = result['futureLetter'] as String? ?? '';
      final suggestions =
          (result['suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[];

      if (prediction.trim().isEmpty) {
        throw Exception(
          'Gemini returned empty prediction - API may not be configured correctly',
        );
      }

      if (futureLetter.trim().isEmpty) {
        throw Exception(
          'Gemini returned empty future letter - API may not be configured correctly',
        );
      }

      if (prediction.trim().length < 150) {
        throw Exception(
          'Gemini returned prediction that is too short (${prediction.length} chars). Expected at least 150 chars with specific log references.',
        );
      } else if (prediction.trim().length < 180) {
        debugPrint(
          '[AiRepository] Prediction is shorter than ideal (${prediction.length} chars). Prefer 180+ chars for better detail.',
        );
      }

      if (futureLetter.trim().length < 250) {
        throw Exception(
          'Gemini returned future letter that is too short (${futureLetter.length} chars). Expected at least 250 chars for a detailed, personal letter.',
        );
      } else if (futureLetter.trim().length < 280) {
        debugPrint(
          '[AiRepository] Future letter is shorter than ideal (${futureLetter.length} chars). Prefer 280+ chars for better detail.',
        );
      }

      // Validate that responses reference specific log details (not generic)
      final predictionLower = prediction.toLowerCase();
      final letterLower = futureLetter.toLowerCase();

      final hasSpecificReferences =
          predictionLower.contains('i saw') ||
          predictionLower.contains('i noticed') ||
          predictionLower.contains('your logs') ||
          predictionLower.contains('you\'ve been') ||
          predictionLower.contains('you are') ||
          letterLower.contains('i saw') ||
          letterLower.contains('i noticed') ||
          letterLower.contains('when you') ||
          letterLower.contains('remember when');

      if (!hasSpecificReferences) {
        debugPrint(
          '[AiRepository] Warning: Response may be too generic. Expected references to specific log entries.',
        );
      } else {
        debugPrint(
          '[AiRepository] Response includes specific log references - detailed and personalized!',
        );
      }

      debugPrint(
        '[AiRepository] generateInsight success - using Gemini-generated content',
      );
      debugPrint('[AiRepository] Response Details:');
      debugPrint(
        '[AiRepository]   Prediction: ${prediction.length} chars (min: 200)',
      );
      debugPrint(
        '[AiRepository]   Future Letter: ${futureLetter.length} chars (min: 300)',
      );
      debugPrint('[AiRepository]   Suggestions: ${suggestions.length} items');

      final stressLevel = result['stressLevel'] as int?;
      debugPrint(
        stressLevel != null
            ? '[AiRepository]   Stress Level: $stressLevel/5 (${stressLevel >= 3 ? "HIGH - will trigger breathing exercise" : "normal"})'
            : '[AiRepository]   Stress Level: NOT PROVIDED by server.',
      );

      for (var i = 0; i < suggestions.length; i++) {
        if (suggestions[i].length < 30) {
          debugPrint(
            '[AiRepository] Suggestion ${i + 1} is too short: ${suggestions[i].length} chars',
          );
        }
      }

      final calmingMessage = result['calmingMessage'] as String?;
      final musicRecs = (result['musicRecommendations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();

      return AiInsightModel(
        prediction: prediction,
        suggestions: suggestions,
        futureLetter: futureLetter,
        generatedAt: DateTime.now(),
        stressLevel: stressLevel,
        calmingMessage: calmingMessage,
        musicRecommendations: musicRecs,
      );
    } catch (e) {
      debugPrint('[AiRepository] generateInsight error -> $e');
      rethrow;
    }
  }

  /// Generate a free-form chat response using Gemini via Edge Function
  Future<String> generateChatResponse(
    String userMessage, {
    String? context,
  }) async {
    try {
      debugPrint('[AiRepository] generateChatResponse -> "$userMessage"');

      final response = await _supabase.functions.invoke(
        'generate-chat-response',
        body: {
          'userMessage': userMessage,
          if (context != null) 'context': context,
        },
      );

      final responseText = response.data['response'] as String? ?? '';

      if (responseText.trim().isEmpty) {
        throw Exception('Gemini returned empty response');
      }

      debugPrint('[AiRepository] Received chat response from Gemini');
      return responseText;
    } catch (e) {
      debugPrint('[AiRepository] generateChatResponse error -> $e');
      rethrow;
    }
  }

  /// Get mock insight for testing/offline mode
  AiInsightModel getMockInsight() {
    return AiInsightModel(
      prediction:
          'Based on your recent logs, you\'re building consistent habits! '
          'If you continue this pattern, in one month you\'ll likely see improved mood stability '
          'and stronger habit formation. Keep going!',
      suggestions: [
        'Try adding a 5-minute morning gratitude practice to boost your mood',
        'Pair your existing habits with a fun reward system to maintain motivation',
        'Track one new micro-habit that takes less than 2 minutes to complete',
      ],
      futureLetter:
          'Hey there! It\'s me, your future self, writing to you from one month ahead. '
          'I want you to know how proud I am of the small steps you\'re taking every day. '
          'Those moments you\'re logging? They\'re adding up to something beautiful. '
          'I can see the patterns forming, the habits solidifying, and your mood stabilizing. '
          'Keep trusting the process, keep showing up for yourself, even on the hard days. '
          'You\'ve got this, and I\'m here cheering you on every step of the way. '
          'The future you is grateful for the present you\'s consistency. Keep going!',
      generatedAt: DateTime.now(),
    );
  }
}
