import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/viewmodel/providers/notification_permission_provider.dart';

/// A contextual banner shown when OS-level notification permission is denied or
/// permanently denied.
///
/// - Shows a user-friendly explanation of why notifications aren't working.
/// - Offers a CTA that either re-requests the permission (if just denied) or
///   deep-links to OS App Settings (if permanently denied / revoked).
/// - Disappears automatically when permission is granted.
///
/// Usage — place this above (or inside) the notification settings section:
/// ```dart
/// const NotificationPermissionBanner()
/// ```
class NotificationPermissionBanner extends ConsumerWidget {
  const NotificationPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(notificationPermissionProvider);

    return permissionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        // Only render when permission is missing.
        final shouldShow =
            status == NotificationPermissionStatus.denied ||
            status == NotificationPermissionStatus.permanentlyDenied ||
            status == NotificationPermissionStatus.restricted;

        if (!shouldShow) return const SizedBox.shrink();

        return _BannerContent(status: status);
      },
    );
  }
}

// ─── Internal banner body ─────────────────────────────────────────────────────

class _BannerContent extends ConsumerWidget {
  final NotificationPermissionStatus status;

  const _BannerContent({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(notificationPermissionProvider.notifier);

    final bool isPermanent =
        status == NotificationPermissionStatus.permanentlyDenied ||
        status == NotificationPermissionStatus.restricted;

    final String title = isPermanent
        ? 'Notifications are blocked'
        : 'Notifications are disabled';

    final String body = isPermanent
        ? 'Reminders can\'t be delivered because notification permission was '
            'revoked. Open Settings to re-enable them.'
        : 'EchoMirror needs notification permission to deliver your daily '
            'reflection reminders.';

    final String ctaLabel =
        isPermanent ? 'Open Settings' : 'Enable Notifications';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.25),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                FontAwesomeIcons.bellSlash.data,
                size: 18,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: 14),

            // Text + CTA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () async {
                        if (isPermanent) {
                          await notifier.openOsSettings();
                        } else {
                          await notifier.requestPermission();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.12),
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPermanent
                                ? FontAwesomeIcons.arrowUpRightFromSquare.data
                                : FontAwesomeIcons.bell.data,
                            size: 13,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ctaLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
