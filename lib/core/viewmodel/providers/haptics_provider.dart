import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'haptics_provider.g.dart';

@riverpod
class HapticsEnabled extends _$HapticsEnabled {
  static const _key = 'haptics_enabled';

  @override
  bool build() {
    _loadState();
    return true; // Default to true while loading
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_key) ?? true;
    state = isEnabled;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final newState = !state;
    await prefs.setBool(_key, newState);
    state = newState;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = value;
  }
}
