import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/insight_model.dart';
import '../../../logging/data/repositories/logging_repository.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// Repository for dashboard operations.
class DashboardRepository {
  DashboardRepository(
    this._loggingRepository, {
    SupabaseClient? supabaseClient,
    DateTime Function()? now,
  })  : _supabase = supabaseClient,
        _now = now ?? DateTime.now;

  final LoggingRepository _loggingRepository;
  final SupabaseClient? _supabase;
  final DateTime Function() _now;

  SupabaseClient get _client => _supabase ?? Supabase.instance.client;

  Future<List<InsightModel>> getInsights(String userId) async {
    try {
      final logEntries = await _loggingRepository.getLogEntries(userId);
      if (logEntries.isEmpty) return [];

      final insights = <InsightModel>[];
      final now = _now();

      final echoInsight = await _buildEchoRewardInsight(userId, logEntries, now);
      if (echoInsight != null) insights.add(echoInsight);

      final moodEntries = logEntries.where((e) => e.mood != null).toList();
      if (moodEntries.isNotEmpty) {
        final averageMood =
            moodEntries.map((e) => e.mood!).reduce((a, b) => a + b) /
                moodEntries.length;

        final localNow = now.isUtc ? now.toLocal() : now;
        final weekAgo = localNow.subtract(const Duration(days: 7));
        final recentMoods = moodEntries.where((e) {
          final localDate = e.date.isUtc ? e.date.toLocal() : e.date;
          return localDate.isAfter(weekAgo);
        }).toList();

        if (recentMoods.length >= 3) {
          final recentAvg =
              recentMoods.map((e) => e.mood!).reduce((a, b) => a + b) /
                  recentMoods.length;
          if (recentAvg > averageMood + 0.5) {
            insights.add(InsightModel(
              id: 'mood-improving-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Mood Improvement Detected',
              description:
                  'Your mood has been improving over the past week! '
                  'Keep up the great work.',
              date: now,
              type: InsightType.mood,
              createdAt: now,
            ));
          } else if (recentAvg < averageMood - 0.5) {
            insights.add(InsightModel(
              id: 'mood-declining-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Mood Trend Notice',
              description:
                  'Your mood has been lower recently. '
                  'Consider taking some time for self-care.',
              date: now,
              type: InsightType.mood,
              createdAt: now,
            ));
          }
        }

        final bestMoodEntry = moodEntries
            .reduce((a, b) => (a.mood ?? 0) > (b.mood ?? 0) ? a : b);
        if (bestMoodEntry.mood != null && bestMoodEntry.mood! >= 4) {
          final localDate = bestMoodEntry.date.isUtc
              ? bestMoodEntry.date.toLocal()
              : bestMoodEntry.date;
          insights.add(InsightModel(
            id: 'best-mood-${bestMoodEntry.id}',
            userId: userId,
            title: 'Great Mood Day',
            description:
                'You had an excellent mood on ${_formatDate(localDate)}. '
                'What made that day special?',
            date: localDate,
            type: InsightType.mood,
            createdAt: now,
          ));
        }
      }

      final habitFrequency = <String, int>{};
      for (final entry in logEntries) {
        for (final habit in entry.habits) {
          habitFrequency[habit] = (habitFrequency[habit] ?? 0) + 1;
        }
      }

      if (habitFrequency.isNotEmpty) {
        final sortedHabits = habitFrequency.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final topHabit = sortedHabits.first;
        if (topHabit.value >= 5) {
          insights.add(InsightModel(
            id: 'top-habit-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'Consistent Habit',
            description:
                'You have logged "${topHabit.key}" ${topHabit.value} times. '
                'Consistency is key!',
            date: now,
            type: InsightType.habit,
            createdAt: now,
          ));
        }

        final localNow = now.isUtc ? now.toLocal() : now;
        final recentEntries = logEntries.where((e) {
          final localDate = e.date.isUtc ? e.date.toLocal() : e.date;
          return localDate
              .isAfter(localNow.subtract(const Duration(days: 7)));
        }).toList();

        final recentHabits = <String>{};
        for (final entry in recentEntries) {
          recentHabits.addAll(entry.habits);
        }

        if (recentHabits.length >= 3) {
          insights.add(InsightModel(
            id: 'habit-variety-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'Habit Variety',
            description:
                "You've been practicing ${recentHabits.length} different "
                'habits this week. Great diversity!',
            date: now,
            type: InsightType.habit,
            createdAt: now,
          ));
        }
      }

      final totalEntries = logEntries.length;
      if (totalEntries >= 7) {
        insights.add(InsightModel(
          id: 'milestone-${now.millisecondsSinceEpoch}',
          userId: userId,
          title: 'Logging Milestone',
          description:
              'You have logged $totalEntries entries! '
              'Your consistency is building valuable insights.',
          date: now,
          type: InsightType.general,
          createdAt: now,
        ));
      }

      insights.sort((a, b) => b.date.compareTo(a.date));
      return insights;
    } catch (e) {
      throw Exception('Failed to get insights: $e');
    }
  }

