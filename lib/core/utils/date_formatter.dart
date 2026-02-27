import 'package:intl/intl.dart';

/// Utility class for date formatting
class DateFormatter {
  DateFormatter._();

  /// Format date as "MMM dd, yyyy" (e.g., "Jan 15, 2024")
  /// Normalizes to local date to avoid timezone issues
  static String formatDate(DateTime date) {
    // Convert to local time first to get the correct date
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateFormat('MMM dd, yyyy').format(localDate);
  }

  /// Format date as "EEEE, MMMM dd" (e.g., "Monday, January 15")
  /// Normalizes to local date to avoid timezone issues
  static String formatDateLong(DateTime date) {
    // Convert to local time first to get the correct date
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateFormat('EEEE, MMMM dd').format(localDate);
  }

  /// Format date as "MM/dd/yyyy" (e.g., "01/15/2024")
  /// Normalizes to local date to avoid timezone issues
  static String formatDateShort(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateFormat('MM/dd').format(localDate);
  }

  /// Format time as "hh:mm a" (e.g., "02:30 PM")
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  /// Format date and time together
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  /// Check if date is today
  /// Normalizes dates to local time for comparison
  static bool isToday(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final now = DateTime.now();
    return localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;
  }

  /// Check if date is yesterday
  /// Normalizes dates to local time for comparison
  static bool isYesterday(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return localDate.year == yesterday.year &&
        localDate.month == yesterday.month &&
        localDate.day == yesterday.day;
  }

  /// Normalize a date to local date (year, month, day) for comparison
  /// This helps avoid timezone issues when comparing dates
  static DateTime normalizeToLocalDate(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  /// Format relative time (e.g., "2 hours ago")
  static String formatRelativeTime(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays > 7) {
      return formatDate(date);
    } else if (duration.inDays >= 1) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'} ago';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (duration.inMinutes >= 1) {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}
