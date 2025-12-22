import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/ai_insight_model.dart';
import '../../viewmodel/providers/ai_provider.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import 'future_letter_card.dart';
import 'prediction_card.dart';
import 'suggestions_list.dart';
import 'stress_detection_card.dart';

/// Section widget that displays AI insights on the dashboard
class AiInsightSection extends ConsumerWidget {
  const AiInsightSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(aiInsightProvider);
    final loggingState = ref.watch(loggingProvider);
    final theme = Theme.of(context);

    // Listen for insight changes and auto-navigate to breathing exercise when stress is detected
    ref.listen<AsyncValue<AiInsightModel?>>(aiInsightProvider, (previous, next) {
      // Only trigger when we transition from loading/error/null to a valid insight with stress
      if (previous?.value == null && next.value != null) {
        final insight = next.value!;
        debugPrint(
          '[AiInsightSection] 📊 Insight generated - stressLevel: ${insight.stressLevel}',
        );
        
        if (insight.stressLevel != null && insight.stressLevel! >= 3) {
          // Small delay to let the UI render first
          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              debugPrint(
                '[AiInsightSection] 🧘 Auto-navigating to breathing exercise (stress level: ${insight.stressLevel})',
              );
              context.push('/breathing');
            }
          });
        } else if (insight.stressLevel == null) {
          debugPrint(
            '[AiInsightSection] ⚠️ Warning: Gemini did not return stressLevel. Server-side code may need to calculate stress from logs.',
          );
        }
      }
    });

    // Auto-generate insights when logs are available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final logs = loggingState.value ?? [];
        if (logs.length >= 3 && aiState.value == null && !aiState.isLoading) {
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
            // Wrap in try-catch to prevent crashes
            ref
                .read(aiInsightProvider.notifier)
                .generateInsight(recentLogs)
                .catchError((error) {
                  debugPrint(
                    '[AiInsightSection] Error generating insight: $error',
                  );
                  // Error is already handled by the provider, just log it
                });
          }
        }
      } catch (e) {
        debugPrint('[AiInsightSection] Error in auto-generate callback: $e');
        // Don't crash, just log the error
      }
    });

    return aiState.when(
      data: (insight) {
        if (insight == null) {
          return _buildPlaceholder(context, theme, ref);
        }
        return _buildInsightContent(context, theme, ref, insight);
      },
      loading: () => _buildLoadingState(context, theme),
      error: (error, stack) => _buildErrorState(context, theme, ref, error),
    );
  }

  Widget _buildInsightContent(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    AiInsightModel insight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with refresh button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  FontAwesomeIcons.wandMagicSparkles,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Insights',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(FontAwesomeIcons.arrowsRotate),
                onPressed: () => _refreshInsight(ref),
                tooltip: 'Refresh Insight',
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stress detection card (shown if stress level >= 3)
        StressDetectionCard(insight: insight),
        // Prediction card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PredictionCard(insight: insight),
        ),
        const SizedBox(height: 12),
        // Suggestions list
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SuggestionsList(insight: insight),
        ),
        const SizedBox(height: 12),
        // Future letter card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureLetterCard(insight: insight),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final loggingState = ref.read(loggingProvider);
    final logs = loggingState.value ?? [];

    // Show placeholder if we have less than 3 logs
    if (logs.length < 3) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  FontAwesomeIcons.wandMagicSparkles,
                  size: 48,
                  color: AppTheme.primaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'AI Insights Coming Soon',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Log at least 3 entries to receive personalized AI insights, predictions, and habit suggestions powered by Gemini AI.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show shimmer/loading placeholder if we have enough logs but no insight yet
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const ShimmerLoading(
                width: 40,
                height: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Generating Insights...',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _refreshInsight(ref),
                child: const Text('Generate Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const ShimmerLoading(
                width: 40,
                height: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Generating AI Insights with Gemini...',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
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
    WidgetRef ref,
    Object error,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation,
                size: 48,
                color: AppTheme.errorColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to Generate AI Insights',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gemini AI is currently unavailable. Please check your connection and try again.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _refreshInsight(ref),
                icon: const Icon(FontAwesomeIcons.arrowsRotate),
                label: const Text('Retry with Gemini'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshInsight(WidgetRef ref) {
    if (!ref.read(authProvider).isAuthenticated ||
        ref.read(authProvider).user == null) {
      return;
    }

    final loggingState = ref.read(loggingProvider);
    final logs = loggingState.value ?? [];

    if (logs.length >= 3) {
      // Get recent logs (last 7-14 days)
      final now = DateTime.now();
      final recentLogs =
          logs
              .where(
                (log) =>
                    log.date.isAfter(now.subtract(const Duration(days: 14))),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      if (recentLogs.length >= 3) {
        ref.read(aiInsightProvider.notifier).generateInsight(recentLogs);
      }
    }
  }
}