  Future<List<InsightModel>> getPredictions(String userId) async {
    try {
      final logEntries = await _loggingRepository.getLogEntries(userId);
      if (logEntries.isEmpty) return [];

      final response = await _client.functions.invoke(
        'generate-insight',
        body: {
          'recentLogs': logEntries.map((e) => e.toJson()).toList(),
        },
      );

      if (response.status != null && response.status! >= 400) {
        final data = response.data;
        if (data is Map &&
            data['error']?.toString().contains('Rate limit') == true) {
          debugPrint(
            '[DashboardRepository] Rate limit exceeded for generate-insight',
          );
          return [];
        }
      }

      final result = response.data;
      if (result is! Map<String, dynamic>) {
        debugPrint(
          '[DashboardRepository] getPredictions: unexpected response type',
        );
        return [];
      }

      final now = _now();
      final insights = <InsightModel>[];

      final prediction = (result['prediction'] as String? ?? '').trim();
      if (prediction.isNotEmpty) {
        insights.add(InsightModel(
          id: 'prediction-${now.millisecondsSinceEpoch}',
          userId: userId,
          title: 'AI Prediction',
          description: prediction,
          date: now,
          type: InsightType.prediction,
          createdAt: now,
        ));
      }

      final suggestions = result['suggestions'];
      if (suggestions is List) {
        for (var i = 0; i < suggestions.length; i++) {
          final text = suggestions[i]?.toString().trim() ?? '';
          if (text.isEmpty) continue;
          insights.add(InsightModel(
            id: 'suggestion-$i-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'Suggestion',
            description: text,
            date: now,
            type: InsightType.general,
            createdAt: now,
          ));
        }
      }

      final futureLetter = (result['futureLetter'] as String? ?? '').trim();
      if (futureLetter.isNotEmpty) {
        insights.add(InsightModel(
          id: 'future-letter-ai-${now.millisecondsSinceEpoch}',
          userId: userId,
          title: 'A Letter to Your Future Self',
          description: futureLetter,
          date: now,
          type: InsightType.general,
          createdAt: now,
        ));
      }

      final calmingMessage =
          (result['calmingMessage'] as String? ?? '').trim();
      if (calmingMessage.isNotEmpty) {
        insights.add(InsightModel(
          id: 'calming-${now.millisecondsSinceEpoch}',
          userId: userId,
          title: 'Calming Thought',
          description: calmingMessage,
          date: now,
          type: InsightType.mood,
          createdAt: now,
        ));
      }

      final music = result['musicRecommendations'];
      if (music is List && music.isNotEmpty) {
        final tracks = music
            .map((m) => m?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (tracks.isNotEmpty) {
          insights.add(InsightModel(
            id: 'music-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'Music for Your Mood',
            description: tracks.join('\n'),
            date: now,
            type: InsightType.general,
            createdAt: now,
          ));
        }
      }

      return insights;
    } catch (e) {
      debugPrint('[DashboardRepository] getPredictions error -> $e');
      return [];
    }
  }

  Future<List<InsightModel>> getFutureLetters(String userId) async {
    try {
      final response = await _client
          .from('future_letters')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(_mapFutureLetterToInsight)
          .toList();
    } catch (e) {
      debugPrint('[DashboardRepository] getFutureLetters error -> $e');
      return [];
    }
  }

  InsightModel _mapFutureLetterToInsight(Map<String, dynamic> row) {
    final createdAt = _parseDateTime(
      row['created_at'] ??
          row['createdAt'] ??
          row['delivery_date'] ??
          row['date'],
    );
    final date = _parseDateTime(
      row['delivery_date'] ??
          row['open_at'] ??
          row['date'] ??
          row['created_at'],
    );
    return InsightModel(
      id: row['id'].toString(),
      userId: (row['user_id'] ?? row['userId'] ?? '').toString(),
      title: (row['title'] ?? 'Future Letter').toString(),
      description: (row['content'] ??
              row['letter'] ??
              row['future_letter'] ??
              row['futureLetter'] ??
              row['description'] ??
              '')
          .toString(),
      date: date,
      type: InsightType.general,
      createdAt: createdAt,
    );
  }

  Future<InsightModel?> _buildEchoRewardInsight(
    String userId,
    List<LogEntryModel> logEntries,
    DateTime now,
  ) async {
    final localNow = now.isUtc ? now.toLocal() : now;
    final weekAgo = localNow.subtract(const Duration(days: 7));
    final recentLogDays = logEntries
        .map((entry) => entry.date.isUtc ? entry.date.toLocal() : entry.date)
        .where((date) => date.isAfter(weekAgo))
        .map(_dateKey)
        .toSet();

    if (recentLogDays.length < 3) return null;

    try {
      final rewardRows = await _client
          .from('echo_rewards')
          .select('reason, amount, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);

      if (rewardRows is! List) return null;

      final rewardsByDay = <String, double>{};
      var totalRecentEcho = 0.0;
      for (final row in rewardRows.whereType<Map>()) {
        final createdAt = _parseDateTime(row['created_at']);
        final localCreatedAt = createdAt.isUtc ? createdAt.toLocal() : createdAt;
        if (localCreatedAt.isBefore(weekAgo)) continue;

        final amount = double.tryParse(row['amount']?.toString() ?? '') ?? 0.0;
        if (amount <= 0) continue;

        totalRecentEcho += amount;
        final key = _dateKey(localCreatedAt);
        rewardsByDay[key] = (rewardsByDay[key] ?? 0) + amount;
      }

      if (rewardsByDay.length < 3 || totalRecentEcho <= 0) return null;

      final averagePerRewardDay = totalRecentEcho / rewardsByDay.length;
      final projectedWeeklyEcho = averagePerRewardDay * recentLogDays.length;
      final currentStreak = _currentLoggingStreak(logEntries, localNow);
      final streakCopy = currentStreak >= 3
          ? ' Your $currentStreak-day logging streak is helping keep that earning pace steady.'
          : '';

      return InsightModel(
        id: 'echo-earning-${now.millisecondsSinceEpoch}',
        userId: userId,
        title: 'ECHO Earning Trend',
        description:
            'Based on your recent reward history, you are on track to earn about '
            '${projectedWeeklyEcho.toStringAsFixed(1)} ECHO this week if your logging pace stays the same.$streakCopy',
        date: now,
        type: InsightType.general,
        createdAt: now,
      );
    } catch (e) {
      debugPrint('[DashboardRepository] ECHO reward insight error -> $e');
      return null;
    }
  }

  int _currentLoggingStreak(List<LogEntryModel> logEntries, DateTime localNow) {
    final loggedDays = logEntries
        .map((entry) => entry.date.isUtc ? entry.date.toLocal() : entry.date)
        .map(_dateKey)
        .toSet();
    var streak = 0;
    var day = DateTime(localNow.year, localNow.month, localNow.day);

    while (loggedDays.contains(_dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _dateKey(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    return '${local.year}-${local.month}-${local.day}';
  }
  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return _now();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
