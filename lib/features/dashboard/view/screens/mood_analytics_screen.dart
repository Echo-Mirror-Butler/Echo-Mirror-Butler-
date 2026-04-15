import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';
import '../../data/models/mood_analytics_model.dart';
import '../widgets/mood_chart_widget.dart';
import '../widgets/mood_stats_widget.dart';

/// Screen displaying mood analytics with charts and statistics
class MoodAnalyticsScreen extends ConsumerWidget {
  const MoodAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggingState = ref.watch(loggingProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Load log entries when we have a user ID
    if (authState.isAuthenticated && authState.user != null) {
      final userId = authState.user!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (userId.isNotEmpty) {
          ref.read(loggingProvider.notifier).loadLogEntries(userId: userId);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mood Analytics')),
      body: loggingState.when(
        data: (entries) {
          // Filter entries with mood data
          final moodEntries = entries
              .where((e) => e.mood != null)
              .map(
                (e) => MoodEntry(
                  date: e.date.isUtc ? e.date.toLocal() : e.date,
                  mood: e.mood,
                ),
              )
              .toList();

          if (moodEntries.isEmpty) {
            return _buildEmptyState(context, theme);
          }

          // Calculate analytics
          final analytics = MoodAnalyticsModel.fromEntries(moodEntries);

          return RefreshIndicator(
            onRefresh: () async {
              if (authState.isAuthenticated && authState.user != null) {
                await ref
                    .read(loggingProvider.notifier)
                    .loadLogEntries(userId: authState.user!.id);
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Statistics
                  MoodStatsWidget(analytics: analytics),
                  const SizedBox(height: 8),
                  // Weekly trend
                  MoodChartWidget(
                    dataPoints: analytics.weeklyTrend,
                    title: 'Weekly Mood Trend',
                    isWeekly: true,
                  ),
                  // Monthly trend
                  MoodChartWidget(
                    dataPoints: analytics.monthlyTrend,
                    title: 'Monthly Mood Trend',
                    isWeekly: false,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
        loading: () =>
            const Center(child: ShimmerLoading(width: 40, height: 40)),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading mood data',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
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
                    colors: [AppTheme.accentColor, AppTheme.primaryColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  FontAwesomeIcons.chartLine,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No mood data yet',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Start logging your daily mood to see analytics, trends, and insights.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.6,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
