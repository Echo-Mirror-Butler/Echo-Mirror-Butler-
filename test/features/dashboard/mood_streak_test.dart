import 'package:echomirror/features/dashboard/data/models/mood_analytics_model.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoodAnalyticsModel.computeStreak', () {
    final referenceDate = DateTime(2026, 2, 27, 12, 0);

    LogEntryModel buildEntry(
      DateTime date, {
      int? mood = 3,
      String userId = 'user_1',
    }) {
      final normalized = DateTime(date.year, date.month, date.day);
      return LogEntryModel(
        id: '${normalized.toIso8601String()}-${mood ?? 'none'}',
        userId: userId,
        date: normalized,
        mood: mood,
        habits: const [],
        notes: null,
        createdAt: normalized,
      );
    }

    test('returns 0 when there are no entries', () {
      final streak = MoodAnalyticsModel.computeStreak(
        const <LogEntryModel>[],
        referenceDate: referenceDate,
      );
      expect(streak, 0);
    });

    test('counts consecutive days starting from today', () {
      final entries = [
        buildEntry(referenceDate),
        buildEntry(referenceDate.subtract(const Duration(days: 1))),
        buildEntry(referenceDate.subtract(const Duration(days: 2))),
      ];

      final streak = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: referenceDate,
      );

      expect(streak, 3);
    });

    test('returns 0 when today has no mood entry', () {
      final entries = [
        buildEntry(referenceDate.subtract(const Duration(days: 1))),
        buildEntry(referenceDate.subtract(const Duration(days: 2))),
      ];

      final streak = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: referenceDate,
      );

      expect(streak, 0);
    });

    test('ignores duplicate dates and null mood entries', () {
      final entries = [
        buildEntry(referenceDate, mood: 4),
        buildEntry(referenceDate, mood: 2), // Same date should not double-count.
        buildEntry(referenceDate.subtract(const Duration(days: 1)), mood: 3),
        buildEntry(
          referenceDate.subtract(const Duration(days: 2)),
          mood: null,
        ), // Null mood should not count.
      ];

      final streak = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: referenceDate,
      );

      expect(streak, 2);
    });

    test('updates correctly when mock entries are added and removed', () {
      var entries = [
        buildEntry(referenceDate),
        buildEntry(referenceDate.subtract(const Duration(days: 1))),
      ];

      expect(
        MoodAnalyticsModel.computeStreak(entries, referenceDate: referenceDate),
        2,
      );

      entries = [
        ...entries,
        buildEntry(referenceDate.subtract(const Duration(days: 2))),
      ];

      expect(
        MoodAnalyticsModel.computeStreak(entries, referenceDate: referenceDate),
        3,
      );

      entries = entries
          .where(
            (entry) =>
                !_isSameDay(
                  entry.date,
                  DateTime(referenceDate.year, referenceDate.month, referenceDate.day),
                ),
          )
          .toList();

      expect(
        MoodAnalyticsModel.computeStreak(entries, referenceDate: referenceDate),
        0,
      );
    });
  });
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
