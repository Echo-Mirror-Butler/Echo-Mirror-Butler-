import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/themes/app_theme.dart';

/// Overlay tooltip shown to new users pointing to the "Log Today's Mood" button.
/// Dismisses on tap or after 10 seconds.
class FirstRunTooltipOverlay extends StatefulWidget {
  /// Key of the target widget to point at (e.g. Log button).
  final GlobalKey targetKey;
  final VoidCallback onDismiss;

  const FirstRunTooltipOverlay({
    super.key,
    required this.targetKey,
    required this.onDismiss,
  });

  @override
  State<FirstRunTooltipOverlay> createState() => _FirstRunTooltipOverlayState();
}

class _FirstRunTooltipOverlayState extends State<FirstRunTooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  Timer? _timer;
  Offset _targetOffset = Offset.zero;
  Size _targetSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Auto-dismiss after 10 seconds
    _timer = Timer(const Duration(seconds: 10), _dismiss);

    // Measure target position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  void _measureTarget() {
    final ctx = widget.targetKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    setState(() {
      _targetOffset = offset;
      _targetSize = box.size;
    });
  }

  void _dismiss() {
    _timer?.cancel();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltipTop = _targetOffset.dy - 100;
    final tooltipLeft = _targetOffset.dx;

    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.translucent,
      child: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            // Semi-transparent backdrop
            Container(color: Colors.black.withValues(alpha: 0.35)),

            // Tooltip bubble
            Positioned(
              top: tooltipTop.clamp(80.0, double.infinity),
              left: tooltipLeft.clamp(16.0, double.infinity),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              FontAwesomeIcons.handPointer,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Your first task',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Log Today\'s Mood" to make your first entry. Your future self will thank you!',
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
                ),
              ),
            ),

            // Arrow pointing down to target
            if (_targetOffset != Offset.zero)
              Positioned(
                top: (tooltipTop.clamp(80.0, double.infinity)) + 90,
                left: _targetOffset.dx + (_targetSize.width / 2) - 12,
                child: CustomPaint(
                  size: const Size(24, 16),
                  painter: _ArrowPainter(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
