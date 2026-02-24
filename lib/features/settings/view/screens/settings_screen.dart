import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/viewmodel/providers/theme_provider.dart';
import '../../../../core/viewmodel/providers/notification_provider.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';

/// Modern settings screen with improved UI/UX
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.settings, style: theme.textTheme.headlineSmall),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Appearance Section
          _buildSectionHeader(
            context,
            theme,
            icon: FontAwesomeIcons.palette,
            title: 'Appearance',
            subtitle: 'Customize your app experience',
          ),
          const SizedBox(height: 12),
          _buildThemeCard(context, theme, themeMode, ref, isDark),
          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader(
            context,
            theme,
            icon: FontAwesomeIcons.bell,
            title: 'Reminders',
            subtitle: 'Stay on track with daily reflections',
          ),
          const SizedBox(height: 12),
          _buildNotificationsCard(context, theme, ref),
          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader(
            context,
            theme,
            icon: FontAwesomeIcons.user,
            title: 'Account',
            subtitle: 'Manage your account settings',
          ),
          const SizedBox(height: 12),
          _buildAccountCard(context, theme, authState, ref),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    ThemeData theme,
    ThemeMode themeMode,
    WidgetRef ref,
    bool isDark,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            _buildModernListTile(
              context,
              theme,
              icon: FontAwesomeIcons.moon,
              iconColor: Colors.indigo,
              title: 'Dark Mode',
              subtitle: 'Switch to dark theme',
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ref
                      .read(themeProvider.notifier)
                      .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            _buildModernListTile(
              context,
              theme,
              icon: FontAwesomeIcons.circleHalfStroke,
              iconColor: Colors.blue,
              title: 'System Theme',
              subtitle: 'Follow system appearance',
              trailing: Switch(
                value: themeMode == ThemeMode.system,
                onChanged: (value) {
                  ref
                      .read(themeProvider.notifier)
                      .setThemeMode(value ? ThemeMode.system : ThemeMode.light);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final notificationEnabled = ref.watch(notificationEnabledProvider);
    final notificationTime = ref.watch(notificationTimeProvider);
    final notificationService = ref.watch(notificationServiceProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: notificationEnabled.when(
        data: (enabled) => notificationTime.when(
          data: (time) => Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                _buildModernListTile(
                  context,
                  theme,
                  icon: FontAwesomeIcons.bell,
                  iconColor: Colors.orange,
                  title: 'Daily Reflection Reminder',
                  subtitle: enabled
                      ? 'Reminder at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                      : 'Get reminded to log your daily reflections',
                  trailing: Switch(
                    value: enabled,
                    onChanged: (value) async {
                      if (value) {
                        await notificationService.scheduleDailyReminder(
                          hour: time.hour,
                          minute: time.minute,
                        );
                      } else {
                        await notificationService.cancelDailyReminder();
                      }
                      ref.invalidate(notificationEnabledProvider);
                    },
                  ),
                ),
                if (enabled) ...[
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  _buildModernListTile(
                    context,
                    theme,
                    icon: FontAwesomeIcons.clock,
                    iconColor: Colors.teal,
                    title: 'Reminder Time',
                    subtitle:
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    trailing: FaIcon(
                      FontAwesomeIcons.chevronRight,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: time.hour,
                          minute: time.minute,
                        ),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        await notificationService.scheduleDailyReminder(
                          hour: picked.hour,
                          minute: picked.minute,
                        );
                        ref.invalidate(notificationTimeProvider);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          loading: () => Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: ShimmerLoading(width: 24, height: 24)),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.triangleExclamation,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error loading reminder time',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        loading: () => Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: ShimmerLoading(width: 24, height: 24)),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              FaIcon(
                FontAwesomeIcons.triangleExclamation,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error loading reminder settings',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    ThemeData theme,
    dynamic authState,
    WidgetRef ref,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            if (authState.user != null)
              _buildModernListTile(
                context,
                theme,
                icon: FontAwesomeIcons.envelope,
                iconColor: Colors.blue,
                title: 'Email',
                subtitle: authState.user!.email,
                trailing: null,
              ),
            if (authState.user != null)
              Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            _buildModernListTile(
              context,
              theme,
              icon: FontAwesomeIcons.key,
              iconColor: Colors.purple,
              title: 'Change Password',
              subtitle: 'Update your account password',
              trailing: FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () {
                context.push('/settings/change-password');
              },
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            _buildModernListTile(
              context,
              theme,
              icon: FontAwesomeIcons.rightFromBracket,
              iconColor: Colors.red,
              title: AppStrings.logout,
              subtitle: 'Sign out of your account',
              trailing: null,
              onTap: () async {
                await ref.read(authProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernListTile(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
        ),
      ),
    );
  }
}
