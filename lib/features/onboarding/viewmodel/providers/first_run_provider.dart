import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFirstRunKey = 'first_run_tooltip_shown';

final firstRunProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kFirstRunKey) ?? false);
});

Future<void> markFirstRunSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kFirstRunKey, true);
}
