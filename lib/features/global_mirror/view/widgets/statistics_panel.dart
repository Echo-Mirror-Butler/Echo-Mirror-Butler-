import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../data/models/mood_pin_model.dart';
import '../../../../core/themes/app_theme.dart';

class StatisticsPanel extends StatelessWidget {
  final List<MoodPinModel> pins;
  final bool isMobile;

  const StatisticsPanel({
    super.key,
    required this.pins,
    this.isMobile = false,
  });

  Map<String, int> _getSentimentCounts() {
    final counts = <String, int>{};
    for (final pin in pins) {
      final sentiment = _normalizeSentiment(pin.sentiment);
      counts[sentiment] = (counts[sentiment] ?? 0) + 1;
    }
    return counts;
  }

  String _normalizeSentiment(String sentiment) {
    final lower = sentiment.toLowerCase();
    if (lower.contains('positive') || lower.contains('happy') || lower.contains('excited')) {
      return 'Happy';
    } else if (lower.contains('calm') || lower.contains('grateful')) {
      return 'Calm';
    } else if (lower.contains('stress')) {
      return 'Stressed';
    } else if (lower.contains('anx')) {
      return 'Anxious';
    } else if (lower.contains('sad') || lower.contains('negative')) {
      return 'Sad';
    }
    return 'Neutral';
  }

  String _getDominantMood() {
    if (pins.isEmpty) return '😐 No data';
    
    final counts = _getSentimentCounts();
    final dominant = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    final emoji = {
      'Happy': '😊',
      'Calm': '😌',
      'Stressed': '😰',
      'Anxious': '😟',
      'Sad': '😢',
      'Neutral': '😐',
    }[dominant.key] ?? '😐';
    
    return '$emoji ${dominant.key} is trending worldwide';
  }

  String _getMostActiveRegion() {
    if (pins.isEmpty) return 'No activity';

    final regions = <String, int>{};
    for (final pin in pins) {
      final region = _getRegionFromLatLon(pin.gridLat, pin.gridLon);
      regions[region] = (regions[region] ?? 0) + 1;
    }

    final mostActive = regions.entries.reduce((a, b) => a.value > b.value ? a : b);
    return mostActive.key;
  }

  String _getRegionFromLatLon(double lat, double lon) {
    if (lat > 71) return 'Arctic';
    if (lat > 60) {
      if (lon < -30) return 'Northern America / Greenland';
      if (lon < 45) return 'Northern Europe';
      return 'Northern Asia';
    }
    if (lat > 35) {
      if (lon < -100) return 'Western North America';
      if (lon < -30) return 'Eastern North America';
      if (lon < 45) return 'Europe';
      if (lon < 100) return 'Central Asia';
      return 'East Asia';
    }
    if (lat > 23.5) {
      if (lon < -100) return 'Mexico / Central America';
      if (lon < -30) return 'North Atlantic / Caribbean';
      if (lon < 35) return 'North Africa / Middle East';
      if (lon < 80) return 'South Asia';
      return 'Southeast Asia';
    }
    if (lat > 0) {
      if (lon < -80) return 'Northern South America';
      if (lon < -30) return 'Brazil / Eastern South America';
      if (lon < 20) return 'West Africa';
      if (lon < 60) return 'East Africa';
      if (lon < 120) return 'Southeast Asia / Indonesia';
      return 'Oceania / Pacific';
    }
    if (lat > -23.5) {
      if (lon < -80) return 'Southern Tropical South America';
      if (lon < -30) return 'Southern Brazil / Atlantic';
      if (lon < 20) return 'Central Africa';
      if (lon < 60) return 'Southern Africa';
      if (lon < 140) return 'Australia / Oceania';
      return 'South Pacific';
    }
    if (lat > -35) {
      if (lon < -70) return 'Southern South America';
      if (lon < 20) return 'Southern Africa';
      if (lon < 140) return 'Southern Australia';
      return 'New Zealand / South Pacific';
    }
    if (lat > -60) return 'Subantarctic';
    return 'Antarctica';
  }

  int _getLiveUsersCount() {
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    return pins.where((pin) => pin.timestamp.isAfter(fiveMinutesAgo)).length;
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment) {
      case 'Happy':
        return Colors.green;
      case 'Calm':
        return Colors.blue;
      case 'Stressed':
        return Colors.orange;
      case 'Anxious':
        return Colors.red.shade300;
      case 'Sad':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPins = pins.length;
    final liveUsers = _getLiveUsersCount();
    final dominantMood = _getDominantMood();
    final mostActiveRegion = _getMostActiveRegion();
    final sentimentCounts = _getSentimentCounts();

    if (isMobile) {
      return FadeInDown(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatItem(
                  label: 'Total Pins',
                  value: totalPins.toString(),
                  icon: Icons.push_pin,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: 'Live Now',
                  value: liveUsers.toString(),
                  icon: Icons.person,
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: 'Trending',
                  value: dominantMood.split(' ').first,
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: 'Active',
                  value: mostActiveRegion,
                  icon: Icons.public,
                  color: Colors.blue,
                  isWide: true,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Desktop layout
    return FadeInDown(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stats row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatCard(
                  label: 'Total Pins',
                  value: totalPins.toString(),
                  icon: Icons.push_pin,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  label: 'Live Users',
                  value: liveUsers.toString(),
                  icon: Icons.person,
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  label: 'Most Active',
                  value: mostActiveRegion,
                  icon: Icons.public,
                  color: Colors.blue,
                  isWide: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Global mood
            Text(
              'Global Mood',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dominantMood,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            // Sentiment breakdown chart
            if (pins.isNotEmpty) ...[
              Text(
                'Mood Distribution',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              _SentimentBreakdownChart(
                sentimentCounts: sentimentCounts,
                total: totalPins,
                getSentimentColor: _getSentimentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isWide;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(minWidth: isWide ? 140 : 100),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isWide;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

class _SentimentBreakdownChart extends StatelessWidget {
  final Map<String, int> sentimentCounts;
  final int total;
  final Color Function(String) getSentimentColor;

  const _SentimentBreakdownChart({
    required this.sentimentCounts,
    required this.total,
    required this.getSentimentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: sentimentCounts.entries.map((entry) {
        final percentage = (entry.value / total * 100).round();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: getSentimentColor(entry.key),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entry.value / total,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(getSentimentColor(entry.key)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
