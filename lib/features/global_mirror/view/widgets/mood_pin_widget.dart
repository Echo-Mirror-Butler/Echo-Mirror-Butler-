import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../data/models/mood_pin_model.dart';
import 'mood_pin_comment_dialog.dart';

/// Animated mood pin widget for the globe
class MoodPinWidget extends StatefulWidget {
  final MoodPinModel pin;
  final Color color;

  const MoodPinWidget({super.key, required this.pin, required this.color});

  @override
  State<MoodPinWidget> createState() => _MoodPinWidgetState();
}

class _MoodPinWidgetState extends State<MoodPinWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZoomIn(
      child: GestureDetector(
        onTap: () {
          _showPinDetails(context);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple effect
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 24 * _pulseAnimation.value,
                  height: 24 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(
                      0.3 / _pulseAnimation.value,
                    ),
                  ),
                );
              },
            ),
            // Pin dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPinDetails(BuildContext context) {
    // Show comment dialog instead of simple details
    showDialog(
      context: context,
      builder: (context) => MoodPinCommentDialog(pin: widget.pin),
    );
  }
}
