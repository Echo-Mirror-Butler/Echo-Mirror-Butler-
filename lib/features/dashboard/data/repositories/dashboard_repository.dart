import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/insight_model.dart';
import '../../../ai/data/services/privacy_insight_pipeline.dart';
import '../../../logging/data/models/log_entry_model.dart';
import '../../../logging/data/repositories/logging_repository.dart';

/// Repository for dashboard operations.
class DashboardRepository {
  DashboardRepository(
    this._loggingRepository, {
    SupabaseClient? supabaseClient,
    DateTime Function()? now,
  }) : _supabase = supabaseClient,
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
            insights.add(
              InsightModel(
                id: 'mood-improving-${now.millisecondsSinceEpoch}',
                userId: userId,
                title: 'Mood Improvement Detected',
                description:
                    'Your mood has been improving over the past week! '
                    'Keep up the great work.',
                date: now,
                type: InsightType.mood,
                createdAt: now,
              ),
            );
          } else if (recentAvg < averageMood - 0.5) {
            insights.add(
              InsightModel(
                id: 'mood-declining-${now.millisecondsSinceEpoch}',
                userId: userId,
                title: 'Mood Trend Notice',
                description:
                    'Your mood has been lower recently. '
                    'Consider taking some time for self-care.',
                date: now,
                type: InsightType.mood,
                createdAt: now,
              ),
            );
          }
        }

        final bestMoodEntry = moodEntries.reduce(
          (a, b) => (a.mood ?? 0) > (b.mood ?? 0) ? a : b,
        );
        if (bestMoodEntry.mood != null && bestMoodEntry.mood! >= 4) {
          final localDate = bestMoodEntry.date.isUtc
              ? bestMoodEntry.date.toLocal()
              : bestMoodEntry.date;
          insights.add(
            InsightModel(
              id: 'best-mood-${bestMoodEntry.id}',
              userId: userId,
              title: 'Great Mood Day',
              description:
                  'You had an excellent mood on ${_formatDate(localDate)}. '
                  'What made that day special?',
              date: localDate,
              type: InsightType.mood,
              createdAt: now,
            ),
          );
        }

        final weekdayPattern = _detectWeekdayMoodPattern(moodEntries);
        if (weekdayPattern != null) {
          final weekday = _weekdayName(weekdayPattern.weekday);
          insights.add(
            InsightModel(
              id: 'mood-pattern-${weekdayPattern.weekday}-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Pattern Detected',
              description:
                  'Your mood tends to be highest on ${weekday}s '
                  '(average ${weekdayPattern.average.toStringAsFixed(1)} across '
                  '${weekdayPattern.sampleCount} entries), '
                  '${weekdayPattern.gap.toStringAsFixed(1)} points above your '
                  'other logged days.',
              date: now,
              type: InsightType.prediction,
              createdAt: now,
            ),
          );
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
          insights.add(
            InsightModel(
              id: 'top-habit-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Consistent Habit',
              description:
                  'You have logged "${topHabit.key}" ${topHabit.value} times. '
                  'Consistency is key!',
              date: now,
              type: InsightType.habit,
              createdAt: now,
            ),
          );
        }

        final localNow = now.isUtc ? now.toLocal() : now;
        final recentEntries = logEntries.where((e) {
          final localDate = e.date.isUtc ? e.date.toLocal() : e.date;
          return localDate.isAfter(localNow.subtract(const Duration(days: 7)));
        }).toList();

        final recentHabits = <String>{};
        for (final entry in recentEntries) {
          recentHabits.addAll(entry.habits);
        }

        if (recentHabits.length >= 3) {
          insights.add(
            InsightModel(
              id: 'habit-variety-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Habit Variety',
              description:
                  "You've been practicing ${recentHabits.length} different "
                  'habits this week. Great diversity!',
              date: now,
              type: InsightType.habit,
              createdAt: now,
            ),
          );
        }
      }

      final totalEntries = logEntries.length;
      if (totalEntries >= 7) {
        insights.add(
          InsightModel(
            id: 'milestone-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'Logging Milestone',
            description:
                'You have logged $totalEntries entries! '
                'Your consistency is building valuable insights.',
            date: now,
            type: InsightType.general,
            createdAt: now,
          ),
        );
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

      final pipeline = PrivacyInsightPipeline();
      final privacyPayload = pipeline.buildPrivacyPayload(logEntries);

      final response = await _client.functions.invoke(
        'generate-insight',
        body: privacyPayload.toJson(),
      );

      if (response.status >= 400) {
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
        insights.add(
          InsightModel(
            id: 'prediction-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'AI Prediction',
            description: prediction,
            date: now,
            type: InsightType.prediction,
            createdAt: now,
          ),
        );
      }

      final suggestions = result['suggestions'];
      if (suggestions is List) {
        for (var i = 0; i < suggestions.length; i++) {
          final text = suggestions[i]?.toString().trim() ?? '';
          if (text.isEmpty) continue;
          insights.add(
            InsightModel(
              id: 'suggestion-$i-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Suggestion',
              description: text,
              date: now,
              type: InsightType.general,
              createdAt: now,
            ),
          );
        }
      }

      final futureLetter = (result['futureLetter'] as String? ?? '').trim();
      if (futureLetter.isNotEmpty) {
        insights.add(
          InsightModel(
            id: 'future-letter-ai-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'A Letter to Your Future Self',
            description: futureLetter,
            date: now,
            type: InsightType.general,
            createdAt: now,
          ),
        );
      }

      final calmingMessage = (result['calmingMessage'] as String? ?? '').trim();
      if (calmingMessage.isNotEmpty) {
        insights.add(
          InsightModel(
            id: 'calming-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'Calming Thought',
            description: calmingMessage,
            date: now,
            type: InsightType.mood,
            createdAt: now,
          ),
        );
      }

      final music = result['musicRecommendations'];
      if (music is List && music.isNotEmpty) {
        final tracks = music
            .map((m) => m?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (tracks.isNotEmpty) {
          insights.add(
            InsightModel(
              id: 'music-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Music for Your Mood',
              description: tracks.join('\n'),
              date: now,
              type: InsightType.general,
              createdAt: now,
            ),
          );
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
      description:
          (row['content'] ??
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

  _WeekdayMoodPattern? _detectWeekdayMoodPattern(
    List<LogEntryModel> moodEntries,
  ) {
    // A prediction needs repeated evidence for one weekday and enough
    // comparison data to avoid treating a single unusually good day as a
    // recurring pattern.
    if (moodEntries.length < 5) return null;

    final moodsByWeekday = <int, List<int>>{};
    for (final entry in moodEntries) {
      final mood = entry.mood;
      if (mood == null) continue;
      final localDate = entry.date.isUtc ? entry.date.toLocal() : entry.date;
      moodsByWeekday.putIfAbsent(localDate.weekday, () => []).add(mood);
    }
    if (moodsByWeekday.length < 3) return null;

    final summaries =
        moodsByWeekday.entries
            .map(
              (entry) => _WeekdayMoodSummary(
                weekday: entry.key,
                average:
                    entry.value.reduce((a, b) => a + b) / entry.value.length,
                sampleCount: entry.value.length,
              ),
            )
            .toList()
          ..sort((a, b) {
            final averageOrder = b.average.compareTo(a.average);
            if (averageOrder != 0) return averageOrder;
            final countOrder = b.sampleCount.compareTo(a.sampleCount);
            if (countOrder != 0) return countOrder;
            return a.weekday.compareTo(b.weekday);
          });

    final best = summaries.first;
    if (best.sampleCount < 2) return null;

    // Require the leading weekday to be clearly separated from the next-best
    // weekday as well as from all other observations combined.
    const minimumMoodGap = 1.0;
    if (best.average - summaries[1].average < minimumMoodGap) return null;

    final otherMoods = <int>[];
    for (final entry in moodsByWeekday.entries) {
      if (entry.key != best.weekday) otherMoods.addAll(entry.value);
    }
    if (otherMoods.length < 3) return null;

    final otherAverage = otherMoods.reduce((a, b) => a + b) / otherMoods.length;
    final gap = best.average - otherAverage;
    if (gap < minimumMoodGap) return null;

    return _WeekdayMoodPattern(
      weekday: best.weekday,
      average: best.average,
      sampleCount: best.sampleCount,
      gap: gap,
    );
  }

  String _weekdayName(int weekday) {
    const names = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - DateTime.monday];
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

class _WeekdayMoodSummary {
  const _WeekdayMoodSummary({
    required this.weekday,
    required this.average,
    required this.sampleCount,
  });

  final int weekday;
  final double average;
  final int sampleCount;
}

class _WeekdayMoodPattern extends _WeekdayMoodSummary {
  const _WeekdayMoodPattern({
    required super.weekday,
    required super.average,
    required super.sampleCount,
    required this.gap,
  });

  final double gap;
}
