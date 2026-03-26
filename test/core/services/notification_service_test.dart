import 'package:echomirror/core/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'initialize') return true;
          // cancel, zonedSchedule, show, requestPermissionsFromSystem, etc.
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NotificationService', () {
    test('initialize() returns true on success', () async {
      final service = NotificationService();
      final result = await service.initialize();
      expect(result, isTrue);
    });

    test(
      'scheduleDailyReminder() saves hour, minute, and enabled to prefs',
      () async {
        final service = NotificationService();
        await service.scheduleDailyReminder(hour: 9, minute: 30);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('reminder_hour'), 9);
        expect(prefs.getInt('reminder_minute'), 30);
        expect(prefs.getBool('reminder_enabled'), isTrue);
      },
    );

    test('cancelDailyReminder() sets reminder_enabled to false', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_enabled', true);

      final service = NotificationService();
      await service.cancelDailyReminder();

      expect(prefs.getBool('reminder_enabled'), isFalse);
    });

    test('isReminderEnabled() returns false when pref is not set', () async {
      final service = NotificationService();
      final enabled = await service.isReminderEnabled();
      expect(enabled, isFalse);
    });

    test('isReminderEnabled() returns true when pref is set to true', () async {
      SharedPreferences.setMockInitialValues({'reminder_enabled': true});

      final service = NotificationService();
      final enabled = await service.isReminderEnabled();
      expect(enabled, isTrue);
    });

    test(
      'checkAndNotifyIfNoLogToday() skips scheduling when already checked today',
      () async {
        final today = DateTime.now();
        final todayKey = '${today.year}-${today.month}-${today.day}';
        SharedPreferences.setMockInitialValues({
          'last_log_check_date': todayKey,
        });

        final service = NotificationService();
        // Even though hasLoggedToday is false, it should not update anything
        // because last_log_check_date already matches today.
        await service.checkAndNotifyIfNoLogToday(hasLoggedToday: false);

        final prefs = await SharedPreferences.getInstance();
        // Key should remain unchanged (early return before any write).
        expect(prefs.getString('last_log_check_date'), todayKey);
      },
    );

    test(
      'checkAndNotifyIfNoLogToday() records check date when user has not logged',
      () async {
        final service = NotificationService();
        await service.checkAndNotifyIfNoLogToday(hasLoggedToday: false);

        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now();
        final expectedKey = '${today.year}-${today.month}-${today.day}';
        expect(prefs.getString('last_log_check_date'), expectedKey);
      },
    );

    test(
      'checkAndNotifyIfNoLogToday() records check date and cancels notification when user has logged',
      () async {
        final service = NotificationService();
        await service.checkAndNotifyIfNoLogToday(hasLoggedToday: true);

        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now();
        final expectedKey = '${today.year}-${today.month}-${today.day}';
        expect(prefs.getString('last_log_check_date'), expectedKey);
      },
    );
  });
}
