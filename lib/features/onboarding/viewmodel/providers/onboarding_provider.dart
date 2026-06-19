import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _onboardingCompletedKey = 'onboarding_completed';
const String _onboardingCompletedAtKey = 'onboarding_completed_at';
const String _habitPresetsKey = 'user_habit_presets';

/// Provider to check if onboarding has been completed
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompletedKey) ?? false;
});

/// Provider to read saved habit presets
final habitPresetsProvider = FutureProvider<List<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_habitPresetsKey) ?? [];
});

/// Helper to mark onboarding as completed with ISO timestamp
Future<void> markOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingCompletedKey, true);
  await prefs.setString(
    _onboardingCompletedAtKey,
    DateTime.now().toIso8601String(),
  );
}

/// Save selected habit presets
Future<void> saveHabitPresets(List<String> habits) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_habitPresetsKey, habits);
}

/// Get onboarding completed timestamp
Future<String?> getOnboardingCompletedAt() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_onboardingCompletedAtKey);
}
