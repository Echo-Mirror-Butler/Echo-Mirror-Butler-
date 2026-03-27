import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/features/dashboard/data/models/mood_analytics_model.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';

void main() {
  group('MoodAnalyticsModel.fromEntries', () {
    test('handles empty entries list seamlessly', () {
      final model = MoodAnalyticsModel.fromEntries([]);
      expect(model.totalEntries, 0);
      expect(model.averageMood, 0.0);
      expect(model.moodDistribution, isEmpty);
      expect(model.weeklyTrend, isEmpty);
      expect(model.monthlyTrend, isEmpty);
      expect(model.bestMoodDay, isNull);
      expect(model.worstMoodDay, isNull);
      expect(model.weeklyAverage, isNull);
      expect(model.monthlyAverage, isNull);
    });

    test('calculates analytics properly from valid entries', () {
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      final entries = [
        MoodEntry(date: now, mood: 4),
        MoodEntry(date: twoDaysAgo, mood: 2),
        MoodEntry(
          date: tenDaysAgo,
          mood: 5,
        ), // Not in weekly trend, but in monthly
      ];

      final model = MoodAnalyticsModel.fromEntries(entries);

      // Total 3 entries
      expect(model.totalEntries, 3);

      // Average mood = (4 + 2 + 5) / 3 = 11 / 3 = 3.666
      expect(model.averageMood, closeTo(3.666, 0.01));

      // Best/Worst
      expect(model.bestMoodDay, 5);
      expect(model.worstMoodDay, 2);

      // Distribution
      expect(model.moodDistribution[4], 1);
      expect(model.moodDistribution[2], 1);
      expect(model.moodDistribution[5], 1);

      // Trends
      expect(model.weeklyTrend.length, 7);
      expect(model.monthlyTrend.length, 30);

      // Weekly avg (4 + 2) / 2 = 3.0
      expect(model.weeklyAverage, closeTo(3.0, 0.01));

      // Monthly avg (4 + 2 + 5) / 3 = 3.666
      expect(model.monthlyAverage, closeTo(3.666, 0.01));
    });

    test('handles entries without mood values gracefully', () {
      final now = DateTime.now();

      final entries = [
        MoodEntry(date: now, mood: null),
        MoodEntry(date: now.subtract(const Duration(days: 1)), mood: null),
      ];

      final model = MoodAnalyticsModel.fromEntries(entries);
      expect(model.totalEntries, 2);
      expect(model.averageMood, 0.0);
      expect(model.bestMoodDay, isNull);
      expect(model.weeklyAverage, isNull);
    });

    test('orders trends chronologically and injects empty dates', () {
      final now = DateTime.now();
      final entries = [MoodEntry(date: now, mood: 5)];

      final model = MoodAnalyticsModel.fromEntries(entries);
      final lastPoint = model.weeklyTrend.last;

      expect(lastPoint.date.year, now.year);
      expect(lastPoint.date.month, now.month);
      expect(lastPoint.date.day, now.day);
      expect(lastPoint.mood, 5);

      // Check an older, empty point
      final firstPoint = model.weeklyTrend.first;
      expect(firstPoint.mood, isNull);
    });
  });
}
