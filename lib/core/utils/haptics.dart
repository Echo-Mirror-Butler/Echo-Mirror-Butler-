import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Haptics {
  const Haptics._();

  static Future<void> selection() => _run(HapticFeedback.selectionClick);

  static Future<void> impactMedium() => _run(HapticFeedback.mediumImpact);

  static Future<void> impactLight() => _run(HapticFeedback.lightImpact);

  static Future<void> error() => _run(HapticFeedback.vibrate);

  static Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Haptics unavailable: $error');
    }
  }
}
