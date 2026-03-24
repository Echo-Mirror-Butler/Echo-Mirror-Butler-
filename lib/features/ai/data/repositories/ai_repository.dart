import 'package:flutter/foundation.dart';
import '../models/ai_insight_model.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// Repository for AI operations
/// Previously backed by Serverpod + Gemini — pending Supabase Edge Function migration
class AiRepository {
  AiRepository() {
    debugPrint('[AiRepository] Initialized');
  }

  /// Generate AI insight based on recent logs
  ///
  /// TODO: Implement via Supabase Edge Function once deployed.
  /// The edge function should accept log data and call Google Gemini API,
  /// returning prediction, suggestions, futureLetter, and stressLevel.
  Future<AiInsightModel> generateInsight(List<LogEntryModel> recentLogs) async {
    debugPrint('[AiRepository] generateInsight -> ${recentLogs.length} logs');
    throw UnimplementedError(
      'AI insights not yet migrated to Supabase Edge Functions. '
      'Implement by calling a Supabase Edge Function with the log data.',
    );
  }

  /// Generate a free-form chat response
  ///
  /// TODO: Implement via Supabase Edge Function once deployed.
  Future<String> generateChatResponse(
    String userMessage, {
    String? context,
  }) async {
    debugPrint('[AiRepository] generateChatResponse -> "$userMessage"');
    throw UnimplementedError(
      'Chat not yet migrated to Supabase Edge Functions.',
    );
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
