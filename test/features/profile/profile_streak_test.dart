import 'package:flutter_test/flutter_test.dart';

// Expose the pure streak-calculation logic for unit testing by reproducing
// the algorithm here.  The identical implementation lives in
// lib/features/profile/view/screens/profile_screen.dart → _calculateStreak.
int calculateStreak(List<String> dates) {
  if (dates.isEmpty) return 0;
  int streak = 0;
  DateTime cursor = DateTime.now();
  for (final d in dates) {
    final day = DateTime.tryParse(d);
    if (day == null) break;
    final diff = DateTime(cursor.year, cursor.month, cursor.day)
        .difference(DateTime(day.year, day.month, day.day))
        .inDays;
    if (diff == 0 || diff == 1) {
      streak++;
      cursor = day;
    } else {
      break;
    }
  }
  return streak;
}

void main() {
  group('Profile streak calculation', () {
    test('empty list returns 0', () {
      expect(calculateStreak([]), 0);
    });

    test('single entry for today returns 1', () {
      final today = DateTime.now();
      final dateStr = today.toIso8601String().split('T').first;
      expect(calculateStreak([dateStr]), 1);
    });

    test('consecutive days build a streak', () {
      final today = DateTime.now();
      final dates = List.generate(
        5,
        (i) => today.subtract(Duration(days: i)).toIso8601String().split('T').first,
      );
      expect(calculateStreak(dates), 5);
    });

    test('gap in dates breaks the streak at the gap', () {
      final today = DateTime.now();
      // days 0, 1, and then a gap to day 3
      final dates = [
        today.subtract(const Duration(days: 0)).toIso8601String().split('T').first,
        today.subtract(const Duration(days: 1)).toIso8601String().split('T').first,
        today.subtract(const Duration(days: 3)).toIso8601String().split('T').first,
      ];
      expect(calculateStreak(dates), 2);
    });

    test('unparseable date string breaks the loop immediately', () {
      expect(calculateStreak(['not-a-date']), 0);
    });

    test('list with one invalid entry after valid ones stops at invalid', () {
      final today = DateTime.now();
      final dates = [
        today.toIso8601String().split('T').first,
        'bad-date',
      ];
      expect(calculateStreak(dates), 1);
    });
  });
}
