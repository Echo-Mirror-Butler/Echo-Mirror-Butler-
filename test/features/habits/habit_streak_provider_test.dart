import 'package:flutter_test/flutter_test.dart';

import 'package:echomirror/features/habits/viewmodel/providers/habit_streak_provider.dart';

void main() {
  group('HabitStreakState', () {
    test('default state has zero streaks and no error', () {
      const state = HabitStreakState();
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.lastLogDate, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates currentStreak', () {
      const state = HabitStreakState();
      final updated = state.copyWith(currentStreak: 7);
      expect(updated.currentStreak, 7);
      expect(updated.longestStreak, 0); // unchanged
    });

    test('copyWith updates longestStreak independently', () {
      const state = HabitStreakState(currentStreak: 3, longestStreak: 5);
      final updated = state.copyWith(longestStreak: 10);
      expect(updated.currentStreak, 3); // unchanged
      expect(updated.longestStreak, 10);
    });

    test('copyWith sets isLoading flag', () {
      const state = HabitStreakState();
      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);
      final done = loading.copyWith(isLoading: false);
      expect(done.isLoading, isFalse);
    });

    test('copyWith stores an error message', () {
      const state = HabitStreakState();
      final withError = state.copyWith(error: 'Network error');
      expect(withError.error, 'Network error');
    });

    test('copyWith clears the error with clearError flag', () {
      const state = HabitStreakState(error: 'Something went wrong');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith preserves existing lastLogDate when not supplied', () {
      final date = DateTime(2026, 1, 15);
      final state = HabitStreakState(lastLogDate: date);
      final updated = state.copyWith(currentStreak: 5);
      expect(updated.lastLogDate, date);
    });

    test('copyWith can update lastLogDate', () {
      final original = DateTime(2026, 1, 1);
      final newer = DateTime(2026, 9, 25);
      final state = HabitStreakState(lastLogDate: original);
      final updated = state.copyWith(lastLogDate: newer);
      expect(updated.lastLogDate, newer);
    });

    test('HabitStreakNotifier starts in default state', () {
      final notifier = HabitStreakNotifier();
      expect(notifier.state.currentStreak, 0);
      expect(notifier.state.isLoading, isFalse);
    });

    test('loadStreak does nothing for an empty userId', () async {
      final notifier = HabitStreakNotifier();
      await notifier.loadStreak('');
      // State should remain at defaults — no loading attempted.
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.currentStreak, 0);
    });
  });
}
