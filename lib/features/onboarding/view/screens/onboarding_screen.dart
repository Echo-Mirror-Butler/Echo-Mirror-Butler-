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
import '../../../../core/services/notification_service.dart';
import '../../viewmodel/providers/onboarding_provider.dart';

// ─── Step indices ────────────────────────────────────────────────────────────
// 0 - Welcome + habit presets
// 1 - Feature carousel
// 2 - Reminder time picker
// 3 - Intro pages (3 slides, handled inside _IntroPages)

const _kHabitPresets = [
  'Morning meditation',
  'Exercise',
  'Journaling',
  'Reading',
  'Hydration',
  'Gratitude',
  'Healthy eating',
  'Sleep by 10pm',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 0 — habit presets
  final Set<String> _selectedHabits = {};
  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Meet EchoMirror',
      subtitle: 'Your Future Self as a Butler',
      description:
          'A personal growth assistant that helps you reflect, track your journey, and receive insights from your future self.',
      icon: FontAwesomeIcons.userTie.data,
      imageUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80',
      lottieAsset: LottieAnimations.mirrorReflection,
      gradient: [AppTheme.primaryColor, AppTheme.secondaryColor],
    ),
    OnboardingPageData(
      title: 'Log Daily Moods & Habits',
      description:
          'Capture your daily reflections, track your mood, and build meaningful habits. Your journey starts with a single entry.',
      icon: FontAwesomeIcons.book.data,
      imageUrl:
          'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800&q=80',
      lottieAsset: LottieAnimations.habitCheck,
      gradient: [AppTheme.secondaryColor, AppTheme.accentColor],
    ),
    OnboardingPageData(
      title: 'Receive Predictions & Letters',
      description:
          'Get AI-powered insights about your patterns, predictions for your future, and motivational letters from your future self.',
      icon: FontAwesomeIcons.envelopeOpen.data,
      imageUrl:
          'https://images.unsplash.com/photo-1516534775068-ba3e7458af70?w=800&q=80',
      lottieAsset: LottieAnimations.envelopeOpen,
      gradient: [AppTheme.accentColor, AppTheme.primaryColor],
    ),
  ];

  // Step 2 — reminder time
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _permissionDenied = false;

  static const int _totalSteps = 3; // welcome, features, reminder

  Future<void> _completeOnboarding() async {
    try {
      await saveHabitPresets(_selectedHabits.toList());
      await markOnboardingCompleted();
      ref.invalidate(onboardingCompletedProvider);
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) context.go('/login');
    } catch (e) {
      debugPrint('[OnboardingScreen] Error: $e');
      if (mounted) context.go('/login');
    }
  }

  Future<void> _requestReminderPermission() async {
    final svc = NotificationService();
    await svc.initialize();
    final granted = await svc.requestPermissions();
    if (granted) {
      await svc.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
      setState(() => _permissionDenied = false);
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  void _next() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previous() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _currentPage == _totalSteps - 1;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Skip
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  'Skip',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),

            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _WelcomeStep(
                  selectedHabits: _selectedHabits,
                  onToggle: (h) => setState(() {
                    if (_selectedHabits.contains(h)) {
                      _selectedHabits.remove(h);
                    } else if (_selectedHabits.length < 3) {
                      _selectedHabits.add(h);
                    }
                  }),
                ),
                _FeatureCarouselStep(onSkip: _next),
                _ReminderStep(
                  reminderTime: _reminderTime,
                  permissionDenied: _permissionDenied,
                  onTimeChanged: (t) => setState(() => _reminderTime = t),
                  onRequestPermission: _requestReminderPermission,
                ),
              ],
            ),

            // Bottom nav
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _totalSteps,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppTheme.primaryColor,
                      dotColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.2),
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 4,
                      spacing: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          TextButton(
                            onPressed: _previous,
                            child: Text(
                              'Previous',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 80),
                        ElevatedButton(
                          onPressed: _next,
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
                                isLast ? 'Start Reflecting' : 'Next',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLast
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

// ─── Step 0: Welcome + Habit Presets ─────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  final Set<String> selectedHabits;
  final void Function(String) onToggle;

  const _WelcomeStep({
    required this.selectedHabits,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                FontAwesomeIcons.userTie,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Meet EchoMirror',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            'Your Future Self as a Butler',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A personal growth assistant that helps you reflect, track your journey, and receive insights from your future self.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Pick 2–3 habits to track',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These will be pre-selected on your first log.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kHabitPresets.map((habit) {
              final selected = selectedHabits.contains(habit);
              return GestureDetector(
                onTap: () => onToggle(habit),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryColor
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryColor
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        const Icon(
                          FontAwesomeIcons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        habit,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (selectedHabits.length >= 3)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Max 3 selected. Tap one to deselect.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Step 1: Feature Carousel ─────────────────────────────────────────────────

class _FeatureCarouselStep extends StatefulWidget {
  final VoidCallback onSkip;
  const _FeatureCarouselStep({required this.onSkip});

  @override
  State<_FeatureCarouselStep> createState() => _FeatureCarouselStepState();
}

class _FeatureCarouselStepState extends State<_FeatureCarouselStep> {
  final PageController _cardController = PageController(viewportFraction: 0.85);
  int _cardIndex = 0;

  static const _cards = [
    _FeatureCard(
      icon: FontAwesomeIcons.faceSmile,
      title: 'Log your mood daily',
      description: 'Takes just 2 minutes — capture how you feel and what matters.',
      gradient: [Color(0xFF6D5CE8), Color(0xFF8B5CF6)],
    ),
    _FeatureCard(
      icon: FontAwesomeIcons.star,
      title: 'Earn ECHO tokens on Stellar',
      description: 'Stay consistent and earn crypto rewards for your growth journey.',
      gradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
    _FeatureCard(
      icon: FontAwesomeIcons.lightbulb,
      title: 'Unlock AI insights',
      description: 'After just 3 logs, your future self starts sending insights.',
      gradient: [Color(0xFFEC4899), Color(0xFF6D5CE8)],
    ),
  ];

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 80, 0, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'What you\'ll get',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Swipe to explore the key features',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _cardController,
              itemCount: _cards.length,
              onPageChanged: (i) => setState(() => _cardIndex = i),
              itemBuilder: (context, i) {
                final card = _cards[i];
                return AnimatedScale(
                  scale: _cardIndex == i ? 1.0 : 0.92,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: card.gradient,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: card.gradient.first.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              card.icon,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            card.title,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            card.description,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Card dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_cards.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _cardIndex == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _cardIndex == i
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

// ─── Step 2: Reminder Time Picker ────────────────────────────────────────────

class _ReminderStep extends StatelessWidget {
  final TimeOfDay reminderTime;
  final bool permissionDenied;
  final void Function(TimeOfDay) onTimeChanged;
  final VoidCallback onRequestPermission;

  const _ReminderStep({
    required this.reminderTime,
    required this.permissionDenied,
    required this.onTimeChanged,
    required this.onRequestPermission,
  });

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.accentColor, AppTheme.primaryColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              FontAwesomeIcons.bell,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Set your daily reminder',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll nudge you to log your mood at this time every day.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          // Time display + picker button
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: reminderTime,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppTheme.primaryColor,
                        ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) onTimeChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    FontAwesomeIcons.clock,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(reminderTime),
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    FontAwesomeIcons.penToSquare,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Permission button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRequestPermission,
              icon: const Icon(FontAwesomeIcons.bell, size: 16),
              label: Text(
                'Enable Reminders',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (permissionDenied) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.circleInfo,
                    color: AppTheme.accentColor,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can enable reminders later in Settings.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
