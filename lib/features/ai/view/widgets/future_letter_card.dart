import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/animations/lottie_animations.dart';
import '../../data/models/ai_insight_model.dart';

/// Card displaying the motivational letter from "future me"
class FutureLetterCard extends StatefulWidget {
  final AiInsightModel insight;

  const FutureLetterCard({
    super.key,
    required this.insight,
  });

  @override
  State<FutureLetterCard> createState() => _FutureLetterCardState();
}

class _FutureLetterCardState extends State<FutureLetterCard>
    with TickerProviderStateMixin {
  bool _hasPlayedAnimation = false;
  int _envelopePlayCount = 0;
  late AnimationController _lottieController;
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    // Initialize envelope controller with a default duration
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Initialize sparkle controller
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Start animations immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _hasPlayedAnimation = true;
        });
        // Start sparkle animation and stop after 5 seconds
        _sparkleController.repeat();
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _sparkleController.stop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.secondaryColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              FontAwesomeIcons.envelopeOpen,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          // Lottie animation overlay - play 3 times
                          if (_hasPlayedAnimation && _envelopePlayCount < 3)
                            Positioned.fill(
                              child: Lottie.asset(
                                LottieAnimations.envelopeOpen,
                                controller: _lottieController,
                                fit: BoxFit.contain,
                                repeat: false,
                                onLoaded: (composition) {
                                  if (mounted) {
                                    // Update duration and play animation 3 times
                                    _lottieController.duration = composition.duration;
                                    _playEnvelopeAnimation();
                                  }
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  // Gracefully handle missing Lottie file
                                  debugPrint('[FutureLetterCard] Envelope Lottie error: $error');
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                      'Letter from Future You',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                  widget.insight.futureLetter,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.6,
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                    letterSpacing: 0.2,
                  ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                'Generated ${_formatDate(widget.insight.generatedAt)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Lottie sparkle animation in background (subtle but visible)
        // Only show if animation has been initialized
        if (_hasPlayedAnimation)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.3, // Increased to make it more visible
                child: Lottie.asset(
                  LottieAnimations.sparkle,
                  controller: _sparkleController,
                  repeat: true,
                  animate: true, // Explicitly enable animation
                  onLoaded: (composition) {
                    if (mounted) {
                      _sparkleController.duration = composition.duration;
                      // Ensure animation is playing
                      if (!_sparkleController.isAnimating) {
                        _sparkleController.repeat();
                      }
                    }
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Log error for debugging
                    debugPrint('[FutureLetterCard] Sparkle animation error: $error');
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _playEnvelopeAnimation() {
    if (!mounted || _envelopePlayCount >= 3) return;
    
    _lottieController.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _envelopePlayCount++;
      });
      
      if (_envelopePlayCount < 3) {
        // Wait a bit before playing again
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _lottieController.reset();
            _playEnvelopeAnimation();
          }
        });
      } else {
        // After 3 plays, reset and keep it reset
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _lottieController.reset();
          }
        });
      }
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return 'on ${date.day}/${date.month}/${date.year}';
    }
  }
}

