import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';

/// Persisted key for the touch gesture hint "seen" flag.
const String _kTouchGestureHintSeen = 'touch_gesture_hint_seen';

/// A one-time onboarding hint overlay for the Global Mirror screen.
///
/// Shows a visual hint explaining touch gestures (pan, pinch, tap) on the globe.
/// Auto-dismisses after a timeout or on tap, and persists a "seen" flag via
/// SharedPreferences so it only appears once per user (per install).
///
/// To reset for testing: run `SharedPreferences` and delete the key
/// `touch_gesture_hint_seen`, or call [TouchGestureHint.resetForTesting].
class TouchGestureHint extends StatefulWidget {
  final VoidCallback onDismiss;

  const TouchGestureHint({super.key, required this.onDismiss});

  @override
  State<TouchGestureHint> createState() => _TouchGestureHintState();

  /// Returns whether the hint has been seen before.
  static Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTouchGestureHintSeen) ?? false;
  }

  /// Marks the hint as seen (persisted).
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTouchGestureHintSeen, true);
  }

  /// Resets the "seen" flag so the hint will show again.
  /// Useful for QA/testing — call from a debug menu or dev console.
  static Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTouchGestureHintSeen);
  }
}

class _TouchGestureHintState extends State<TouchGestureHint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Auto-dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      TouchGestureHint.markAsSeen();
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.translucent,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _GestureIcon(
                      icon: FontAwesomeIcons.hand,
                      label: 'Pan',
                    ),
                    SizedBox(width: 24),
                    _GestureIcon(
                      icon: FontAwesomeIcons.upDownLeftRight,
                      label: 'Pinch',
                    ),
                    SizedBox(width: 24),
                    _GestureIcon(
                      icon: FontAwesomeIcons.handPointer,
                      label: 'Tap',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Explore the Global Mirror',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pan to move around the globe \u2022 Pinch to zoom \u2022 Tap a mood pin to see how others are feeling',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap anywhere to dismiss',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GestureIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GestureIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}