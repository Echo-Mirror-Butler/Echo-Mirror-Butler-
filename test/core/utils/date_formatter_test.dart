import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    test('formatDate formats local date correctly', () {
      final date = DateTime(2024, 1, 15);
      expect(DateFormatter.formatDate(date), 'Jan 15, 2024');
      
      final utcDate = DateTime.utc(2024, 1, 15);
      expect(DateFormatter.formatDate(utcDate), isNotEmpty);
    });

    test('formatDateLong formats correctly', () {
      final date = DateTime(2024, 1, 15); 
      expect(DateFormatter.formatDateLong(date), 'Monday, January 15');
      expect(DateFormatter.formatDateLong(DateTime.utc(2024, 1, 15)), isNotEmpty);
    });

    test('formatDateShort formats correctly', () {
      final date = DateTime(2024, 1, 15);
      expect(DateFormatter.formatDateShort(date), '01/15');
      expect(DateFormatter.formatDateShort(DateTime.utc(2024, 1, 15)), isNotEmpty);
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

    test('normalizeToLocalDate removes time component from UTC/local dates', () {
      final date = DateTime(2024, 1, 15, 14, 30);
      final normalized = DateFormatter.normalizeToLocalDate(date);
      expect(normalized.year, 2024);
      expect(normalized.month, 1);
      expect(normalized.day, 15);
      expect(normalized.hour, 0);
      
      final utcDate = DateTime.utc(2024, 1, 15, 14, 30);
      final normalizedUtc = DateFormatter.normalizeToLocalDate(utcDate);
      expect(normalizedUtc.hour, 0);
    });

    test('formatRelativeTime returns string based on time difference', () {
      final now = DateTime.now();
      
      // Just now
      expect(DateFormatter.formatRelativeTime(now), 'Just now');
      
      // Minutes
      final minutesAgo = now.subtract(const Duration(minutes: 5));
      expect(DateFormatter.formatRelativeTime(minutesAgo), '5 minutes ago');
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      expect(DateFormatter.formatRelativeTime(oneMinuteAgo), '1 minute ago');
      
      // Hours
      final hoursAgo = now.subtract(const Duration(hours: 3));
      expect(DateFormatter.formatRelativeTime(hoursAgo), '3 hours ago');
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      expect(DateFormatter.formatRelativeTime(oneHourAgo), '1 hour ago');
      
      // Days
      final daysAgo = now.subtract(const Duration(days: 2));
      expect(DateFormatter.formatRelativeTime(daysAgo), '2 days ago');
      final oneDayAgo = now.subtract(const Duration(days: 1));
      expect(DateFormatter.formatRelativeTime(oneDayAgo), '1 day ago');
      
      // More than 7 days falls back to string format
      final oldDate = now.subtract(const Duration(days: 10));
      expect(DateFormatter.formatRelativeTime(oldDate), isNotEmpty);
    });
  });
}
