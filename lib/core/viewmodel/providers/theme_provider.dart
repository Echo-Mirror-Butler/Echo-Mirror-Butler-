import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider for managing light/dark mode
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  static const String _themeKey = 'theme_mode';
  bool _isInitialized = false;

  Future<void> _loadThemeMode() async {
    if (_isInitialized) return;
    try {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
      if (themeIndex != null && themeIndex < ThemeMode.values.length) {
      state = ThemeMode.values[themeIndex];
      }
    } catch (e) {
      // If loading fails, keep system default
      debugPrint('Error loading theme mode: $e');
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  void toggleTheme() {
    // Toggle between light and dark only (skip system mode)
    final newMode = state == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    setThemeMode(newMode);
  }
}

/// Provider for theme mode
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);

