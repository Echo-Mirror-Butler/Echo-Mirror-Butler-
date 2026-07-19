import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/widgets/no_connection_widget.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';
import '../../../ai/view/widgets/ai_insight_section.dart';
import '../../../../core/viewmodel/providers/notification_provider.dart';
import '../../../ai/viewmodel/providers/ai_provider.dart';
import '../../../help/view/screens/professional_help_screen.dart';
import '../../data/models/insight_model.dart';
import '../../viewmodel/providers/dashboard_provider.dart';
import '../../viewmodel/providers/streak_provider.dart';
import '../../viewmodel/providers/echo_balance_provider.dart';
import '../widgets/insight_section.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/mood_streak_card.dart';
import '../widgets/mood_trend_chart.dart';
import '../widgets/echo_balance_card.dart';
import '../../viewmodel/providers/mood_chart_provider.dart';
import '../../viewmodel/providers/has_logged_today_provider.dart';
import '../widgets/quick_check_in_widget.dart';
import '../widgets/daily_log_status_banner.dart';

/// Dashboard screen showing insights and predictions.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late ConfettiController _confettiController;
  bool _hasCheckedMilestone = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _checkMilestones(List<InsightModel> insights) {
    if (_hasCheckedMilestone) return;
    if (insights.length >= 7) {
      _hasCheckedMilestone = true;
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final authState = ref.watch(authProvider);
    final streakState = ref.watch(streakProvider);
    final hasLoggedToday = ref.watch(hasLoggedTodayProvider);
    final theme = Theme.of(context);

    if (authState.isAuthenticated && authState.user != null) {
      final userId = authState.user!.id;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (userId.isNotEmpty) {
          await ref
              .read(loggingProvider.notifier)
              .loadLogEntries(userId: userId);

          ref.read(dailyLogCheckProvider.future);

          ref
              .read(dashboardProvider.notifier)
              .loadInsights(userId: userId, forceReload: false);

          ref.read(streakProvider.notifier).loadStreak(userId);

          ref.read(echoBalanceProvider.notifier).loadBalance(userId);

          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;

            final loggingState = ref.read(loggingProvider);
            final logs = loggingState.value ?? [];

            if (logs.length >= 3) {
              final now = DateTime.now();
              final recentLogs = logs
                  .where(
                    (log) => log.date.isAfter(
                      now.subtract(const Duration(days: 14)),
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              if (recentLogs.length >= 3) {
                if (!mounted) return;

                final aiState = ref.read(aiInsightProvider);
                if (aiState.value == null) {
                  if (!mounted) return;
                  ref
                      .read(aiInsightProvider.notifier)
                      .generateInsight(recentLogs);
                }
              }
            }
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(FontAwesomeIcons.handHoldingHeart.data),
            tooltip: 'Need Help?',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfessionalHelpScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async {
              if (authState.isAuthenticated && authState.user != null) {
                ref.invalidate(dashboardProvider);
                ref.invalidate(streakProvider);
                ref.invalidate(echoBalanceProvider);
                ref.invalidate(moodChartDataProvider);
                ref.invalidate(dailyLogCheckProvider);

                await ref.read(dashboardProvider.notifier).loadInsights(
                      userId: authState.user!.id,
                      forceReload: true,
                    );
              }
            },
            child: dashboardState.when(
              data: (insights) {
                if (insights.isEmpty) {
                  return _buildEmptyState(
                    context,
                    theme,
                    ref,
                    hasLoggedToday,
                  );
                }

                _checkMilestones(insights);

                final predictions = insights
                    .where((i) => i.type == InsightType.prediction)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                final habits = insights
                    .where((i) => i.type == InsightType.habit)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                final moods = insights
                    .where((i) => i.type == InsightType.mood)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                final general = insights
                    .where((i) => i.type == InsightType.general)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasLoggedToday)
                        const DailyLogStatusBanner()
                      else
                        const QuickCheckInWidget(),
                      const SizedBox(height: 8),
                      DashboardStats(insights: insights),
                      const SizedBox(height: 8),
                      MoodStreakCard(
                        streak: streakState.currentStreak,
                      ),
                      const SizedBox(height: 8),
                      if (authState.isAuthenticated &&
                          authState.user != null)
                        EchoBalanceCard(userId: authState.user!.id),
                      const SizedBox(height: 8),
                      MoodTrendChart(
                        recentLogs: ref.watch(moodChartDataProvider),
                      ),
                      const SizedBox(height: 8),
                      const AiInsightSection(),
                      const SizedBox(height: 8),
                      _buildMoodAnalyticsCard(context, theme),
                      const SizedBox(height: 8),
                      InsightSection(
                        title: 'Predictions',
                        insights: predictions,
                        icon: FontAwesomeIcons
                            .wandMagicSparkles.data,
                        color: AppTheme.secondaryColor,
                      ),
                      InsightSection(
                        title: 'Habits',
                        insights: habits,
                        icon: FontAwesomeIcons.repeat.data,
                        color: AppTheme.primaryColor,
                      ),
                      InsightSection(
                        title: 'Mood Insights',
                        insights: moods,
                        icon: FontAwesomeIcons.faceSmile.data,
                        color: AppTheme.accentColor,
                        onInsightTap: (insight) =>
                            _handleInsightTap(context, ref, insight),
                      ),
                      if (general.isNotEmpty)
                        InsightSection(
                          title: 'General Insights',
                          insights: general,
                          icon: FontAwesomeIcons.lightbulb.data,
                          color: AppTheme.primaryColor,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
              loading: () =>
                  const Center(child: ShimmerLoading(width: 40, height: 40)),
              error: (error, stack) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: NoConnectionWidget(
                      onRetry: () => ref.refresh(dashboardProvider),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                AppTheme.accentColor,
                AppTheme.successColor,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodAnalyticsCard(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => context.push('/dashboard/mood-analytics'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accentColor,
                        AppTheme.primaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    FontAwesomeIcons.chartLine.data,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood Analytics',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View trends, statistics, and insights',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  FontAwesomeIcons.chevronRight.data,
                  size: 16,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    bool hasLoggedToday,
  ) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasLoggedToday)
                const DailyLogStatusBanner()
              else
                const QuickCheckInWidget(),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor
                          .withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  FontAwesomeIcons.chartLine.data,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No insights yet',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Start logging your daily activities, moods, and habits '
                'to see personalized insights and AI-powered predictions '
                'generated by Gemini.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.6),
                  height: 1.6,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/logging/create'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FontAwesomeIcons.pen.data,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Start Logging',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInsightTap(
    BuildContext context,
    WidgetRef ref,
    InsightModel insight,
  ) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || authState.user == null) return;

    if (insight.type == InsightType.mood) {
      try {
        final loggingState = ref.read(loggingProvider);
        final entries = loggingState.value ?? [];

        if (entries.isEmpty) {
          await ref
              .read(loggingProvider.notifier)
              .loadLogEntries(userId: authState.user!.id);

          await Future.delayed(const Duration(milliseconds: 300));

          final updatedState = ref.read(loggingProvider);
          final updatedEntries = updatedState.value ?? [];

          if (updatedEntries.isEmpty) {
            throw Exception('No entries available');
          }
        }

        final insightDate = DateTime(
          insight.date.year,
          insight.date.month,
          insight.date.day,
        );

        final currentEntries = ref.read(loggingProvider).value ?? [];

        final matchingEntry = currentEntries.firstWhere((entry) {
          final localDate =
              entry.date.isUtc ? entry.date.toLocal() : entry.date;
          final entryDate = DateTime(
            localDate.year,
            localDate.month,
            localDate.day,
          );
          return entryDate.isAtSameMomentAs(insightDate);
        });

        if (context.mounted) {
          context.push(
            '/logging/detail/${matchingEntry.id}',
            extra: matchingEntry,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No log entry found for '
                '${DateFormatter.formatDate(insight.date)}. '
                'Would you like to create one?',
              ),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Create Entry',
                onPressed: () => context.push('/logging/create'),
              ),
            ),
          );
        }
      }
    }
  }
}
