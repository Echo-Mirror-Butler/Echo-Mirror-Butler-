import 'package:shared_preferences/shared_preferences.dart';

/// Service to track user's own mood pin IDs locally
class UserMoodPinsService {
  static const String _key = 'user_mood_pin_ids';

  /// Add a mood pin ID to user's list
  static Future<void> addMoodPinId(String pinId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingIds = getMoodPinIdsSync(prefs);
    if (!existingIds.contains(pinId)) {
      existingIds.add(pinId);
      await prefs.setStringList(_key, existingIds);
    }
  }

  /// Get all mood pin IDs belonging to the user
  static Future<List<String>> getMoodPinIds() async {
    final prefs = await SharedPreferences.getInstance();
    return getMoodPinIdsSync(prefs);
  }

  /// Get mood pin IDs synchronously (for use with already obtained prefs)
  static List<String> getMoodPinIdsSync(SharedPreferences prefs) {
    return prefs.getStringList(_key) ?? [];
  }

  /// Check if a mood pin ID belongs to the user
  static Future<bool> isUserMoodPin(String pinId) async {
    final ids = await getMoodPinIds();
    return ids.contains(pinId);
  }

  /// Remove a mood pin ID (when it expires)
  static Future<void> removeMoodPinId(String pinId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingIds = getMoodPinIdsSync(prefs);
    existingIds.remove(pinId);
    await prefs.setStringList(_key, existingIds);
  }

  /// Clear all mood pin IDs
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
