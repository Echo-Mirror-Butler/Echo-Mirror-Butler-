import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key for storing onboarding completion status
const String _onboardingCompletedKey = 'onboarding_completed';

/// Provider to check if onboarding has been completed
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompletedKey) ?? false;
});

/// Provider to mark onboarding as completed
final completeOnboardingProvider = FutureProvider.family<void, bool>((
  ref,
  completed,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingCompletedKey, completed);
  ref.invalidate(onboardingCompletedProvider);
});

/// Helper function to mark onboarding as completed
Future<void> markOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingCompletedKey, true);
}
