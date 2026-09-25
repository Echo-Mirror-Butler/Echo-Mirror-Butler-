import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echomirror/features/onboarding/viewmodel/providers/onboarding_provider.dart';
import 'package:echomirror/features/onboarding/viewmodel/providers/first_run_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('onboardingCompletedProvider helpers', () {
    test('onboarding is not completed on a fresh install', () async {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('onboarding_completed') ?? false;
      expect(completed, isFalse);
    });

    test('markOnboardingCompleted persists the flag', () async {
      await markOnboardingCompleted();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    test('markOnboardingCompleted writes an ISO timestamp', () async {
      await markOnboardingCompleted();

      final ts = await getOnboardingCompletedAt();
      expect(ts, isNotNull);
      expect(DateTime.tryParse(ts!), isNotNull);
    });

    test('markOnboardingCompleted is idempotent', () async {
      await markOnboardingCompleted();
      await markOnboardingCompleted();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });
  });

  group('saveHabitPresets / habitPresetsProvider', () {
    test('saveHabitPresets persists the selected habits', () async {
      const habits = ['Exercise', 'Journaling', 'Hydration'];
      await saveHabitPresets(habits);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('user_habit_presets'), equals(habits));
    });

    test('saveHabitPresets with empty list clears previous selection', () async {
      await saveHabitPresets(['Morning meditation']);
      await saveHabitPresets([]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('user_habit_presets'), isEmpty);
    });

    test('saveHabitPresets overwrites a previous selection', () async {
      await saveHabitPresets(['Reading']);
      await saveHabitPresets(['Gratitude', 'Sleep by 10pm']);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('user_habit_presets'),
        equals(['Gratitude', 'Sleep by 10pm']),
      );
    });
  });

  group('getOnboardingCompletedAt', () {
    test('returns null before onboarding is completed', () async {
      final ts = await getOnboardingCompletedAt();
      expect(ts, isNull);
    });

    test('returns a non-null string after completion', () async {
      await markOnboardingCompleted();
      final ts = await getOnboardingCompletedAt();
      expect(ts, isNotNull);
    });
  });

  group('firstRunProvider helpers', () {
    test('markFirstRunSeen persists the flag', () async {
      await markFirstRunSeen();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('first_run_tooltip_shown'), isTrue);
    });

    test('flag is absent on a fresh install', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('first_run_tooltip_shown'), isNull);
    });
  });
}
