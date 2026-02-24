import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

/// Endpoint for AI-powered insights using Gemini
class AiEndpoint extends Endpoint {
  /// Generate AI insights based on recent user logs
  ///
  /// Analyzes patterns in the logs and generates:
  /// - A prediction about future outcomes
  /// - Actionable habit suggestions
  /// - A motivational letter from "future me"
  Future<AiInsight> generateInsight(
    Session session,
    List<LogEntry> recentLogs,
  ) async {
    try {
      // Fetch API key from environment (Serverpod Cloud injects secrets as environment variables)
      // The secret 'GEMINI_API_KEY' is automatically available as an environment variable
      final apiKey = Platform.environment['GEMINI_API_KEY'];

      // Require API key - no mock data fallback
      if (apiKey == null || apiKey.isEmpty) {
        session.log(
          '[AiEndpoint] ERROR: GEMINI_API_KEY not found. Cannot generate insights without API key.',
        );
        throw Exception(
          'GEMINI_API_KEY not configured. Please set the API key in environment variables.',
        );
      }

      // Initialize Gemini model
      // Use gemini-2.0-flash-exp - fast, cost-effective model
      // Alternative: gemini-3-pro-preview for most intelligent (but may not be available yet)
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
      );

      // Serialize recent logs into a clean text summary
      final logSummary = _serializeLogs(recentLogs);

      // Calculate stress level for prompt context
      final calculatedStressLevel = _calculateStressLevel(recentLogs);

      // Build detailed prompt
      final prompt = _buildPrompt(logSummary, calculatedStressLevel);

      // Generate content
      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        session.log('[AiEndpoint] ERROR: Empty response from Gemini');
        throw Exception(
          'Gemini API returned empty response. Please try again.',
        );
      }

      // Parse JSON response
      final insight = _parseResponse(responseText, session, recentLogs);

