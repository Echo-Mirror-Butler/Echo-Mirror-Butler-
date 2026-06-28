import '../../../logging/data/models/log_entry_model.dart';
import '../../../../core/utils/date_formatter.dart';

/// Model for mood analytics calculations
class MoodAnalyticsModel {
  final double averageMood;
  final Map<int, int> moodDistribution; // mood value -> count
  final List<MoodDataPoint> weeklyTrend; // Last 7 days
  final List<MoodDataPoint> monthlyTrend; // Last 30 days
  final int totalEntries;
  final int? bestMoodDay; // Best mood value
  final int? worstMoodDay; // Worst mood value
  final double? weeklyAverage;
  final double? monthlyAverage;

  const MoodAnalyticsModel({
    required this.averageMood,
    required this.moodDistribution,
    required this.weeklyTrend,
    required this.monthlyTrend,
    required this.totalEntries,
    this.bestMoodDay,
    this.worstMoodDay,
    this.weeklyAverage,
    this.monthlyAverage,
  });

  /// Compute streak from log entries
  static int computeStreak(
    List<LogEntryModel> entries, {
    DateTime? referenceDate,
    String timezone = 'UTC',
  }) {
    if (entries.isEmpty) return 0;

    final refDate = referenceDate ?? DateFormatter.daysAgo(0, timezone);
    final ref = DateTime(refDate.year, refDate.month, refDate.day);

    // Get unique dates with non-null mood, normalized to midnight
    final uniqueDates = entries
        .where((e) => e.mood != null)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();

    if (!uniqueDates.contains(ref)) return 0;

    int streak = 1;
    var currentDay = ref.subtract(const Duration(days: 1));
    while (uniqueDates.contains(currentDay)) {
      streak++;
      currentDay = currentDay.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Create analytics from log entries
  factory MoodAnalyticsModel.fromEntries(List<MoodEntry> entries, {String timezone = 'UTC'}) {
    if (entries.isEmpty) {
      return const MoodAnalyticsModel(
        averageMood: 0,
        moodDistribution: {},
        weeklyTrend: [],
        monthlyTrend: [],
        totalEntries: 0,
      );
    }

    // Calculate average mood
    final moodsWithValues = entries.where((e) => e.mood != null).toList();
    final average = moodsWithValues.isEmpty
        ? 0.0
        : moodsWithValues.map((e) => e.mood!).reduce((a, b) => a + b) /
              moodsWithValues.length;

    // Calculate mood distribution
    final distribution = <int, int>{};
    for (final entry in moodsWithValues) {
      distribution[entry.mood!] = (distribution[entry.mood!] ?? 0) + 1;
    }

    // Calculate trends
    final now = DateFormatter.daysAgo(0, timezone);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Weekly trend (last 7 days)
    final weeklyEntries =
        entries
            .where(
              (e) =>
                  e.date.isAfter(sevenDaysAgo) ||
                  e.date.isAtSameMomentAs(sevenDaysAgo),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final weeklyTrend = _calculateTrend(weeklyEntries, 7, timezone: timezone);

    // Monthly trend (last 30 days)
    final monthlyEntries =
        entries
            .where(
              (e) =>
                  e.date.isAfter(thirtyDaysAgo) ||
                  e.date.isAtSameMomentAs(thirtyDaysAgo),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final monthlyTrend = _calculateTrend(monthlyEntries, 30, timezone: timezone);

    // Calculate weekly and monthly averages
    final weeklyMoods = weeklyEntries
        .where((e) => e.mood != null)
        .map((e) => e.mood!)
        .toList();
    final monthlyMoods = monthlyEntries
        .where((e) => e.mood != null)
        .map((e) => e.mood!)
        .toList();

    final weeklyAvg = weeklyMoods.isEmpty
        ? null
        : weeklyMoods.reduce((a, b) => a + b) / weeklyMoods.length;
    final monthlyAvg = monthlyMoods.isEmpty
        ? null
        : monthlyMoods.reduce((a, b) => a + b) / monthlyMoods.length;

    // Find best and worst mood days
    int? bestMood;
    int? worstMood;
    if (moodsWithValues.isNotEmpty) {
      bestMood = moodsWithValues
          .map((e) => e.mood!)
          .reduce((a, b) => a > b ? a : b);
      worstMood = moodsWithValues
          .map((e) => e.mood!)
          .reduce((a, b) => a < b ? a : b);
    }

    return MoodAnalyticsModel(
      averageMood: average,
      moodDistribution: distribution,
      weeklyTrend: weeklyTrend,
      monthlyTrend: monthlyTrend,
      totalEntries: entries.length,
      bestMoodDay: bestMood,
      worstMoodDay: worstMood,
      weeklyAverage: weeklyAvg,
      monthlyAverage: monthlyAvg,
    );
  }

  /// Calculate trend data points for a given period
  static List<MoodDataPoint> _calculateTrend(
    List<MoodEntry> entries,
    int days, {
    String timezone = 'UTC',
  }) {
    final trend = <MoodDataPoint>[];
    final today = DateFormatter.daysAgo(0, timezone);

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      final normalizedDate = DateTime(date.year, date.month, date.day);

      // Find entry for this date
      final entry = entries.firstWhere((e) {
        final entryDate = DateTime(e.date.year, e.date.month, e.date.day);
        return entryDate.isAtSameMomentAs(normalizedDate);
      }, orElse: () => MoodEntry(date: normalizedDate, mood: null));

      trend.add(MoodDataPoint(date: normalizedDate, mood: entry.mood));
    }

    return trend;
  }
}

/// Data point for mood charts
class MoodDataPoint {
  final DateTime date;
  final int? mood;

  const MoodDataPoint({required this.date, this.mood});
}

/// Entry with mood value for analytics
class MoodEntry {
  final DateTime date;
  final int? mood;

  const MoodEntry({required this.date, this.mood});
}
