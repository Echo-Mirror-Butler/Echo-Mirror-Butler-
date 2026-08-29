import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';

/// Callback type for triggering a background sync cycle.
typedef SyncCycleCallback = Future<void> Function();

/// Coordinates reliable background sync triggers:
/// - Flapping connectivity defense via debounce
/// - Periodic background timer (WorkManager / BGTaskScheduler fallback)
/// - Exponential backoff retry scheduler
class BackgroundSyncScheduler {
  BackgroundSyncScheduler({
    required this.connectivity,
    Duration debounceDuration = const Duration(milliseconds: 600),
    Duration periodicInterval = const Duration(minutes: 5),
  })  : _debounceDuration = debounceDuration,
        _periodicInterval = periodicInterval;

  final ConnectivityService connectivity;
  final Duration _debounceDuration;
  final Duration _periodicInterval;

  StreamSubscription<bool>? _connectivitySub;
  Timer? _debounceTimer;
  Timer? _periodicTimer;
  Timer? _retryTimer;

  bool _started = false;
  int _consecutiveFailures = 0;
  SyncCycleCallback? _onTriggerSync;

  bool get isRunning => _started;
  int get consecutiveFailures => _consecutiveFailures;

  /// Registers the synchronization trigger callback and starts listening to events.
  Future<void> start(SyncCycleCallback onTriggerSync) async {
    if (_started) return;
    _started = true;
    _onTriggerSync = onTriggerSync;

    // 1. Connectivity change listener with debounce
    _connectivitySub = connectivity.onStatusChange.listen((online) {
      if (online) {
        _scheduleDebouncedSync();
      }
    });

    // 2. Periodic background sync timer
    _periodicTimer = Timer.periodic(_periodicInterval, (_) {
      _triggerSyncNow();
    });

    // 3. Initial check
    if (await connectivity.isConnected()) {
      _triggerSyncNow();
    }
  }

  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      debugPrint('[BackgroundSyncScheduler] Connectivity restored — triggering debounced sync');
      _triggerSyncNow();
    });
  }

  void _triggerSyncNow() {
    final callback = _onTriggerSync;
    if (callback != null) {
      unawaited(callback());
    }
  }

  /// Notifies the scheduler of a sync run outcome.
  /// Schedules exponential backoff if failed, or resets failure count if successful.
  void recordOutcome({required bool success, bool rateLimited = false}) {
    if (success) {
      _consecutiveFailures = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
    } else {
      _consecutiveFailures++;
      final baseDelaySeconds = rateLimited ? 30 : 2;
      final backoffSeconds = (baseDelaySeconds * (1 << (_consecutiveFailures - 1).clamp(0, 5)))
          .clamp(2, 120);

      debugPrint(
        '[BackgroundSyncScheduler] Sync failed (attempt #$_consecutiveFailures); '
        'retrying in ${backoffSeconds}s',
      );

      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: backoffSeconds), () {
        _triggerSyncNow();
      });
    }
  }

  /// Simulates / invokes an OS background task (e.g. WorkManager or BGTaskScheduler callback).
  Future<void> handleOsBackgroundTask() async {
    debugPrint('[BackgroundSyncScheduler] Executing OS background task flush');
    final callback = _onTriggerSync;
    if (callback != null) {
      await callback();
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _started = false;
    _onTriggerSync = null;
  }
}

/// Provider for background sync scheduler.
final backgroundSyncSchedulerProvider = Provider<BackgroundSyncScheduler>((ref) {
  final scheduler = BackgroundSyncScheduler(
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
