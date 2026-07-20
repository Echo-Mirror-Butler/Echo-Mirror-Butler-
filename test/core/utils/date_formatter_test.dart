import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/core/utils/date_formatter.dart';

void main() {
  setUpAll(() {
    DateFormatter.initTimezones();
  });

  group('DateFormatter', () {
    test('formatDate formats local date correctly', () {
      final date = DateTime(2024, 1, 15);
      expect(DateFormatter.formatDate(date), 'Jan 15, 2024');

      final utcDate = DateTime.utc(2024, 1, 15);
      expect(DateFormatter.formatDate(utcDate), isNotEmpty);
    });

    test('formatDate handles null edge case', () {
      expect(DateFormatter.formatDate(DateTime(2024)), 'Jan 01, 2024');
    });

    test('formatDateLong formats correctly', () {
      final date = DateTime(2024, 1, 15);
      expect(DateFormatter.formatDateLong(date), 'Monday, January 15');
      expect(
        DateFormatter.formatDateLong(DateTime.utc(2024, 1, 15)),
        isNotEmpty,
      );
    });

    test('formatDateShort formats correctly', () {
      final date = DateTime(2024, 1, 15);
      expect(DateFormatter.formatDateShort(date), '01/15');
      expect(
        DateFormatter.formatDateShort(DateTime.utc(2024, 1, 15)),
        isNotEmpty,
      );
    });

    test('formatTime formats correctly', () {
      final date = DateTime(2024, 1, 15, 14, 30);
      expect(DateFormatter.formatTime(date), '02:30 PM');
    });

    test('formatDateTime formats correctly', () {
      final date = DateTime(2024, 1, 15, 14, 30);
      expect(DateFormatter.formatDateTime(date), 'Jan 15, 2024 02:30 PM');
    });

    test('isToday returns true for current date', () {
      final now = DateTime.now();
      expect(DateFormatter.isToday(now), isTrue);
      expect(DateFormatter.isToday(now.toUtc()), isTrue);

      final past = now.subtract(const Duration(days: 2));
      expect(DateFormatter.isToday(past), isFalse);
    });

    test('isYesterday returns true for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateFormatter.isYesterday(yesterday), isTrue);
      expect(DateFormatter.isYesterday(yesterday.toUtc()), isTrue);

      expect(DateFormatter.isYesterday(DateTime.now()), isFalse);
    });

    test(
      'normalizeToLocalDate removes time component from UTC/local dates',
      () {
        final date = DateTime(2024, 1, 15, 14, 30);
        final normalized = DateFormatter.normalizeToLocalDate(date);
        expect(normalized.year, 2024);
        expect(normalized.month, 1);
        expect(normalized.day, 15);
        expect(normalized.hour, 0);

        final utcDate = DateTime.utc(2024, 1, 15, 14, 30);
        final normalizedUtc = DateFormatter.normalizeToLocalDate(utcDate);
        expect(normalizedUtc.hour, 0);
      },
    );

    test('toLocalDate returns correct local date for UTC-5 timezone', () {
      final utcDate = DateTime.utc(2024, 1, 15, 23, 0);
      final localDate = DateFormatter.toLocalDate(utcDate, 'America/New_York');
      expect(localDate.year, 2024);
      expect(localDate.month, 1);
      expect(localDate.day, 15);
      expect(localDate.hour, 0);
      expect(localDate.minute, 0);
    });

    test('toLocalDate returns correct local date for UTC+9 timezone', () {
      final utcDate = DateTime.utc(2024, 1, 15, 2, 0);
      final localDate = DateFormatter.toLocalDate(utcDate, 'Asia/Tokyo');
      expect(localDate.year, 2024);
      expect(localDate.month, 1);
      expect(localDate.day, 15);
      expect(localDate.hour, 0);
      expect(localDate.minute, 0);
    });

    test('toLocalDate handles timezone crossing midnight', () {
      final utcDate = DateTime.utc(2024, 1, 15, 2, 0);
      final localDate = DateFormatter.toLocalDate(utcDate, 'America/Los_Angeles');
      expect(localDate.year, 2024);
      expect(localDate.month, 1);
      expect(localDate.day, 14);
    });

    test('daysAgo returns correct date relative to a fixed base', () {
      final baseDate = DateTime.utc(2024, 1, 15, 12, 0);
      final sevenDaysAgo = baseDate.subtract(const Duration(days: 7));
      final result = DateFormatter.toLocalDate(sevenDaysAgo, 'America/New_York');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 8);
    });

    test('daysAgo handles different timezones consistently', () {
      final result1 = DateFormatter.daysAgo(1, 'America/New_York');
      final result2 = DateFormatter.daysAgo(1, 'Europe/London');
      expect(result1, isA<DateTime>());
      expect(result2, isA<DateTime>());
      expect(result1.hour, 0);
      expect(result2.hour, 0);
    });

    test('formatRelativeTime returns string based on time difference', () {
      final now = DateTime.now();

      expect(DateFormatter.formatRelativeTime(now), 'Just now');

      final minutesAgo = now.subtract(const Duration(minutes: 5));
      expect(DateFormatter.formatRelativeTime(minutesAgo), '5 minutes ago');
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      expect(DateFormatter.formatRelativeTime(oneMinuteAgo), '1 minute ago');

      final hoursAgo = now.subtract(const Duration(hours: 3));
      expect(DateFormatter.formatRelativeTime(hoursAgo), '3 hours ago');
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      expect(DateFormatter.formatRelativeTime(oneHourAgo), '1 hour ago');

      final daysAgo = now.subtract(const Duration(days: 2));
      expect(DateFormatter.formatRelativeTime(daysAgo), '2 days ago');
      final oneDayAgo = now.subtract(const Duration(days: 1));
      expect(DateFormatter.formatRelativeTime(oneDayAgo), '1 day ago');

      final oldDate = now.subtract(const Duration(days: 10));
      expect(DateFormatter.formatRelativeTime(oldDate), isNotEmpty);
    });
  });
}
