import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/features/dashboard/data/models/mood_analytics_model.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';

LogEntryModel _entry(String id, DateTime date, {int? mood = 3}) =>
    LogEntryModel(
      id: id,
      userId: 'user-1',
      date: date,
      mood: mood,
      habits: [],
      notes: '',
      createdAt: date,
    );

void main() {
  group('MoodAnalyticsModel.computeStreak', () {
    test('returns 0 for empty list', () {
      final result = MoodAnalyticsModel.computeStreak([]);
      expect(result, 0);
    });

    test('returns 1 for single day matching reference date', () {
      final ref = DateTime(2024, 6, 10);
      final entries = [_entry('1', DateTime(2024, 6, 10))];
      final result = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: ref,
      );
      expect(result, 1);
    });

    test('returns 0 when single entry does not match reference date', () {
      final ref = DateTime(2024, 6, 10);
      final entries = [_entry('1', DateTime(2024, 6, 8))];
      final result = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: ref,
      );
      expect(result, 0);
    });

    test('returns correct streak for multi-day consecutive entries', () {
      final ref = DateTime(2024, 6, 10);
      final entries = [
        _entry('1', DateTime(2024, 6, 8)),
        _entry('2', DateTime(2024, 6, 9)),
        _entry('3', DateTime(2024, 6, 10)),
      ];
      final result = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: ref,
      );
      expect(result, 3);
    });

    test('stops streak at gap in dates', () {
      final ref = DateTime(2024, 6, 10);
      final entries = [
        _entry('1', DateTime(2024, 6, 7)), // gap here
        _entry('2', DateTime(2024, 6, 9)),
        _entry('3', DateTime(2024, 6, 10)),
      ];
      final result = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: ref,
      );
      expect(result, 2);
    });

    test('ignores entries with null mood', () {
      final ref = DateTime(2024, 6, 10);
      final entries = [
        _entry('1', DateTime(2024, 6, 8), mood: null),
        _entry('2', DateTime(2024, 6, 9)),
        _entry('3', DateTime(2024, 6, 10)),
      ];
      final result = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: ref,
      );
      expect(result, 2);
    });

    test('deduplicates multiple entries on the same day', () {
      final ref = DateTime(2024, 6, 10);
      final entries = [
        _entry('1', DateTime(2024, 6, 9)),
        _entry('2', DateTime(2024, 6, 9)),
        _entry('3', DateTime(2024, 6, 10)),
      ];
      final result = MoodAnalyticsModel.computeStreak(
        entries,
        referenceDate: ref,
      );
      expect(result, 2);
    });
  });
}
