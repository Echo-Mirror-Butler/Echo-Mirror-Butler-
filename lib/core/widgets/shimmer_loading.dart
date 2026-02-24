import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable shimmer loading widget to replace CircularProgressIndicator
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    this.width,
    this.height,
    this.shape = ShimmerShape.circle,
    this.baseColor,
    this.highlightColor,
    this.radius,
  });

  final double? width;
  final double? height;
  final ShimmerShape shape;
  final Color? baseColor;
  final Color? highlightColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!),
      highlightColor:
          highlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width ?? 20,
        height: height ?? 20,
        decoration: shape == ShimmerShape.circle
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(radius ?? 8),
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
      ),
    );
  }
}

/// Shimmer loading for buttons
class ShimmerButton extends StatelessWidget {
  const ShimmerButton({super.key, this.width, this.height = 20});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? Colors.grey[800] : Colors.grey[300],
        ),
      ),
    );
  }
}

/// Shimmer loading for cards
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height, this.padding});

  final double? height;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        height: height ?? 100,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.grey[800] : Colors.grey[300],
        ),
      ),
    );
  }
}

/// Shimmer loading for text
class ShimmerText extends StatelessWidget {
  const ShimmerText({
    super.key,
    required this.width,
    this.height = 16,
    this.radius = 4,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: isDark ? Colors.grey[800] : Colors.grey[300],
        ),
      ),
    );
  }
}

enum ShimmerShape { circle, rectangle }
