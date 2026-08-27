import 'package:echomirror/core/services/notification_permission_service.dart';
import 'package:echomirror/core/viewmodel/providers/notification_permission_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Channel mock helpers ─────────────────────────────────────────────────────

// permission_handler communicates over a MethodChannel.  We intercept it to
// control what status the OS "returns" without hitting real platform code.
const _permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

/// Stubs the permission_handler channel so that
/// [Permission.notification.status] returns [status] and
/// [Permission.notification.request()] returns [requestResult].
void _stubPermission(
  PermissionStatus status, {
  PermissionStatus? requestResult,
  bool openSettingsResult = true,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_permissionChannel, (MethodCall call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return status.index;
      case 'requestPermissions':
        // encodePermissions() sends call.arguments as a plain List<int> of
        // permission codes directly — not wrapped in a map. Returns a map
        // of permission.value → status.index (Permission.notification.value
        // is 14 as of permission_handler 11.x).
        final List<dynamic> permissions = (call.arguments as List?) ?? [];
        return {for (final p in permissions) p: (requestResult ?? status).index};
      case 'openAppSettings':
        return openSettingsResult;
      default:
        return null;
    }
  });
}

void _clearPermissionStub() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_permissionChannel, null);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearPermissionStub);

  // ── NotificationPermissionService ──────────────────────────────────────────

  group('NotificationPermissionService', () {
    late NotificationPermissionService service;

    setUp(() {
      service = NotificationPermissionService();
    });

    test('checkPermissionStatus() returns granted when OS is granted', () async {
      _stubPermission(PermissionStatus.granted);
      final result = await service.checkPermissionStatus();
      expect(result, NotificationPermissionStatus.granted);
    });

    test('checkPermissionStatus() returns denied when OS is denied', () async {
      _stubPermission(PermissionStatus.denied);
      final result = await service.checkPermissionStatus();
      expect(result, NotificationPermissionStatus.denied);
    });

    test(
      'checkPermissionStatus() returns permanentlyDenied when OS is permanentlyDenied',
      () async {
        _stubPermission(PermissionStatus.permanentlyDenied);
        final result = await service.checkPermissionStatus();
        expect(result, NotificationPermissionStatus.permanentlyDenied);
      },
    );

    test('checkPermissionStatus() returns restricted for PermissionStatus.restricted', () async {
      _stubPermission(PermissionStatus.restricted);
      final result = await service.checkPermissionStatus();
      expect(result, NotificationPermissionStatus.restricted);
    });

    test('checkPermissionStatus() maps provisional to granted', () async {
      _stubPermission(PermissionStatus.provisional);
      final result = await service.checkPermissionStatus();
      expect(result, NotificationPermissionStatus.granted);
    });

    test('checkPermissionStatus() maps limited to granted', () async {
      _stubPermission(PermissionStatus.limited);
      final result = await service.checkPermissionStatus();
      expect(result, NotificationPermissionStatus.granted);
    });

    test(
      'requestPermission() returns granted after successful request',
      () async {
        _stubPermission(
          PermissionStatus.denied,
          requestResult: PermissionStatus.granted,
        );
        final result = await service.requestPermission();
        expect(result, NotificationPermissionStatus.granted);
      },
    );

    test(
      'requestPermission() returns denied when user rejects',
      () async {
        _stubPermission(
          PermissionStatus.denied,
          requestResult: PermissionStatus.denied,
        );
        final result = await service.requestPermission();
        expect(result, NotificationPermissionStatus.denied);
      },
    );

    test(
      'requestPermission() returns immediately if already granted',
      () async {
        _stubPermission(PermissionStatus.granted);
        // No request should be made — just the status check.
        final result = await service.requestPermission();
        expect(result, NotificationPermissionStatus.granted);
      },
    );

    test(
      'requestPermission() opens OS settings when permanently denied',
      () async {
        // Status starts as permanentlyDenied; after "settings" it becomes granted.
        int checkCount = 0;
        bool openSettingsCalled = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_permissionChannel, (MethodCall call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              checkCount++;
              // First check → permanentlyDenied, second check (post-settings) → granted.
              return checkCount == 1
                  ? PermissionStatus.permanentlyDenied.index
                  : PermissionStatus.granted.index;
            case 'openAppSettings':
              openSettingsCalled = true;
              return true;
            default:
              return null;
          }
        });

        final result = await service.requestPermission();
        expect(openSettingsCalled, isTrue);
        expect(result, NotificationPermissionStatus.granted);
      },
    );

    test('isPermissionGranted() returns true when granted', () async {
      _stubPermission(PermissionStatus.granted);
      expect(await service.isPermissionGranted(), isTrue);
    });

    test('isPermissionGranted() returns false when denied', () async {
      _stubPermission(PermissionStatus.denied);
      expect(await service.isPermissionGranted(), isFalse);
    });

    test('openOsAppSettings() returns true on success', () async {
      _stubPermission(PermissionStatus.granted, openSettingsResult: true);
      final opened = await service.openOsAppSettings();
      expect(opened, isTrue);
    });
  });

  // ── NotificationPermissionNotifier ────────────────────────────────────────

  group('NotificationPermissionNotifier', () {
    ProviderContainer makeContainer(PermissionStatus stubStatus) {
      _stubPermission(stubStatus);
      return ProviderContainer(
        overrides: [
          notificationPermissionServiceProvider
              .overrideWith((_) => NotificationPermissionService()),
        ],
      );
    }

    test('initial state reflects OS permission (granted)', () async {
      final container = makeContainer(PermissionStatus.granted);
      addTearDown(container.dispose);

      // Await the initial async build.
      final result = await container
          .read(notificationPermissionProvider.future);

      expect(result, NotificationPermissionStatus.granted);
    });

    test('initial state reflects OS permission (denied)', () async {
      final container = makeContainer(PermissionStatus.denied);
      addTearDown(container.dispose);

      final result = await container
          .read(notificationPermissionProvider.future);

      expect(result, NotificationPermissionStatus.denied);
    });

    test('initial state reflects OS permission (permanentlyDenied)', () async {
      final container = makeContainer(PermissionStatus.permanentlyDenied);
      addTearDown(container.dispose);

      final result = await container
          .read(notificationPermissionProvider.future);

      expect(result, NotificationPermissionStatus.permanentlyDenied);
    });

    test('refresh() re-queries and updates state', () async {
      int checkCount = 0;
      // First check → denied; subsequent → granted (simulates user going to
      // OS settings and toggling permission on).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permissionChannel, (MethodCall call) async {
        if (call.method == 'checkPermissionStatus') {
          checkCount++;
          return checkCount == 1
              ? PermissionStatus.denied.index
              : PermissionStatus.granted.index;
        }
        return null;
      });

      final container = ProviderContainer(
        overrides: [
          notificationPermissionServiceProvider
              .overrideWith((_) => NotificationPermissionService()),
        ],
      );
      addTearDown(container.dispose);

      // First build → denied.
      final initial = await container
          .read(notificationPermissionProvider.future);
      expect(initial, NotificationPermissionStatus.denied);

      // Manually refresh — simulates returning from OS settings.
      await container
          .read(notificationPermissionProvider.notifier)
          .refresh();

      final updated = await container
          .read(notificationPermissionProvider.future);
      expect(updated, NotificationPermissionStatus.granted);
    });

    test('requestPermission() transitions state from denied to granted', () async {
      _stubPermission(
        PermissionStatus.denied,
        requestResult: PermissionStatus.granted,
      );

      final container = ProviderContainer(
        overrides: [
          notificationPermissionServiceProvider
              .overrideWith((_) => NotificationPermissionService()),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial build.
      await container.read(notificationPermissionProvider.future);

      // Request permission.
      await container
          .read(notificationPermissionProvider.notifier)
          .requestPermission();

      final result = await container
          .read(notificationPermissionProvider.future);
      expect(result, NotificationPermissionStatus.granted);
    });

    test('requestPermission() stays denied when user rejects', () async {
      _stubPermission(
        PermissionStatus.denied,
        requestResult: PermissionStatus.denied,
      );

      final container = ProviderContainer(
        overrides: [
          notificationPermissionServiceProvider
              .overrideWith((_) => NotificationPermissionService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationPermissionProvider.future);
      await container
          .read(notificationPermissionProvider.notifier)
          .requestPermission();

      final result = await container
          .read(notificationPermissionProvider.future);
      expect(result, NotificationPermissionStatus.denied);
    });
  });
}
