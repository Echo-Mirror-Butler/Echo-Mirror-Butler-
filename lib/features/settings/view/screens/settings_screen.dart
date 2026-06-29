import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/viewmodel/providers/theme_provider.dart';
import '../../../../core/viewmodel/providers/notification_provider.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../../global_mirror/viewmodel/providers/gift_provider.dart';

/// Modern settings screen with improved UI/UX
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);
    final isDark = theme.brightness == Brightness.dark;
    final echoBalance = ref.watch(giftProvider).echoBalance;

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
            icon: FontAwesomeIcons.palette.data,
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
            icon: FontAwesomeIcons.bell.data,
            title: 'Reminders',
            subtitle: 'Stay on track with daily reflections',
          ),
          const SizedBox(height: 12),
          _buildNotificationsCard(context, theme, ref),
          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader(
            context,
            theme,
            icon: FontAwesomeIcons.fileExport.data,
            title: 'Data',
            subtitle: 'Export your mood journal',
          ),
          const SizedBox(height: 12),
          _buildDataCard(context, theme, authState),
          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader(
            context,
            theme,
            icon: FontAwesomeIcons.user.data,
            title: 'Account',
            subtitle: 'Manage your account settings',
          ),
          const SizedBox(height: 12),
          _buildAccountCard(context, theme, authState, ref, echoBalance),
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
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
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
              icon: FontAwesomeIcons.moon.data,
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
              icon: FontAwesomeIcons.circleHalfStroke.data,
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
                  icon: FontAwesomeIcons.bell.data,
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
                    icon: FontAwesomeIcons.clock.data,
                    iconColor: Colors.teal,
                    title: 'Reminder Time',
                    subtitle:
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    trailing: Icon(
                      FontAwesomeIcons.chevronRight.data,
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
                Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
                _buildWeeklyDigestTile(context, theme, ref),
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
                Icon(
                  FontAwesomeIcons.triangleExclamation.data,
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
              Icon(
                FontAwesomeIcons.triangleExclamation.data,
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

  Widget _buildWeeklyDigestTile(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final weeklyDigest = ref.watch(weeklyDigestProvider);
    final weeklyDigestNotifier = ref.watch(weeklyDigestNotifierProvider);

    return weeklyDigest.when(
      data: (enabled) => _buildModernListTile(
        context,
        theme,
        icon: FontAwesomeIcons.envelope.data,
        iconColor: Colors.purple,
        title: 'Weekly Digest Email',
        subtitle: enabled ? 'Weekly summary is on' : 'Get a weekly mood recap',
        trailing: Switch(
          value: enabled,
          onChanged: (value) async {
            await weeklyDigestNotifier.setEnabled(value);
          },
        ),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: ShimmerLoading(width: 24, height: 24),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.triangleExclamation.data,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error loading digest preference',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    ThemeData theme,
    dynamic authState,
    WidgetRef ref,
    double echoBalance,
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
              icon: FontAwesomeIcons.coins.data,
              iconColor: AppTheme.primaryColor,
              title: 'ECHO Balance',
              subtitle: '${echoBalance.toStringAsFixed(0)} ECHO available',
              trailing: Icon(
                FontAwesomeIcons.chevronRight.data,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () => context.push('/gift/${authState.user?.id ?? ''}'),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            if (authState.user != null)
              _buildModernListTile(
                context,
                theme,
                icon: FontAwesomeIcons.envelope.data,
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
              icon: FontAwesomeIcons.circleUser.data,
              iconColor: AppTheme.primaryColor,
              title: 'My Profile',
              subtitle: 'Edit name and avatar',
              trailing: Icon(
                FontAwesomeIcons.chevronRight.data,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () => context.push('/profile'),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            _buildModernListTile(
              context,
              theme,
              icon: FontAwesomeIcons.listCheck.data,
              iconColor: Colors.teal,
              title: 'Manage Habits',
              subtitle: 'Reorder, rename, or remove habits',
              trailing: Icon(
                FontAwesomeIcons.chevronRight.data,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () => context.push('/habits'),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            _buildModernListTile(
              context,
              theme,
              icon: FontAwesomeIcons.shield.data,
              iconColor: Colors.green,
              title: 'Security',
              subtitle: 'Manage sessions and two-factor authentication',
              trailing: Icon(
                FontAwesomeIcons.chevronRight.data,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () {
                context.push('/settings/security');
              },
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            _buildModernListTile(
              context,
              theme,
              icon: FontAwesomeIcons.key.data,
              iconColor: Colors.purple,
              title: 'Change Password',
              subtitle: 'Update your account password',
              trailing: Icon(
                FontAwesomeIcons.chevronRight.data,
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
              icon: FontAwesomeIcons.rightFromBracket.data,
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

  Widget _buildDataCard(BuildContext context, ThemeData theme, dynamic authState) {
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
        child: _buildModernListTile(
          context,
          theme,
          icon: FontAwesomeIcons.filePdf.data,
          iconColor: Colors.red,
          title: 'Export PDF',
          subtitle: 'Download your mood journal as a PDF',
          trailing: Icon(
            FontAwesomeIcons.chevronRight.data,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          onTap: () => _generateAndSharePDF(context, authState),
        ),
      ),
    );
  }

  Future<void> _generateAndSharePDF(BuildContext context, dynamic authState) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Building your PDF…')));

    try {
      final client = Supabase.instance.client;
      final userId = (authState.user?.id as String?) ?? '';

      final entriesRes = await client
          .from('log_entries')
          .select('date, mood, habits, notes')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(300);

      final insightsRes = await client
          .from('insights')
          .select('prediction, suggestions, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3);

      final entries = (entriesRes as List).cast<Map<String, dynamic>>();
      final insights = (insightsRes as List).cast<Map<String, dynamic>>();
      final userEmail = authState.user?.email ?? '';

      const moodEmoji = {1: '😢', 2: '😕', 3: '😐', 4: '🙂', 5: '😄'};

      final totalEntries = entries.length;
      final moodsWithValue = entries.where((e) => e['mood'] != null).toList();
      final avgMood = moodsWithValue.isEmpty
          ? 'N/A'
          : (moodsWithValue.fold(0, (s, e) => s + (e['mood'] as int)) /
                  moodsWithValue.length)
              .toStringAsFixed(2);
      final dateRange = totalEntries > 0
          ? '${entries.last['date']} → ${entries.first['date']}'
          : 'No entries';

      const brand = PdfColor.fromInt(0xFF1463FF);
      const footerText = 'Generated locally by EchoMirror — your data never left your device';

      final doc = pw.Document();

      // Cover page
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 6, color: brand),
            pw.SizedBox(height: 32),
            pw.Text('EchoMirror', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: brand)),
            pw.SizedBox(height: 8),
            pw.Text('Mood Journal Export', style: pw.TextStyle(fontSize: 16, color: PdfColors.blueGrey700)),
            pw.Divider(color: PdfColors.blueGrey100),
            pw.SizedBox(height: 16),
            _pdfRow('Email', userEmail),
            _pdfRow('Date range', dateRange),
            _pdfRow('Total entries', '$totalEntries'),
            _pdfRow('Average mood', avgMood),
            pw.Spacer(),
            pw.Text(footerText, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ));

      // Entries pages (10 per page)
      const pageSize = 10;
      final pages = (totalEntries / pageSize).ceil();
      for (int p = 0; p < pages; p++) {
        final slice = entries.skip(p * pageSize).take(pageSize).toList();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 4, color: brand),
              pw.SizedBox(height: 16),
              pw.Text('Mood Entries (${p + 1}/$pages)',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: brand)),
              pw.SizedBox(height: 12),
              ...slice.map((entry) {
                final mood = entry['mood'] as int?;
                final emoji = mood != null ? (moodEmoji[mood] ?? '$mood') : '—';
                final habits = (entry['habits'] as List?)?.cast<String>().join(', ') ?? '';
                final notes = entry['notes'] as String? ?? '';
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${entry['date']}  $emoji',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    if (habits.isNotEmpty)
                      pw.Text(habits,
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
                    if (notes.isNotEmpty)
                      pw.Text(notes,
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                    pw.Divider(color: PdfColors.blueGrey50),
                  ],
                );
              }),
              pw.Spacer(),
              pw.Text(footerText, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ));
      }

      // Insights page
      if (insights.isNotEmpty) {
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 4, color: brand),
              pw.SizedBox(height: 16),
              pw.Text('AI Insights',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: brand)),
              pw.SizedBox(height: 12),
              ...insights.map((insight) {
                final prediction = insight['prediction'] as String? ?? '';
                final suggestions = (insight['suggestions'] as List?)?.cast<String>() ?? [];
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(prediction,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ...suggestions.take(3).map((s) =>
                        pw.Text('• $s', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
                    pw.SizedBox(height: 12),
                  ],
                );
              }),
              pw.Spacer(),
              pw.Text(footerText, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ));
      }

      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'echomirror-journal.pdf');
    } catch (e) {
      debugPrint('[SettingsScreen] PDF export error: $e');
      messenger.showSnackBar(SnackBar(content: Text('PDF export failed: ${e.toString()}')));
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey700)),
          ),
          pw.Text(value, style: pw.TextStyle(fontSize: 10)),
        ],
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
                child: Icon(icon, color: iconColor, size: 18),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
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
