import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/ai_insight_model.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// Repository for AI operations
/// Handles all Serverpod backend calls for AI insights
class AiRepository {
  AiRepository() {
    debugPrint('[AiRepository] Initialized client -> ${ApiConstants.serverUrl}');
  }

  final Client _client = Client(ApiConstants.serverUrl);

  /// Debug flag to force mock data (for testing without API key)
  static const bool _useMockData = false;

  /// Generate AI insight based on recent logs
  /// 
  /// Converts Flutter LogEntryModel to Serverpod LogEntry and calls the endpoint
  Future<AiInsightModel> generateInsight(List<LogEntryModel> recentLogs) async {
    try {
      // Use mock data if flag is set
      if (_useMockData) {
        debugPrint('[AiRepository] Using mock data (debug flag enabled)');
        return _getMockInsight();
      }

      debugPrint('[AiRepository] generateInsight -> ${recentLogs.length} logs');

      // Convert LogEntryModel to Serverpod LogEntry
      final serverpodLogs = recentLogs.map((log) {
        return LogEntry(
          id: int.tryParse(log.id),
          userId: log.userId,
          date: log.date,
          mood: log.mood,
          habits: log.habits,
          notes: log.notes,
          createdAt: log.createdAt,
          updatedAt: log.updatedAt,
        );
      }).toList();

      // Call Serverpod endpoint
      // Note: This will be available after running 'serverpod generate'
      // The endpoint is defined in lib/src/endpoints/ai_endpoint.dart
      final result = await _client.ai.generateInsight(serverpodLogs);

      debugPrint('[AiRepository] generateInsight success');

      // Convert Serverpod AiInsight to AiInsightModel
      return AiInsightModel(
        prediction: result.prediction,
        suggestions: result.suggestions,
        futureLetter: result.futureLetter,
        generatedAt: result.generatedAt,
      );
    } catch (e, stackTrace) {
      debugPrint('[AiRepository] generateInsight error -> $e');
      debugPrint('[AiRepository] generateInsight stackTrace -> $stackTrace');
      
      // Return mock data on error so app doesn't break
      return _getMockInsight();
    }
  }

  /// Get mock insight for testing/offline mode
  AiInsightModel _getMockInsight() {
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

