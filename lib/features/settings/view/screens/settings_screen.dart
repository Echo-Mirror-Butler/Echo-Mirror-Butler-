import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/viewmodel/providers/theme_provider.dart';
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

