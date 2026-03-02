import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the currently selected index in the main bottom navigation.
final mainTabIndexProvider = StateProvider<int>((ref) => 0);
