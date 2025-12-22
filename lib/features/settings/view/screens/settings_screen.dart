import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/viewmodel/providers/theme_provider.dart';
import '../../../../core/viewmodel/providers/notification_provider.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Appearance',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(FontAwesomeIcons.palette),
                  title: const Text('Theme'),
                  subtitle: Text(
                    themeMode == ThemeMode.light
                        ? 'Light'
                        : themeMode == ThemeMode.dark
                            ? 'Dark'
                            : 'System',
                  ),
                  trailing: Switch(
                    value: themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Notifications Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Reminders',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final notificationEnabled = ref.watch(notificationEnabledProvider);
                    final notificationTime = ref.watch(notificationTimeProvider);
                    final notificationService = ref.watch(notificationServiceProvider);

                    return notificationEnabled.when(
                      data: (enabled) => notificationTime.when(
                        data: (time) => Column(
                          children: [
                            ListTile(
                              leading: const Icon(FontAwesomeIcons.bell),
                              title: const Text('Daily Reflection Reminder'),
                              subtitle: enabled
                                  ? Text('Reminder at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}')
                                  : const Text('Get reminded to log your daily reflections'),
                              trailing: Switch(
                                value: enabled,
                                onChanged: (value) async {
                                  if (value) {
                                    // Enable reminder with current time
                                    await notificationService.scheduleDailyReminder(
                                      hour: time.hour,
                                      minute: time.minute,
                                    );
                                  } else {
                                    // Disable reminder
                                    await notificationService.cancelDailyReminder();
                                  }
                                  // Refresh state
                                  ref.invalidate(notificationEnabledProvider);
                                },
                              ),
                            ),
                            if (enabled)
                              ListTile(
                                leading: const Icon(FontAwesomeIcons.clock),
                                title: const Text('Reminder Time'),
                                subtitle: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                                trailing: const Icon(FontAwesomeIcons.chevronRight),
                                onTap: () async {
                                  // Show time picker
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
                                    // Refresh state
                                    ref.invalidate(notificationTimeProvider);
                                  }
                                },
                              ),
                          ],
                        ),
                        loading: () => const ListTile(
                          leading: CircularProgressIndicator(),
                          title: Text('Loading...'),
                        ),
                        error: (_, __) => const ListTile(
                          leading: Icon(FontAwesomeIcons.triangleExclamation),
                          title: Text('Error loading reminder time'),
                        ),
                      ),
                      loading: () => const ListTile(
                        leading: CircularProgressIndicator(),
                        title: Text('Loading...'),
                      ),
                      error: (_, __) => const ListTile(
                        leading: Icon(FontAwesomeIcons.triangleExclamation),
                        title: Text('Error loading reminder settings'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Account Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Account',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (authState.user != null)
                  ListTile(
                    leading: const Icon(FontAwesomeIcons.user),
                    title: const Text('Email'),
                    subtitle: Text(authState.user!.email),
                  ),
                ListTile(
                  leading: const Icon(FontAwesomeIcons.key),
                  title: const Text('Change Password'),
                  trailing: const Icon(FontAwesomeIcons.chevronRight),
                  onTap: () {
                    context.push('/settings/change-password');
                  },
                  ),
                ListTile(
                  leading: const Icon(FontAwesomeIcons.rightFromBracket),
                  title: const Text(AppStrings.logout),
                  onTap: () async {
                    await ref.read(authProvider.notifier).signOut();
                    // Navigation will be handled by router
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

