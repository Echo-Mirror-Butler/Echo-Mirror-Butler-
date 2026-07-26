import 'package:flutter/material.dart';
<<<<<<< HEAD
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
=======
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class TouchGestureHint extends StatefulWidget {
  const TouchGestureHint({super.key});

  @override
  State<TouchGestureHint> createState() => _TouchGestureHintState();
}

class _TouchGestureHintState extends State<TouchGestureHint> {
  bool _visible = true;
>>>>>>> upstream/development

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
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
=======
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _visible = false;
        });
      }
>>>>>>> upstream/development
    });
  }

  @override
<<<<<<< HEAD
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
=======
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return FadeIn(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _visible = false;
          });
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: FadeInUp(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                margin: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 48,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pinch to zoom',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag to pan',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap anywhere to dismiss',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
>>>>>>> upstream/development
            ),
          ),
        ),
      ),
    );
  }
}
<<<<<<< HEAD

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
=======
>>>>>>> upstream/development
