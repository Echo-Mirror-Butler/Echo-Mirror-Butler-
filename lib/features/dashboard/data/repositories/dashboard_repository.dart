import '../models/insight_model.dart';
import '../../../logging/data/repositories/logging_repository.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// Repository for dashboard operations
/// Handles all Serverpod backend calls for insights and predictions
class DashboardRepository {
  DashboardRepository(this._loggingRepository);

  final LoggingRepository _loggingRepository;

  /// Get insights for a user
  /// Generates insights from log entries
  Future<List<InsightModel>> getInsights(String userId) async {
    try {
      // Fetch log entries
      final logEntries = await _loggingRepository.getLogEntries(userId);

      if (logEntries.isEmpty) {
        return [];
      }

      final insights = <InsightModel>[];
      final now = DateTime.now();

      // Group entries by date
      final entriesByDate = <DateTime, List<LogEntryModel>>{};
      for (final entry in logEntries) {
        final date = DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        );
        entriesByDate.putIfAbsent(date, () => []).add(entry);
      }

      // Generate mood insights
      // Normalize dates to local time for accurate comparisons (same as logging screen)
      final moodEntries = logEntries.where((e) => e.mood != null).toList();

      if (moodEntries.isNotEmpty) {
        final averageMood =
            moodEntries.map((e) => e.mood!).reduce((a, b) => a + b) /
            moodEntries.length;

        // Weekly mood trend - use local time for comparison (same as logging screen)
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
                    'Your mood has been improving over the past week! Keep up the great work.',
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
                    'Your mood has been lower recently. Consider taking some time for self-care.',
                date: now,
                type: InsightType.mood,
                createdAt: now,
              ),
            );
          }
        }

        // Best mood day
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
                  'You had an excellent mood on ${_formatDate(localDate)}. What made that day special?',
              date: localDate,
              type: InsightType.mood,
              createdAt: now,
            ),
          );
        }
      }

      // Generate habit insights
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
                  'You\'ve logged "${topHabit.key}" ${topHabit.value} times. Consistency is key!',
              date: now,
              type: InsightType.habit,
              createdAt: now,
            ),
          );
        }

        // Check for habit streaks - normalize dates for comparison
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
                  'You\'ve been practicing ${recentHabits.length} different habits this week. Great diversity!',
              date: now,
              type: InsightType.habit,
              createdAt: now,
            ),
          );
        }
      }

      // Generate general insights
      final totalEntries = logEntries.length;
      if (totalEntries >= 7) {
        insights.add(
          InsightModel(
            id: 'milestone-${now.millisecondsSinceEpoch}',
            userId: userId,
            title: 'Logging Milestone',
            description:
                'You\'ve logged $totalEntries entries! Your consistency is building valuable insights.',
            date: now,
            type: InsightType.general,
            createdAt: now,
          ),
        );
      }

      // Generate predictions based on patterns
      if (moodEntries.length >= 5) {
        final weekdayMoods = <int, List<int>>{};
        for (final entry in moodEntries) {
          // Normalize date to local time for weekday calculation
          final localDate = entry.date.isUtc
              ? entry.date.toLocal()
              : entry.date;
          final weekday = localDate.weekday;
          if (entry.mood != null) {
            weekdayMoods.putIfAbsent(weekday, () => []).add(entry.mood!);
          }
        }

        if (weekdayMoods.isNotEmpty) {
          final bestWeekday = weekdayMoods.entries
              .map(
                (e) => MapEntry(
                  e.key,
                  e.value.reduce((a, b) => a + b) / e.value.length,
                ),
              )
              .reduce((a, b) => a.value > b.value ? a : b);

          insights.add(
            InsightModel(
              id: 'prediction-${now.millisecondsSinceEpoch}',
              userId: userId,
              title: 'Pattern Detected',
              description:
                  'Based on your logs, you tend to have better moods on ${_getWeekdayName(bestWeekday.key)}. Plan something special!',
              date: now,
              type: InsightType.prediction,
              createdAt: now,
            ),
          );
        }
      }

      // Sort by date (most recent first)
      insights.sort((a, b) => b.date.compareTo(a.date));

      return insights;
    } catch (e) {
      throw Exception('Failed to get insights: ${e.toString()}');
    }
  }

  String _formatDate(DateTime date) {
    final months = [
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

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdays[weekday - 1];
  }

  /// Get predictions for a user
  Future<List<InsightModel>> getPredictions(String userId) async {
    try {
      // Example Serverpod call
      // final results = await _client.dashboard.getPredictions(userId);
      // return results.map((r) => InsightModel.fromJson(r)).toList();

      // Placeholder implementation
      await Future.delayed(const Duration(seconds: 1));
      return [];
    } catch (e) {
      throw Exception('Failed to get predictions: ${e.toString()}');
    }
  }

  /// Get future letters (time capsule feature)
  Future<List<InsightModel>> getFutureLetters(String userId) async {
    try {
      // Example Serverpod call
      // final results = await _client.dashboard.getFutureLetters(userId);
      // return results.map((r) => InsightModel.fromJson(r)).toList();

      // Placeholder implementation
      await Future.delayed(const Duration(seconds: 1));
      return [];
    } catch (e) {
      throw Exception('Failed to get future letters: ${e.toString()}');
    }
  }
}
