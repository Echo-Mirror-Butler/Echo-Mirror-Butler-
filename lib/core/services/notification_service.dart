import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification IDs
  static const int _dailyReminderId = 1;
  static const int _eveningCheckInId = 2;
  static const int _inactiveNudgeId = 3;
  static const int _noLogTodayId = 4;
  static const int _activeSessionId = 5;
  static const int _scheduledSessionBaseId = 1000; // Base ID for scheduled sessions
  static const String _logNowActionId = 'log_now';
  static const String _snoozeActionId = 'snooze';
  static const String _joinSessionActionId = 'join_session';

  // SharedPreferences keys
  static const String _keyReminderEnabled = 'reminder_enabled';
  static const String _keyReminderHour = 'reminder_hour';
  static const String _keyReminderMinute = 'reminder_minute';
  static const String _keyLastLogCheckDate = 'last_log_check_date';
  static const String _keyLastActiveSessionNotification = 'last_active_session_notification';

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      final locationName = tz.local.name;
      tz.setLocalLocation(tz.getLocation(locationName));

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Initialization settings
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize plugin
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      if (initialized == true) {
        // Request permissions (iOS)
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosImplementation = _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>();
          if (iosImplementation != null) {
            await iosImplementation.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
          }
        }

        // Request permissions (Android 13+)
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidImplementation = _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          if (androidImplementation != null) {
            await androidImplementation.requestNotificationsPermission();
          }
        }

        _initialized = true;
        debugPrint('[NotificationService] Initialized successfully');
        return true;
      }

      debugPrint('[NotificationService] Failed to initialize');
      return false;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
      return false;
    }
  }

  /// Handle notification tap/action
  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint('[NotificationService] Notification response: ${response.id}, action: ${response.actionId}');

    // Handle actions
    if (response.actionId == _logNowActionId) {
      // Navigate to logging screen
      _navigateToLogging();
    } else if (response.actionId == _snoozeActionId) {
      // Snooze for 1 hour
      _snoozeReminder();
    } else if (response.actionId == _joinSessionActionId) {
      // Navigate to socials screen
      _navigateToSocials();
    } else if (response.id == _dailyReminderId || 
               response.id == _eveningCheckInId || 
               response.id == _noLogTodayId) {
      // Regular tap on logging-related notifications
      _navigateToLogging();
    } else if (response.id == _activeSessionId) {
      // Navigate to socials for active session notifications
      _navigateToSocials();
    } else if (response.payload != null && response.payload!.startsWith('scheduled_session:')) {
      // Navigate to socials for scheduled session notifications
      _navigateToSocials();
    }
  }

  /// Navigate to logging screen
  void _navigateToLogging() {
    // This will be set by the app router
    // For now, we'll use a callback pattern
    if (_onNotificationTap != null) {
      _onNotificationTap!();
    }
  }

  /// Navigate to socials screen
  void _navigateToSocials() {
    if (_onSocialsNotificationTap != null) {
      _onSocialsNotificationTap!();
    } else if (_onNotificationTap != null) {
      // Fallback to main navigation if socials callback not set
      _onNotificationTap!();
    }
  }

  /// Snooze reminder for 1 hour
  Future<void> _snoozeReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    final snoozeTime = now.add(const Duration(hours: 1));

    await _scheduleNotification(
      id: _dailyReminderId + 1000, // Use different ID for snooze
      scheduledDate: snoozeTime,
      title: 'Reminder: Time to Reflect',
      body: 'Your future self is still waiting 🌟',
    );

    debugPrint('[NotificationService] Snoozed until ${snoozeTime.toString()}');
  }

  /// Callback for notification tap (set by app)
  VoidCallback? _onNotificationTap;
  VoidCallback? _onSocialsNotificationTap;

  /// Set callback for notification tap (logging)
  void setNotificationTapCallback(VoidCallback callback) {
    _onNotificationTap = callback;
  }

  /// Set callback for socials notification tap
  void setSocialsNotificationTapCallback(VoidCallback callback) {
    _onSocialsNotificationTap = callback;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImplementation = _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosImplementation != null) {
          final result = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return result ?? false;
        }
        return false;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final result = await androidImplementation.requestNotificationsPermission();
          return result ?? false;
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Permission request error: $e');
      return false;
    }
  }

  /// Schedule daily reminder notification
  Future<void> scheduleDailyReminder({
    int hour = 20,
    int minute = 0,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel existing reminder
    await cancelDailyReminder();

    // Save reminder time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);
    await prefs.setBool(_keyReminderEnabled, true);

    // Calculate next occurrence
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Schedule notification
    await _scheduleNotification(
      id: _dailyReminderId,
      scheduledDate: scheduledDate,
      title: 'Time to Reflect',
      body: 'Hey, your future self wants to hear from you today 🌟',
      repeatDaily: true,
    );

    debugPrint('[NotificationService] Scheduled daily reminder at ${hour}:${minute.toString().padLeft(2, '0')}');
  }

  /// Schedule a notification
  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String title,
    required String body,
    bool repeatDaily = false,
  }) async {
    // Android notification details
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reflection Reminders',
      channelDescription: 'Notifications to remind you to log your daily reflections',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(
          _logNowActionId,
          'Log Now',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _snoozeActionId,
          'Snooze',
        ),
      ],
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'daily_reminder',
      interruptionLevel: InterruptionLevel.active,
    );

    // Notification details
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule notification
    if (repeatDaily) {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancel daily reminder
  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(_dailyReminderId);
    
    // Cancel any snoozed reminders
    for (int i = 1001; i <= 1010; i++) {
      await _notifications.cancel(i);
    }

    // Update preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderEnabled, false);

    debugPrint('[NotificationService] Cancelled daily reminder');
  }

  /// Check if reminder is enabled
  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyReminderEnabled) ?? false;
  }

  /// Get reminder time
  Future<({int hour, int minute})> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyReminderHour) ?? 20;
    final minute = prefs.getInt(_keyReminderMinute) ?? 0;
    return (hour: hour, minute: minute);
  }

  /// Reschedule reminder (called on app open)
  Future<void> rescheduleIfNeeded() async {
    if (!_initialized) {
      await initialize();
    }

    final isEnabled = await isReminderEnabled();
    if (isEnabled) {
      final time = await getReminderTime();
      await scheduleDailyReminder(hour: time.hour, minute: time.minute);
    }
    
    // Schedule evening check-in (9 PM default)
    await scheduleEveningCheckIn();
  }

  /// Schedule daily evening check-in notification
  Future<void> scheduleEveningCheckIn({
    int hour = 21,
    int minute = 0,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Calculate next occurrence
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Schedule notification
    await _scheduleNotification(
      id: _eveningCheckInId,
      scheduledDate: scheduledDate,
      title: 'Your future self is checking in',
      body: 'How was your day today? 🌟',
      repeatDaily: true,
    );

    debugPrint('[NotificationService] Scheduled evening check-in at ${hour}:${minute.toString().padLeft(2, '0')}');
  }

  /// Schedule inactive nudge (2+ days without logs)
  /// This should be called when app detects no logs for 2+ days
  Future<void> scheduleInactiveNudge({
    String? geminiMessage,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Schedule for tomorrow at 10 AM
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      10,
      0,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final message = geminiMessage ?? 
        'Hey, future you here—I noticed you haven\'t logged in a while. Let\'s reconnect and see how you\'re doing.';

    await _scheduleNotification(
      id: _inactiveNudgeId,
      scheduledDate: scheduledDate,
      title: 'We miss you!',
      body: message,
      repeatDaily: false,
    );

    debugPrint('[NotificationService] Scheduled inactive nudge');
  }

  /// Cancel inactive nudge
  Future<void> cancelInactiveNudge() async {
    await _notifications.cancel(_inactiveNudgeId);
    debugPrint('[NotificationService] Cancelled inactive nudge');
  }

  // ===== SCHEDULED SESSION NOTIFICATIONS =====

  /// Schedule notification for a video session
  Future<void> scheduleSessionNotification({
    required int sessionId,
    required String sessionTitle,
    required String hostName,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Schedule notification 5 minutes before the session
    final notificationTime = scheduledTime.subtract(const Duration(minutes: 5));
    final now = DateTime.now();

    // Don't schedule if notification time has already passed
    if (notificationTime.isBefore(now)) {
      debugPrint('[NotificationService] Session notification time has passed');
      return;
    }

    final scheduledDate = tz.TZDateTime.from(notificationTime, tz.local);
    
    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'scheduled_sessions_channel',
      'Scheduled Video Sessions',
      channelDescription: 'Notifications for upcoming video call sessions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.event,
      actions: [
        AndroidNotificationAction(
          _joinSessionActionId,
          'Join Now',
          showsUserInterface: true,
        ),
      ],
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'scheduled_session',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    // Notification details
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use session ID offset from base ID
    final notificationId = _scheduledSessionBaseId + sessionId;

    await _notifications.zonedSchedule(
      notificationId,
      'Video Session Starting Soon 📹',
      '"$sessionTitle" with $hostName starts in 5 minutes',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'scheduled_session:$sessionId',
    );

    debugPrint('[NotificationService] Scheduled session notification for session $sessionId at $scheduledDate');
  }

  /// Cancel scheduled session notification
  Future<void> cancelSessionNotification(int sessionId) async {
    final notificationId = _scheduledSessionBaseId + sessionId;
    await _notifications.cancel(notificationId);
    debugPrint('[NotificationService] Cancelled session notification for session $sessionId');
  }

  /// Show immediate notification for session starting now
  Future<void> showSessionStartingNowNotification({
    required int sessionId,
    required String sessionTitle,
    required String hostName,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'scheduled_sessions_channel',
      'Scheduled Video Sessions',
      channelDescription: 'Notifications for upcoming video call sessions',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.call,
      actions: [
        AndroidNotificationAction(
          _joinSessionActionId,
          'Join Now',
          showsUserInterface: true,
        ),
      ],
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'scheduled_session',
      interruptionLevel: InterruptionLevel.critical,
    );

    // Notification details
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = _scheduledSessionBaseId + sessionId;

    await _notifications.show(
      notificationId,
      'Video Session Starting Now! 🎥',
      '"$sessionTitle" with $hostName is starting',
      notificationDetails,
      payload: 'scheduled_session:$sessionId',
    );

    debugPrint('[NotificationService] Showed immediate notification for session $sessionId');
  }

  // ===== DAILY LOG CHECK NOTIFICATIONS =====

  /// Check if user has logged today and schedule notification if not
  /// This should be called daily, preferably in the afternoon (e.g., 2 PM)
  Future<void> checkAndNotifyIfNoLogToday({
    required bool hasLoggedToday,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final lastCheckDate = prefs.getString(_keyLastLogCheckDate);

    // Only check once per day
    if (lastCheckDate == todayKey) {
      return;
    }

    // If user hasn't logged today, schedule a reminder for later today (e.g., 6 PM)
    if (!hasLoggedToday) {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        18, // 6 PM
        0,
      );

      // If 6 PM has passed, schedule for tomorrow at 2 PM
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        scheduledDate = tz.TZDateTime(
          tz.local,
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          14, // 2 PM
          0,
        );
      }

      await _scheduleNotification(
        id: _noLogTodayId,
        scheduledDate: scheduledDate,
        title: 'Don\'t forget to log your day 📝',
        body: 'Your future self is waiting to hear about today. Take a moment to reflect! 🌟',
        repeatDaily: false,
      );

      // Mark that we've checked today
      await prefs.setString(_keyLastLogCheckDate, todayKey);
      debugPrint('[NotificationService] Scheduled no-log reminder for ${scheduledDate.toString()}');
    } else {
      // User has logged, cancel any pending no-log notifications
      await _notifications.cancel(_noLogTodayId);
      await prefs.setString(_keyLastLogCheckDate, todayKey);
      debugPrint('[NotificationService] User has logged today, no reminder needed');
    }
  }

  /// Cancel no-log-today notification
  Future<void> cancelNoLogTodayNotification() async {
    await _notifications.cancel(_noLogTodayId);
    debugPrint('[NotificationService] Cancelled no-log-today notification');
  }

  // ===== ACTIVE SESSION NOTIFICATIONS =====

  /// Notify user when there's an active session available
  /// This should be called when active sessions are detected
  Future<void> notifyActiveSessionAvailable({
    required String sessionTitle,
    required String hostName,
    required int participantCount,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final sessionKey = '$sessionTitle-$hostName';
    final lastNotification = prefs.getString(_keyLastActiveSessionNotification);

    // Don't spam notifications - only notify once per unique session per hour
    if (lastNotification != null) {
      final parts = lastNotification.split('|');
      if (parts.length == 2) {
        final lastSessionKey = parts[0];
        final lastNotificationTime = DateTime.tryParse(parts[1]);
        if (lastSessionKey == sessionKey && 
            lastNotificationTime != null &&
            now.difference(lastNotificationTime).inHours < 1) {
          debugPrint('[NotificationService] Active session notification already sent recently');
          return;
        }
      }
    }

    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'active_sessions_channel',
      'Active Video Sessions',
      channelDescription: 'Notifications when active video sessions are available',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.event,
      actions: [
        AndroidNotificationAction(
          _joinSessionActionId,
          'Join Session',
          showsUserInterface: true,
        ),
      ],
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'active_session',
      interruptionLevel: InterruptionLevel.active,
    );

    // Notification details
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final participantText = participantCount == 1 
        ? '1 person' 
        : '$participantCount people';

    await _notifications.show(
      _activeSessionId,
      'Active Session Available! 🎥',
      '"$sessionTitle" with $hostName - $participantText online',
      notificationDetails,
      payload: 'active_session:$sessionTitle',
    );

    // Save notification timestamp
    await prefs.setString(
      _keyLastActiveSessionNotification,
      '$sessionKey|${now.toIso8601String()}',
    );

    debugPrint('[NotificationService] Notified about active session: $sessionTitle');
  }

  /// Cancel active session notification
  Future<void> cancelActiveSessionNotification() async {
    await _notifications.cancel(_activeSessionId);
    debugPrint('[NotificationService] Cancelled active session notification');
  }
}