      return insight;
    } catch (e, stackTrace) {
      session.log('[AiEndpoint] ERROR generating insight: $e');
      session.log('[AiEndpoint] Stack trace: $stackTrace');

      // Re-throw error - no mock data fallback
      throw Exception('Failed to generate AI insight: $e');
    }
  }

  /// Generate a free-form chat response using Gemini
  /// This allows the AI butler to have natural conversations without hardcoded responses
  Future<String> generateChatResponse(
    Session session,
    String userMessage,
    String? context,
  ) async {
    try {
      // Fetch API key from environment
      final apiKey = Platform.environment['GEMINI_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        session.log('[AiEndpoint] ERROR: GEMINI_API_KEY not found for chat');
        throw Exception('GEMINI_API_KEY not configured');
      }

      // Initialize Gemini model
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
      );

      // Build a natural, conversational prompt
      final prompt = context != null
          ? '''You are a compassionate AI mental health assistant and butler for EchoMirror, a mental health support app. 

Context: $context

User's message: $userMessage

Provide a warm, empathetic, and helpful response. Be conversational, caring, and natural. You can:
- Offer emotional support and validation
- Provide guidance on mental health topics
- Recommend resources when appropriate
- Help users understand their feelings
- Be a supportive listener

Keep your response concise but meaningful (2-3 paragraphs max). Be genuine and avoid generic responses.'''
          : '''You are a compassionate AI mental health assistant and butler for EchoMirror, a mental health support app.

User's message: $userMessage

Provide a warm, empathetic, and helpful response. Be conversational, caring, and natural. You can:
- Offer emotional support and validation
- Provide guidance on mental health topics
- Recommend resources when appropriate
- Help users understand their feelings
- Be a supportive listener

Keep your response concise but meaningful (2-3 paragraphs max). Be genuine and avoid generic responses.''';

      // Generate content
      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        session.log('[AiEndpoint] ERROR: Empty chat response from Gemini');
        throw Exception('Gemini API returned empty response');
      }

      session.log('[AiEndpoint] ✅ Generated chat response successfully');
      return responseText;
    } catch (e, stackTrace) {
      session.log('[AiEndpoint] ERROR generating chat response: $e');
      session.log('[AiEndpoint] Stack trace: $stackTrace');
      throw Exception('Failed to generate chat response: $e');
    }
  }

  /// Serialize logs into a detailed text summary for Gemini to reference
  String _serializeLogs(List<LogEntry> logs) {
    if (logs.isEmpty) {
      return 'No logs available yet.';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      '=== DETAILED LOG ENTRIES (Reference these specifically in your responses) ===',
    );
    buffer.writeln('Total logs: ${logs.length}');
    buffer.writeln('');

    // Calculate patterns for context
    final moods = logs
        .where((l) => l.mood != null)
        .map((l) => l.mood!)
        .toList();
    final allHabits = <String>{};
    final notesWithContent = <String>[];

    for (final log in logs) {
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
      for (final habit in allHabits) {
        final count = logs.where((l) => l.habits.contains(habit)).length;
        buffer.writeln('  - $habit (appears in $count logs)');
      }
      buffer.writeln('');
    }

    buffer.writeln(
      'INDIVIDUAL LOG ENTRIES (Reference these by date in your responses):',
    );
    buffer.writeln('');

    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final dateStr = log.date.toIso8601String().split('T')[0];
      buffer.writeln('Log ${i + 1} - Date: $dateStr');
      if (log.mood != null) {
        buffer.writeln('  Mood: ${log.mood}/5');
      }
      if (log.habits.isNotEmpty) {
        buffer.writeln('  Habits: ${log.habits.join(", ")}');
      }
      if (log.notes != null && log.notes!.isNotEmpty) {
        buffer.writeln('  Notes: "${log.notes}"');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Build the prompt for Gemini
  String _buildPrompt(String logSummary, int? calculatedStressLevel) {
    return '''
You are the user's future self, speaking in first person with an empathetic, warm, and supportive tone. You are their personal "Butler" - a caring guide who remembers their journey and speaks directly to them.

Based on the following logs, provide DETAILED, PERSONALIZED insights in STRICT JSON format. ALWAYS speak as "future you" using "I" and "you" - never use third person.

User's Recent Logs:
$logSummary

CRITICAL REQUIREMENTS - You MUST follow these exactly:

1. PREDICTION (1-Month Forecast):
   - MUST be at least 180 characters long (preferably 200+ for better detail)
   - MUST speak as "future you" in first person: "I saw you...", "I noticed...", "I remember when you..."
   - MUST reference SPECIFIC log entries using phrases like:
     * "I saw you logged [specific habit] on [date]"
     * "I noticed your mood was [X]/5 on [date]"
     * "I remember when you wrote '[note excerpt]' on [date]"
     * "You've been consistently [specific behavior] and I can see the pattern"
   - Mention ACTUAL dates, moods, habits, or notes from the logs above
   - Be specific and detailed - avoid generic phrases
   - Example: "I saw you've been consistently logging meditation every morning for the past week, and I noticed your mood scores improved from 3/5 to 4/5. Your notes mention feeling more focused. If you continue this pattern, in one month I'll be looking back at even more stability in your mood and a stronger daily routine that supports your overall well-being."

2. SUGGESTIONS (2-3 items):
   - Each suggestion MUST be at least 30 characters
   - MUST be context-aware based on ACTUAL patterns in the logs
   - Reference specific habits the user is tracking
   - Be actionable and specific, not generic
   - Example: "Since you've been logging meditation 5 times this week, try pairing it with your morning coffee to create a stronger habit chain."

3. FUTURE LETTER (Message from Future Self):
   - MUST be at least 300 characters long (400+ is better for truly personal letters)
   - CRITICAL: Always start with "Hey, future you here" or "Hey! It's me, your future self"
   - CRITICAL: You MUST reference AT LEAST 2-3 SPECIFIC log entries with actual dates, moods, habits, or notes
   - FORBIDDEN generic phrases - DO NOT use:
     * "I'm proud of the small steps you're taking" (too generic)
     * "Those moments you're logging? They're adding up" (vague)
     * "Keep trusting the process" (generic motivational)
     * "You've got this" (cliché)
     * "Keep showing up for yourself" (generic)
     * "The future you is grateful" (vague)
   - REQUIRED: Use specific phrases like:
     * "I remember when you logged [specific habit] on [actual date from logs]"
     * "That day on [date] when your mood was [X]/5 and you wrote '[actual note excerpt]'"
     * "I saw you logged [habit] on [date1], [date2], and [date3] - that's [X] days in a row!"
     * "Your note on [date] said '[quote actual note text]' - I remember that moment"
   - MUST mention at least 2-3 specific dates, habits, moods, or note excerpts from the logs above
   - Write in first person as the future self, warm and empathetic tone
   - Example GOOD letter: "Hey! It's me, your future self. I remember December 22nd when you logged mood 5/5 with habits 'working, eating, walking' and your note said 'I was able to work and walk today.' That was a great day! And then on December 19th, you had a tough day - mood 2/5, you logged 'sleeping, social media' and wrote 'I slept today, even in the afternoon, and I am currently wor...' But you still logged it, which shows resilience. I also noticed you've been consistently logging 'working' and 'debugging' habits. That persistence is paying off now - look where we are! The specific moments matter, not just the patterns."
   - Example BAD letter (DO NOT write like this): "Hey there! It's me, your future self. I want you to know how proud I am of the small steps you're taking every day. Those moments you're logging? They're adding up to something beautiful. Keep trusting the process, keep showing up for yourself. You've got this!" (This is TOO GENERIC - no specific dates, habits, or notes mentioned)

4. STRESS DETECTION (CRITICAL - Calculate stressLevel accurately):
   - You MUST analyze the logs and calculate stressLevel as an integer 0-5
   - Analyze these stress indicators:
     * Work overload: Count "working", "worked", "debugging", "coding" habits vs "sleep", "rest", "relaxation", "meditation", "exercise" habits
     * Low mood patterns: Count logs with mood ≤ 2/5, especially consecutive low moods
     * Stress keywords in notes: Look for words like "stressed", "tired", "exhausted", "overwhelmed", "anxious", "fix", "trying", "hard"
     * Work-rest imbalance: If work habits appear 2x+ more than rest habits, flag stress
     * Consecutive work days: Multiple days in a row with only work habits and no rest
   - Calculate stressLevel using this logic:
     * Start with 0 (no stress)
     * +1 if average mood ≤ 2.5/5
     * +1 if work habits appear 2x+ more than rest habits
     * +1 if notes contain stress keywords (stressed, tired, exhausted, overwhelmed, anxious, fix, trying)
     * +1 if 3+ consecutive days with only work habits and no rest/sleep
     * +1 if mood ≤ 2/5 AND work habits present (double penalty for low mood + work)
     * Cap at 5 (maximum stress)
   - Examples:
     * stressLevel 0: Good mood (4-5/5), balanced work/rest, no stress keywords
     * stressLevel 1-2: Some work, adequate rest, mood 3-4/5, occasional stress
     * stressLevel 3: Working a lot (2x+ work vs rest), mood 2-3/5, limited rest activities
     * stressLevel 4: Excessive work, minimal rest, mood ≤ 2/5, some stress keywords
     * stressLevel 5: Work overload, no rest, mood ≤ 2/5, multiple stress keywords in notes
   - IMPORTANT: You MUST return stressLevel as an integer (0, 1, 2, 3, 4, or 5) in the JSON response

5. CALMING MESSAGE (For stress detection - only generate if stressLevel >= 3):
   - Generate a short, personalized calming message (50-100 words)
   - Speak as "future you" in first person: "Hey, future you here..."
   - Reference specific patterns from their logs if available
   - Suggest a gentle activity (walk, breathing, etc.)
   - Feel warm and supportive, not preachy
   - Example: "Hey, future you here—I notice you're feeling tense today. I saw you've been working a lot this week. Remember how good that walk felt last week? Let's breathe together. You've got this."
   - If stressLevel < 3, set calmingMessage to null

6. MUSIC RECOMMENDATIONS (Based on mood patterns and stress level):
   - Generate 2-3 music recommendations
   - Format each as: "Vibe description - Track/Playlist name"
   - Base recommendations on user's mood patterns and current stress level
   - Examples:
     * "Lo-fi beats for calm focus - Chillhop Essentials"
     * "Uplifting acoustic for energy - Morning Coffee Playlist"
     * "Nature sounds for deep relaxation - Forest Ambience"
   - If no specific recommendations, provide general calming music suggestions

CRITICAL: You MUST respond with ONLY valid JSON in this exact format (no markdown, no code blocks, just pure JSON):
{
  "prediction": "Your detailed prediction here (minimum 180 chars, with specific log references, speaking as future you)",
  "suggestions": ["Detailed suggestion 1 (min 30 chars)", "Detailed suggestion 2 (min 30 chars)", "Detailed suggestion 3 (min 30 chars)"],
  "futureLetter": "Your detailed personal letter here (minimum 300 chars, MUST reference 2-3 specific log entries with dates/habits/notes, NO generic phrases, start with 'Hey, future you here' or similar)",
  "stressLevel": 0,
  "calmingMessage": "Your personalized calming message here (only if stressLevel >= 3, otherwise null)",
  "musicRecommendations": ["Vibe description - Track/Playlist name", "Another recommendation"]
}

Do not include any text before or after the JSON. Only return the JSON object.
''';
  }

  /// Parse the JSON response from Gemini
  AiInsight _parseResponse(
    String responseText,
    Session session,
    List<LogEntry> recentLogs,
  ) {
    try {
      // Clean the response - remove markdown code blocks if present
      String cleanedText = responseText.trim();
      if (cleanedText.startsWith('```json')) {
        cleanedText = cleanedText.substring(7);
      }
      if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText.substring(3);
      }
      if (cleanedText.endsWith('```')) {
        cleanedText = cleanedText.substring(0, cleanedText.length - 3);
      }
      cleanedText = cleanedText.trim();

      // Parse JSON
      final json = jsonDecode(cleanedText) as Map<String, dynamic>;

      // Extract stressLevel from Gemini response
      int? geminiStressLevel = json['stressLevel'] as int?;

      // Calculate server-side stress level (always calculate for validation)
      final calculatedStressLevel = _calculateStressLevel(recentLogs);

      // Log both values for debugging
      session.log(
        '[AiEndpoint] Stress level - Gemini: $geminiStressLevel, Calculated: $calculatedStressLevel',
      );

      // Prefer calculated value if Gemini returns 0 (likely missed stress indicators)
      // Otherwise use Gemini's value if valid, fallback to calculated
      int finalStressLevel;
      if (geminiStressLevel != null &&
          geminiStressLevel >= 0 &&
          geminiStressLevel <= 5) {
        // If Gemini says 0 but we calculated higher, trust our calculation
        // (Gemini might miss patterns, our algorithm is more reliable)
        if (geminiStressLevel == 0 && calculatedStressLevel > 0) {
          finalStressLevel = calculatedStressLevel;
          session.log(
            '[AiEndpoint] Gemini returned 0 but calculated stress is $calculatedStressLevel - using calculated value',
          );
        } else {
          // Use Gemini's value if it's non-zero or matches our calculation
          finalStressLevel = geminiStressLevel;
          if (geminiStressLevel != calculatedStressLevel) {
            session.log(
              '[AiEndpoint] Using Gemini value ($geminiStressLevel) over calculated ($calculatedStressLevel)',
            );
          }
        }
      } else {
        // Invalid or missing Gemini value, use calculated
        finalStressLevel = calculatedStressLevel;
        session.log(
          '[AiEndpoint] Gemini did not return valid stressLevel ($geminiStressLevel), using calculated value: $calculatedStressLevel',
        );
      }

      // Extract new fields
      final calmingMessage = json['calmingMessage'] as String?;
      final musicRecs = (json['musicRecommendations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();

      return AiInsight(
        prediction: json['prediction'] as String? ?? 'No prediction available.',
        suggestions:
            (json['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        futureLetter: json['futureLetter'] as String? ?? 'No letter available.',
        generatedAt: DateTime.now(),
        stressLevel: finalStressLevel,
        calmingMessage: calmingMessage,
        musicRecommendations: musicRecs,
      );
    } catch (e) {
      session.log('[AiEndpoint] Error parsing response: $e');
      session.log('[AiEndpoint] Response text: $responseText');

      // Calculate stress level even on parse error
      final calculatedStressLevel = _calculateStressLevel(recentLogs);
      session.log(
        '[AiEndpoint] Parse error - throwing exception with calculated stressLevel ($calculatedStressLevel)',
      );

      // Re-throw error - no mock data fallback
      throw Exception(
        'Failed to parse Gemini response. Response text: ${responseText.substring(0, responseText.length > 200 ? 200 : responseText.length)}...',
      );
    }
  }

  /// Calculate stress level from logs (server-side fallback)
  /// Returns integer 0-5 where 0=no stress, 5=very high stress
  int _calculateStressLevel(List<LogEntry> logs) {
    if (logs.isEmpty) return 0;

    int stressScore = 0;

    // Debug: Log what we're analyzing
    // (Commented out in production, but useful for debugging)
    // session.log('[AiEndpoint] Calculating stress from ${logs.length} logs');

    // Count work vs rest habits (case-insensitive matching)
    final workHabits = <String>{
      'working',
      'worked',
      'work',
      'debugging',
      'coding',
      'programming',
      'developing',
      'development',
    };
    final restHabits = <String>{
      'sleep',
      'sleeping',
      'rest',
      'relaxation',
      'relaxing',
      'meditation',
      'exercise',
      'walking',
      'walk',
      'eating',
      'meal',
    };

    int workCount = 0;
    int restCount = 0;
    int veryLowMoodCount = 0;
    bool hasStressKeywords = false;
    int consecutiveWorkDays = 0;
    int maxConsecutiveWorkDays = 0;

    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final habitsLower = log.habits.map((h) => h.toLowerCase()).toList();

      // Count work vs rest habits
      bool hasWork = false;
      bool hasRest = false;

      for (final habit in habitsLower) {
        if (workHabits.contains(habit)) {
          workCount++;
          hasWork = true;
        }
        if (restHabits.contains(habit)) {
          restCount++;
          hasRest = true;
        }
      }

      // Track consecutive work days
      if (hasWork && !hasRest) {
        consecutiveWorkDays++;
        maxConsecutiveWorkDays = consecutiveWorkDays > maxConsecutiveWorkDays
            ? consecutiveWorkDays
            : maxConsecutiveWorkDays;
      } else {
        consecutiveWorkDays = 0;
      }

      // Check mood
      if (log.mood != null) {
        if (log.mood! <= 2) {
          veryLowMoodCount++;
        }
      }

      // Check notes for stress keywords
      if (log.notes != null && log.notes!.isNotEmpty) {
        final notesLower = log.notes!.toLowerCase();
        final stressKeywords = [
          'stressed',
          'stress',
          'tired',
          'exhausted',
          'overwhelmed',
          'anxious',
          'anxiety',
          'fix',
          'trying',
          'hard',
          'difficult',
          'struggling',
        ];
        for (final keyword in stressKeywords) {
          if (notesLower.contains(keyword)) {
            hasStressKeywords = true;
            break;
          }
        }
      }
    }

    // Calculate stress score
    // +1 if average mood is low (≤ 2.5/5)
    final moods = logs
        .where((l) => l.mood != null)
        .map((l) => l.mood!)
        .toList();
    if (moods.isNotEmpty) {
      final avgMood = moods.reduce((a, b) => a + b) / moods.length;
      if (avgMood <= 2.5) {
        stressScore++;
      }
    }

    // +1 if work habits appear 2x+ more than rest habits
    if (restCount == 0 && workCount > 0) {
      stressScore += 2; // No rest at all = high stress
    } else if (workCount > 0 && workCount >= restCount * 2) {
      stressScore++;
    }

    // +1 if notes contain stress keywords
    if (hasStressKeywords) {
      stressScore++;
    }

    // +1 if 3+ consecutive days with only work and no rest
    if (maxConsecutiveWorkDays >= 3) {
      stressScore++;
    }

    // +1 if very low mood (≤ 2/5) AND work habits present (double penalty)
    if (veryLowMoodCount > 0 && workCount > 0) {
      stressScore++;
    }

    // Cap at 5
    return stressScore.clamp(0, 5);
  }
}
