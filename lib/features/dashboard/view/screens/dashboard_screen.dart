import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';
import '../../../ai/view/widgets/ai_insight_section.dart';
import '../../../../core/viewmodel/providers/notification_provider.dart';
import '../../../ai/viewmodel/providers/ai_provider.dart';
import '../../../help/view/screens/professional_help_screen.dart';
import '../../data/models/insight_model.dart';
import '../../viewmodel/providers/dashboard_provider.dart';
import '../widgets/insight_section.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/mood_trend_chart.dart';
import '../../viewmodel/providers/mood_chart_provider.dart';

/// Dashboard screen showing insights and predictions
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

    // Mock milestone check - trigger confetti for 7+ insights
    if (insights.length >= 7) {
      _hasCheckedMilestone = true;
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Load logs and insights when we have a user ID
    if (authState.isAuthenticated && authState.user != null) {
      final userId = authState.user!.id;
      // Use addPostFrameCallback to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (userId.isNotEmpty) {
          // Load logs first (needed for analytics and AI insights)
          await ref
              .read(loggingProvider.notifier)
              .loadLogEntries(userId: userId);

          // Check daily log and schedule notification if needed
          ref.read(dailyLogCheckProvider.future);

          // Load insights
          ref
              .read(dashboardProvider.notifier)
              .loadInsights(userId: userId, forceReload: false);

          // Auto-generate AI insights if we have enough logs (after logs are loaded)
          Future.delayed(const Duration(milliseconds: 500), () {
            // Check if widget is still mounted before using ref
            if (!mounted) return;

            final loggingState = ref.read(loggingProvider);
            final logs = loggingState.value ?? [];
            if (logs.length >= 3) {
              final now = DateTime.now();
              final recentLogs =
                  logs
                      .where(
                        (log) => log.date.isAfter(
                          now.subtract(const Duration(days: 14)),
                        ),
                      )
                      .toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

              if (recentLogs.length >= 3) {
                // Check if insight already exists
                if (!mounted) return;
                final aiState = ref.read(aiInsightProvider);
                if (aiState.value == null) {
                  if (!mounted) return;
                  // Auto-generate insight
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
          // Need Help? button
          IconButton(
            icon: const Icon(FontAwesomeIcons.handHoldingHeart),
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
          dashboardState.when(
            data: (insights) {
              if (insights.isEmpty) {
                return _buildEmptyState(context, theme, ref);
              }

              // Check milestones and trigger confetti
              _checkMilestones(insights);

              // Group insights by type
              final predictions =
                  insights
                      .where((i) => i.type == InsightType.prediction)
                      .toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

              final habits =
                  insights.where((i) => i.type == InsightType.habit).toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

              final moods =
                  insights.where((i) => i.type == InsightType.mood).toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

              final general =
                  insights.where((i) => i.type == InsightType.general).toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

              return RefreshIndicator(
                onRefresh: () async {
                  if (authState.isAuthenticated && authState.user != null) {
                    await ref
                        .read(dashboardProvider.notifier)
                        .loadInsights(
                          userId: authState.user!.id,
                          forceReload: true,
                        );
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats section
                      DashboardStats(insights: insights),
                      const SizedBox(height: 8),
                      // Mood Trend Chart
                      MoodTrendChart(
                        recentLogs: ref.watch(moodChartDataProvider),
                      ),
                      const SizedBox(height: 8),
                      // AI Insights section
                      const AiInsightSection(),
                      const SizedBox(height: 8),
                      // Mood Analytics card
                      _buildMoodAnalyticsCard(context, theme),
                      const SizedBox(height: 8),

                      // Predictions section
                      InsightSection(
                        title: 'Predictions',
                        insights: predictions,
                        icon: FontAwesomeIcons.wandMagicSparkles,
                        color: AppTheme.secondaryColor,
                      ),

                      // Habits section
                      InsightSection(
                        title: 'Habits',
                        insights: habits,
                        icon: FontAwesomeIcons.repeat,
                        color: AppTheme.primaryColor,
                      ),

                      // Moods section
                      InsightSection(
                        title: 'Mood Insights',
                        insights: moods,
                        icon: FontAwesomeIcons.faceSmile,
                        color: AppTheme.accentColor,
                        onInsightTap: (insight) =>
                            _handleInsightTap(context, ref, insight),
                      ),

                      // General insights section
                      if (general.isNotEmpty)
                        InsightSection(
                          title: 'General Insights',
                          insights: general,
                          icon: FontAwesomeIcons.lightbulb,
                          color: AppTheme.primaryColor,
                        ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
            loading: () =>
                const Center(child: ShimmerLoading(width: 40, height: 40)),
            error: (error, stack) =>
                _buildErrorState(context, theme, error, ref),
          ),
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2, // Down
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      colors: [AppTheme.accentColor, AppTheme.primaryColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.chartLine,
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
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  FontAwesomeIcons.chevronRight,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
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
  ) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  FontAwesomeIcons.chartLine,
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
                'Start logging your daily activities, moods, and habits to see personalized insights and AI-powered predictions generated by Gemini.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Navigate directly to create entry screen
                      context.push('/logging/create');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            FontAwesomeIcons.pen,
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

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
    Object error,
    WidgetRef ref,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.triangleExclamation,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading insights',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                final authState = ref.read(authProvider);
                if (authState.isAuthenticated && authState.user != null) {
                  ref
                      .read(dashboardProvider.notifier)
                      .loadInsights(userId: authState.user!.id);
                }
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                'Retry',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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

    // For mood insights that reference a specific date, try to find and navigate to that log entry
    if (insight.type == InsightType.mood) {
      try {
        // Get log entries from provider
        final loggingState = ref.read(loggingProvider);
        final entries = loggingState.value ?? [];

        if (entries.isEmpty) {
          // No entries loaded, try to load them first
          await ref
              .read(loggingProvider.notifier)
              .loadLogEntries(userId: authState.user!.id);
          // Wait a bit for the load to complete
          await Future.delayed(const Duration(milliseconds: 300));
          final updatedState = ref.read(loggingProvider);
          final updatedEntries = updatedState.value ?? [];
          if (updatedEntries.isEmpty) {
            throw Exception('No entries available');
          }
        }

        // Find entry for the insight date
        final insightDate = DateTime(
          insight.date.year,
          insight.date.month,
          insight.date.day,
        );
        final currentEntries = ref.read(loggingProvider).value ?? [];

        final matchingEntry = currentEntries.firstWhere((entry) {
          final localDate = entry.date.isUtc
              ? entry.date.toLocal()
              : entry.date;
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
        // If entry not found, show a message with option to create entry
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No log entry found for ${DateFormatter.formatDate(insight.date)}. '
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
