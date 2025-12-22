import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/animations/lottie_animations.dart';
import '../../viewmodel/providers/onboarding_provider.dart';

/// Onboarding screen with PageView
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Meet EchoMirror',
      subtitle: 'Your Future Self as a Butler',
      description:
          'A personal growth assistant that helps you reflect, track your journey, and receive insights from your future self.',
      icon: FontAwesomeIcons.userTie,
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80',
      lottieAsset: LottieAnimations.mirrorReflection,
      gradient: [AppTheme.primaryColor, AppTheme.secondaryColor],
    ),
    OnboardingPageData(
      title: 'Log Daily Moods & Habits',
      description:
          'Capture your daily reflections, track your mood, and build meaningful habits. Your journey starts with a single entry.',
      icon: FontAwesomeIcons.book,
      imageUrl: 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800&q=80',
      lottieAsset: LottieAnimations.habitCheck,
      gradient: [AppTheme.secondaryColor, AppTheme.accentColor],
    ),
    OnboardingPageData(
      title: 'Receive Predictions & Letters',
      description:
          'Get AI-powered insights about your patterns, predictions for your future, and motivational letters from your future self.',
      icon: FontAwesomeIcons.envelopeOpen,
      imageUrl: 'https://images.unsplash.com/photo-1516534775068-ba3e7458af70?w=800&q=80',
      lottieAsset: LottieAnimations.envelopeOpen,
      gradient: [AppTheme.accentColor, AppTheme.primaryColor],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _completeOnboarding() async {
    try {
      // Mark onboarding as completed
      await markOnboardingCompleted();
      
      // Invalidate the provider to refresh the router's redirect logic
      ref.invalidate(onboardingCompletedProvider);
      
      // Wait a bit longer to ensure SharedPreferences write completes
      // and the provider state is refreshed
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted) {
        // Navigate to login - the router redirect should now allow this
        context.go('/login');
      }
    } catch (e, stackTrace) {
      debugPrint('[OnboardingScreen] Error completing onboarding: $e');
      debugPrint('[OnboardingScreen] Stack trace: $stackTrace');
      // Fallback: try to navigate anyway after marking as completed
      if (mounted) {
        try {
          await markOnboardingCompleted();
          await Future.delayed(const Duration(milliseconds: 100));
          context.go('/login');
        } catch (e2) {
          debugPrint('[OnboardingScreen] Fallback navigation also failed: $e2');
        }
      }
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Skip button
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _skipOnboarding,
                child: Text(
                  'Skip',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),

            // PageView content
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _OnboardingPage(
                  data: _pages[index],
                  isLastPage: index == _pages.length - 1,
                  onGetStarted: _completeOnboarding,
                );
              },
            ),

            // Page indicator and navigation buttons
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppTheme.primaryColor,
                      dotColor: theme.colorScheme.onSurface.withOpacity(0.2),
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 4,
                      spacing: 8,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous button (hidden on first page)
                        if (_currentPage > 0)
                          TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Text(
                              'Previous',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 80),

                        // Next/Get Started button
                        ElevatedButton(
                          onPressed: isLastPage
                              ? _completeOnboarding
                              : () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isLastPage ? 'Start Reflecting' : 'Next',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLastPage
                                    ? FontAwesomeIcons.arrowRight
                                    : FontAwesomeIcons.chevronRight,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual onboarding page widget
class _OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final bool isLastPage;
  final VoidCallback onGetStarted;

  const _OnboardingPage({
    required this.data,
    required this.isLastPage,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Image with Lottie animation overlay
          Stack(
            alignment: Alignment.center,
            children: [
              // Background image
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.gradient.first.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
                ),
                child: ClipOval(
                  child: data.imageUrl != null
                      ? Image.network(
                          data.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: data.gradient,
                                ),
            ),
            child: Center(
                                child: loadingProgress.expectedTotalBytes != null
                                    ? ShimmerLoading(
                                        width: 40,
                                        height: 40,
                                        baseColor: Colors.white24,
                                        highlightColor: Colors.white70,
                                      )
                                    : const ShimmerLoading(
                                        width: 40,
                                        height: 40,
                                        baseColor: Colors.white24,
                                        highlightColor: Colors.white70,
                                ),
                              ),
                        );
                      },
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to gradient if image fails
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: data.gradient,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                      data.icon,
                      size: 120,
                      color: Colors.white,
                    ),
            ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: data.gradient,
                            ),
                          ),
                        ),
                ),
              ),
              
              // Gradient overlay for better Lottie visibility
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.2),
                    ],
                  ),
                ),
              ),
              
              // Lottie animation overlay
              if (data.lottieAsset != null)
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Lottie.asset(
                    data.lottieAsset!,
                    fit: BoxFit.contain,
                    repeat: true,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to nothing if Lottie fails (image is still visible)
                      return const SizedBox.shrink();
                    },
                  ),
                ),
            ],
          ),

          const Spacer(flex: 2),

          // Title
          Text(
            data.title,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          if (data.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              data.subtitle!,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              data.description,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 80), // Add extra spacing before page indicator
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// Data class for onboarding pages
class OnboardingPageData {
  final String title;
  final String? subtitle;
  final String description;
  final IconData icon;
  final String? imageUrl;
  final String? lottieAsset;
  final List<Color> gradient;

  OnboardingPageData({
    required this.title,
    this.subtitle,
    required this.description,
    required this.icon,
    this.imageUrl,
    this.lottieAsset,
    required this.gradient,
  });
}

