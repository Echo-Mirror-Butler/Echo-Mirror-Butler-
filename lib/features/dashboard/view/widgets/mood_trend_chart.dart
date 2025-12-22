import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// Beautiful mood trend chart widget
class MoodTrendChart extends StatelessWidget {
  final List<LogEntryModel> recentLogs;
  final int daysToShow;

  const MoodTrendChart({
    super.key,
    required this.recentLogs,
    this.daysToShow = 30,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filter logs with mood values and sort by date
    final logsWithMood = recentLogs
        .where((log) => log.mood != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (logsWithMood.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    // Prepare chart data
    final chartData = _prepareChartData(logsWithMood);
    
    if (chartData.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    return Card(
      elevation: 4,
      shadowColor: AppTheme.primaryColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              AppTheme.primaryColor.withOpacity(0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
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
                  child: const Icon(
                    FontAwesomeIcons.chartLine,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Mood Journey',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Chart
            SizedBox(
              height: 220,
              child: LineChart(
                _buildLineChartData(chartData, theme),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            _buildLegend(theme),
          ],
        ),
      ),
    );
  }

  List<ChartDataPoint> _prepareChartData(List<LogEntryModel> logs) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysToShow));
    final dataPoints = <ChartDataPoint>[];

    // Create a map of date to log entry for quick lookup
    final logMap = <DateTime, LogEntryModel>{};
    for (final log in logs) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      logMap[logDate] = log;
    }

    // Generate data points for the last N days
    for (int i = daysToShow - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final normalizedDate = DateTime(date.year, date.month, date.day);

      if (normalizedDate.isBefore(startDate)) continue;

      final log = logMap[normalizedDate];
      if (log != null && log.mood != null) {
        dataPoints.add(ChartDataPoint(
          date: normalizedDate,
          mood: log.mood!,
          note: log.notes,
        ));
      }
    }

    return dataPoints;
  }

  LineChartData _buildLineChartData(
    List<ChartDataPoint> dataPoints,
    ThemeData theme,
  ) {
    if (dataPoints.isEmpty) {
      return LineChartData();
    }

    final spots = dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.mood.toDouble());
    }).toList();

    final minY = 0.5;
    final maxY = 5.5;
    final minX = 0.0;
    final maxX = (dataPoints.length - 1).toDouble();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppTheme.primaryColor.withOpacity(0.1),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: _calculateInterval(dataPoints.length),
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < dataPoints.length) {
                final date = dataPoints[value.toInt()].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormatter.formatDateShort(date),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value >= 1 && value <= 5) {
                return Text(
                  value.toInt().toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AppTheme.primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withOpacity(0.3),
                AppTheme.secondaryColor.withOpacity(0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index >= 0 && index < dataPoints.length) {
                final point = dataPoints[index];
                final noteSnippet = point.note != null && point.note!.isNotEmpty
                    ? (point.note!.length > 30
                        ? '${point.note!.substring(0, 30)}...'
                        : point.note!)
                    : 'No note';
                return LineTooltipItem(
                  '${DateFormatter.formatDate(point.date)}\n'
                  'Mood: ${point.mood}/5\n'
                  '$noteSnippet',
                  GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }
              return null;
            }).toList();
          },
          tooltipRoundedRadius: 12,
          tooltipPadding: const EdgeInsets.all(12),
          tooltipMargin: 8,
        ),
        handleBuiltInTouches: true,
      ),
    );
  }

  double _calculateInterval(int dataPointsCount) {
    if (dataPointsCount <= 7) return 1;
    if (dataPointsCount <= 14) return 2;
    if (dataPointsCount <= 30) return 5;
    return 7;
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Mood Trend (Last $daysToShow days)',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 4,
      shadowColor: AppTheme.primaryColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              AppTheme.primaryColor.withOpacity(0.02),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(
              FontAwesomeIcons.chartLine,
              size: 48,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Log more days to see your growth trend',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Data point for chart
class ChartDataPoint {
  final DateTime date;
  final int mood;
  final String? note;

  const ChartDataPoint({
    required this.date,
    required this.mood,
    this.note,
  });
}

