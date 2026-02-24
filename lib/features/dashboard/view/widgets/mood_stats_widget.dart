import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/themes/app_theme.dart';
import '../../data/models/mood_analytics_model.dart';

/// Widget displaying mood statistics
class MoodStatsWidget extends StatelessWidget {
  final MoodAnalyticsModel analytics;

  const MoodStatsWidget({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (analytics.totalEntries == 0) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No mood data available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FontAwesomeIcons.chartBar,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Mood Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Average Mood',
                    value: analytics.averageMood.toStringAsFixed(1),
                    icon: FontAwesomeIcons.chartLine,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                if (analytics.weeklyAverage != null)
                  Expanded(
                    child: _StatCard(
                      label: 'Weekly Avg',
                      value: analytics.weeklyAverage!.toStringAsFixed(1),
                      icon: FontAwesomeIcons.calendarWeek,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
              ],
            ),
            if (analytics.weeklyAverage != null) const SizedBox(height: 12),
            if (analytics.bestMoodDay != null || analytics.worstMoodDay != null)
              Row(
                children: [
                  if (analytics.bestMoodDay != null)
                    Expanded(
                      child: _StatCard(
                        label: 'Best Mood',
                        value: analytics.bestMoodDay.toString(),
                        icon: FontAwesomeIcons.faceGrinStars,
                        color: Colors.green,
                      ),
                    ),
                  if (analytics.bestMoodDay != null &&
                      analytics.worstMoodDay != null)
                    const SizedBox(width: 12),
                  if (analytics.worstMoodDay != null)
                    Expanded(
                      child: _StatCard(
                        label: 'Lowest Mood',
                        value: analytics.worstMoodDay.toString(),
                        icon: FontAwesomeIcons.faceFrown,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Text(
              'Mood Distribution',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildDistributionChart(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionChart(ThemeData theme) {
    if (analytics.moodDistribution.isEmpty) {
      return Text(
        'No distribution data',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      );
    }

    final maxCount = analytics.moodDistribution.values.reduce(
      (a, b) => a > b ? a : b,
    );

    return Column(
      children: [1, 2, 3, 4, 5].map((mood) {
        final count = analytics.moodDistribution[mood] ?? 0;
        final percentage = maxCount > 0 ? (count / maxCount) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '$mood',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getMoodColor(mood),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getMoodColor(int mood) {
    switch (mood) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
