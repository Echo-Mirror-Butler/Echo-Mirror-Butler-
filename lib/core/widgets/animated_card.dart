import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Reusable animated card widget with elevation, shadow, and entrance animation
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Duration animationDuration;
  final Curve animationCurve;
  final VoidCallback? onTap;

  const AnimatedCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.elevation,
    this.borderRadius,
    this.backgroundColor,
    this.gradient,
    this.animationDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.easeOutCubic,
    this.onTap,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.animationCurve),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.animationCurve),
    );

    // Start animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardElevation = widget.elevation ?? 4.0;
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: cardElevation,
          shadowColor: AppTheme.primaryColor.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          margin:
              widget.margin ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: borderRadius,
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: widget.backgroundColor ?? theme.colorScheme.surface,
                gradient: widget.gradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
