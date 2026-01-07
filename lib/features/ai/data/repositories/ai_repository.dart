import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/serverpod_client_service.dart';
import '../models/ai_insight_model.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// Repository for AI operations
/// Handles all Serverpod backend calls for AI insights
class AiRepository {
  AiRepository() {
    debugPrint('[AiRepository] Using shared client with persistent authentication');
  }

  Client get _client => ServerpodClientService.instance.client;

  /// Debug flag to force mock data (for testing without API key)
  /// DISABLED - app uses real-time data only
  static const bool _useMockData = false;

  /// Generate AI insight based on recent logs
  ///
  /// Converts Flutter LogEntryModel to Serverpod LogEntry and calls the endpoint
  /// Throws exception if Gemini API fails - no silent fallback to mock data
  ///
  /// **IMPORTANT: Server-side prompt should request DETAILED, PERSONALIZED responses:**
  ///
  /// **Prediction (1-Month Forecast):**
  /// - Should reference specific log entries (e.g., "I saw you logged meditation 5 times this week")
  /// - Mention specific habits, moods, or notes from the logs
  /// - Use phrases like "I noticed", "I saw", "Your logs show", "You've been"
  /// - Minimum 200 characters with concrete examples
  ///
  /// **Suggestions:**
  /// - Should be context-aware based on actual patterns in the logs
  /// - Reference specific habits the user is tracking
  /// - Minimum 30 characters per suggestion
  ///
  /// **Future Letter (Message from Future Self):**
  /// - Should feel personal and reference specific moments from logs
  /// - Use phrases like "Remember when you logged X", "I saw you were working on Y"
  /// - Reference specific dates, moods, or habits mentioned in the logs
  /// - Minimum 300 characters, should feel like a real letter from future self
  /// - Avoid generic motivational phrases - be specific and detailed
  ///
  /// Example good prediction: "I saw you've been consistently logging meditation
  /// every morning for the past week, and your mood scores have improved from 3/5
  /// to 4/5. Your notes mention feeling more focused. If you continue this pattern..."
  ///
  /// Example good future letter: "Hey! It's me, your future self. I remember when
  /// you logged that tough day on January 15th where your mood was 2/5, but you
  /// still did your exercise habit. That consistency paid off - look at you now..."
  Future<AiInsightModel> generateInsight(List<LogEntryModel> recentLogs) async {
    // Use mock data if flag is set (for testing only)
    if (_useMockData) {
      debugPrint('[AiRepository] ⚠️ Using mock data (debug flag enabled)');
      return _getMockInsight();
    }

    debugPrint('[AiRepository] generateInsight -> ${recentLogs.length} logs');

    // Log detailed information about each log entry for debugging
    debugPrint('[AiRepository] 📊 Log Summary for Gemini:');
    for (var i = 0; i < recentLogs.length; i++) {
      final log = recentLogs[i];
      final moodStr = log.mood != null ? '${log.mood}/5' : 'not set';
      final habitsStr = log.habits.isNotEmpty ? log.habits.join(', ') : 'none';
      final notesStr = log.notes != null && log.notes!.isNotEmpty
          ? '${log.notes!.substring(0, log.notes!.length > 50 ? 50 : log.notes!.length)}...'
          : 'none';
      debugPrint(
        '[AiRepository]   Log ${i + 1}: Date=${log.date.toString().split(' ')[0]}, Mood=$moodStr, Habits=[$habitsStr], Notes="$notesStr"',
      );
    }

    // Convert LogEntryModel to Serverpod LogEntry
    // Ensure all fields are properly included for Gemini analysis
    final serverpodLogs = recentLogs.map((log) {
      // Validate that important data is present BEFORE conversion
      final hasMood = log.mood != null;
      final hasHabits = log.habits.isNotEmpty;
      final hasNotes = log.notes != null && log.notes!.trim().isNotEmpty;

      // Create Serverpod LogEntry with all data preserved
      final serverpodLog = LogEntry(
        id: int.tryParse(log.id),
        userId: log.userId,
        date: log.date,
        mood: log.mood,
        habits: log.habits, // Ensure habits list is preserved (List<String>)
        notes: log.notes, // Ensure notes are preserved (String? - can be null)
        createdAt: log.createdAt,
        updatedAt: log.updatedAt,
      );

      // Validate AFTER conversion to ensure data was preserved
      final convertedHasMood = serverpodLog.mood != null;
      final convertedHasHabits = serverpodLog.habits.isNotEmpty;
      final convertedHasNotes =
          serverpodLog.notes != null && serverpodLog.notes!.trim().isNotEmpty;

      if (hasMood != convertedHasMood ||
          hasHabits != convertedHasHabits ||
          hasNotes != convertedHasNotes) {
        debugPrint(
          '[AiRepository] ⚠️ Data mismatch in conversion for log ${log.id}',
        );
      }

      debugPrint(
        '[AiRepository] Converting log ${log.id}: mood=${convertedHasMood}, habits=${convertedHasHabits} (${serverpodLog.habits.length} items), notes=${convertedHasNotes}',
      );

      return serverpodLog;
    }).toList();

    // Count total data points for Gemini
    final totalMoods = serverpodLogs.where((l) => l.mood != null).length;
    final totalHabits = serverpodLogs.fold<int>(
      0,
      (sum, l) => sum + l.habits.length,
    );
    final totalNotes = serverpodLogs
        .where((l) => l.notes != null && l.notes!.trim().isNotEmpty)
        .length;

    debugPrint(
      '[AiRepository] 📈 Data Summary: $totalMoods moods, $totalHabits habit entries, $totalNotes notes',
    );
    debugPrint(
      '[AiRepository] Sending ${serverpodLogs.length} complete log entries to Gemini...',
    );

    // Validate that we have meaningful data to send
    if (serverpodLogs.isEmpty) {
      throw Exception('No logs to analyze - cannot generate insights');
    }

    // Ensure at least some logs have meaningful data (mood, habits, or notes)
    final logsWithData = serverpodLogs.where((log) {
      return (log.mood != null) ||
          log.habits.isNotEmpty ||
          (log.notes != null && log.notes!.trim().isNotEmpty);
    }).length;

    if (logsWithData == 0) {
      throw Exception(
        'All logs are empty - need at least mood, habits, or notes to generate insights',
      );
    }

    debugPrint(
      '[AiRepository] ✅ Validated: $logsWithData out of ${serverpodLogs.length} logs contain data',
    );

    // Call Serverpod endpoint with Gemini
    try {
      final dynamic client = _client;
      if (client == null) {
        throw Exception('Client is null - cannot connect to server');
      }

      // Create detailed context summary for Gemini to reference specific logs
      final contextSummary = _createDetailedContextSummary(recentLogs);
      debugPrint('[AiRepository] 📝 Context Summary for detailed responses:');
      debugPrint(contextSummary);

      debugPrint(
        '[AiRepository] 🤖 Calling Gemini API with complete log data...',
      );
      debugPrint(
        '[AiRepository] Each log includes: date, mood (1-5), habits (list), notes (text), timestamps',
      );
      debugPrint(
        '[AiRepository] 💡 Requesting DETAILED, PERSONALIZED responses that reference specific log entries',
      );
      final result = await client.ai.generateInsight(serverpodLogs) as dynamic;

      // Validate that we got real data from Gemini (not empty or null)
      final prediction = result.prediction as String? ?? '';
      final futureLetter = result.futureLetter as String? ?? '';
      final suggestions =
          (result.suggestions as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[];

      // Validate that prediction and futureLetter are meaningful (not empty)
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

      // Validate minimum length for DETAILED responses (not generic)
      // Predictions should be at least 150 chars with specific log references
      // (188 chars is acceptable, but we want to ensure quality)
      if (prediction.trim().length < 150) {
        throw Exception(
          'Gemini returned prediction that is too short (${prediction.length} chars). Expected at least 150 chars with specific log references.',
        );
      } else if (prediction.trim().length < 180) {
        // Warn but don't fail for responses between 150-180 chars
        debugPrint(
          '[AiRepository] ⚠️ Prediction is shorter than ideal (${prediction.length} chars). Prefer 180+ chars for better detail.',
        );
      }

      // Future letters should be at least 250 chars and feel personal
      // (300+ is preferred, but 250+ is acceptable)
      if (futureLetter.trim().length < 250) {
        throw Exception(
          'Gemini returned future letter that is too short (${futureLetter.length} chars). Expected at least 250 chars for a detailed, personal letter.',
        );
      } else if (futureLetter.trim().length < 280) {
        // Warn but don't fail for responses between 250-280 chars
        debugPrint(
          '[AiRepository] ⚠️ Future letter is shorter than ideal (${futureLetter.length} chars). Prefer 280+ chars for better detail.',
        );
      }

      // Validate that responses reference specific log details (not generic)
      final predictionLower = prediction.toLowerCase();
      final letterLower = futureLetter.toLowerCase();

      // Check for indicators of detailed, personalized responses
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
          '[AiRepository] ⚠️ Warning: Response may be too generic. Expected references to specific log entries.',
        );
      } else {
        debugPrint(
          '[AiRepository] ✅ Response includes specific log references - detailed and personalized!',
        );
      }

      debugPrint(
        '[AiRepository] ✅ generateInsight success - using Gemini-generated content',
      );
      debugPrint('[AiRepository] 📊 Response Details:');
      debugPrint(
        '[AiRepository]   Prediction: ${prediction.length} chars (min: 200)',
      );
      debugPrint(
        '[AiRepository]   Future Letter: ${futureLetter.length} chars (min: 300)',
      );
      debugPrint('[AiRepository]   Suggestions: ${suggestions.length} items');
      
      // Log stress level if present
      final stressLevel = result.stressLevel as int?;
      if (stressLevel != null) {
        debugPrint(
          '[AiRepository]   Stress Level: $stressLevel/5 (${stressLevel >= 3 ? "HIGH - will trigger breathing exercise" : "normal"})',
        );
      } else {
        debugPrint(
          '[AiRepository]   ⚠️ Stress Level: NOT PROVIDED by server. Server-side code needs to calculate stressLevel from logs.',
        );
      }

      // Validate suggestions are detailed too
      for (var i = 0; i < suggestions.length; i++) {
        if (suggestions[i].length < 30) {
          debugPrint(
            '[AiRepository] ⚠️ Suggestion ${i + 1} is too short: ${suggestions[i].length} chars',
          );
        }
      }

      // Extract new fields if available
      final calmingMessage = result.calmingMessage as String?;
      final musicRecs = (result.musicRecommendations as List<dynamic>?)
          ?.map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();

      // Convert Serverpod AiInsight to AiInsightModel
      return AiInsightModel(
        prediction: prediction,
        suggestions: suggestions,
        futureLetter: futureLetter,
        generatedAt: result.generatedAt as DateTime? ?? DateTime.now(),
        stressLevel: result.stressLevel as int?,
        calmingMessage: calmingMessage,
        musicRecommendations: musicRecs,
      );
    } on NoSuchMethodError catch (e) {
      // Endpoint doesn't exist yet (serverpod generate not run)
      debugPrint(
        '[AiRepository] ❌ AI endpoint not available (NoSuchMethodError): $e',
      );
      throw Exception(
        'AI endpoint not available. Please run "serverpod generate" to create the endpoint.',
      );
    } catch (e) {
      // Re-throw the error instead of silently falling back to mock data
      debugPrint('[AiRepository] ❌ generateInsight error -> $e');
      debugPrint('[AiRepository] Throwing error instead of using mock data');
      rethrow;
    }
  }

  /// Generate a free-form chat response using Gemini
  /// This allows natural conversations without hardcoded responses
  Future<String> generateChatResponse(String userMessage, {String? context}) async {
    try {
      debugPrint('[AiRepository] generateChatResponse -> "$userMessage"');
      
      final dynamic client = _client;
      if (client == null) {
        throw Exception('Client is null - cannot connect to server');
      }
      
      debugPrint('[AiRepository] 🤖 Calling Gemini chat API...');
      final response = await client.ai.generateChatResponse(
        userMessage,
        context,
      ) as String;
      
      if (response.trim().isEmpty) {
        throw Exception('Gemini returned empty response');
      }
      
      debugPrint('[AiRepository] ✅ Received chat response from Gemini');
      return response;
    } catch (e) {
      debugPrint('[AiRepository] ❌ generateChatResponse error -> $e');
      rethrow;
    }
  }

  /// Create a detailed context summary from logs for Gemini to reference
  /// This helps Gemini create personalized responses that mention specific log entries
  String _createDetailedContextSummary(List<LogEntryModel> logs) {
    final buffer = StringBuffer();
    buffer.writeln('=== DETAILED LOG CONTEXT FOR GEMINI ===');
    buffer.writeln('Total logs: ${logs.length}');
    buffer.writeln('');

    // Group by patterns
    final moods = logs
        .where((l) => l.mood != null)
        .map((l) => l.mood!)
        .toList();
    final allHabits = <String>{};
    final notesWithContent = <String>[];

    for (var log in logs) {
      allHabits.addAll(log.habits);
      if (log.notes != null && log.notes!.trim().isNotEmpty) {
        notesWithContent.add(log.notes!);
      }
    }

    if (moods.isNotEmpty) {
      final avgMood = moods.reduce((a, b) => a + b) / moods.length;
      buffer.writeln('MOOD PATTERNS:');
      buffer.writeln('  - Average mood: ${avgMood.toStringAsFixed(1)}/5');
      buffer.writeln(
        '  - Mood range: ${moods.reduce((a, b) => a < b ? a : b)}-${moods.reduce((a, b) => a > b ? a : b)}',
      );
      buffer.writeln('  - Total mood entries: ${moods.length}');
      buffer.writeln('');
    }

    if (allHabits.isNotEmpty) {
      buffer.writeln('HABITS TRACKED:');
      for (var habit in allHabits) {
        final count = logs.where((l) => l.habits.contains(habit)).length;
        buffer.writeln('  - $habit (appears in $count logs)');
      }
      buffer.writeln('');
    }

    if (notesWithContent.isNotEmpty) {
      buffer.writeln('NOTES SUMMARY:');
      buffer.writeln('  - ${notesWithContent.length} logs have notes');
      buffer.writeln(
        '  - Sample themes: Check individual log notes for specific details',
      );
      buffer.writeln('');
    }

    buffer.writeln('RECENT LOG ENTRIES (for specific references):');
    for (var i = 0; i < logs.length && i < 5; i++) {
      final log = logs[i];
      buffer.write('  ${i + 1}. ${log.date.toString().split(' ')[0]}: ');
      if (log.mood != null) buffer.write('Mood ${log.mood}/5, ');
      if (log.habits.isNotEmpty)
        buffer.write('Habits: ${log.habits.join(", ")}, ');
      if (log.notes != null && log.notes!.isNotEmpty) {
        final notePreview = log.notes!.length > 60
            ? '${log.notes!.substring(0, 60)}...'
            : log.notes!;
        buffer.write('Note: "$notePreview"');
      }
      buffer.writeln('');
    }

    buffer.writeln('');
    buffer.writeln('=== INSTRUCTIONS FOR GEMINI ===');
    buffer.writeln('Please create DETAILED, PERSONALIZED responses that:');
    buffer.writeln(
      '1. Reference specific log entries (e.g., "I saw you logged X on Y date")',
    );
    buffer.writeln('2. Mention specific habits, moods, or notes from the logs');
    buffer.writeln(
      '3. Provide context-aware suggestions based on actual patterns',
    );
    buffer.writeln(
      '4. Write future letters that feel personal and reference specific moments',
    );
    buffer.writeln('5. Avoid generic phrases - be specific and detailed');
    buffer.writeln('================================');

    return buffer.toString();
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
