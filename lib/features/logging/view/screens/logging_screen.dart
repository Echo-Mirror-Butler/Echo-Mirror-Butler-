import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/animated_card.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../data/models/log_entry_model.dart';
import '../../viewmodel/providers/logging_provider.dart';
import '../widgets/logging_calendar.dart';

/// Daily logging screen
class LoggingScreen extends ConsumerWidget {
  const LoggingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggingState = ref.watch(loggingProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Load log entries when we have a user ID (only once)
    if (authState.isAuthenticated && authState.user != null) {
      final userId = authState.user!.id;
      // Use addPostFrameCallback to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (userId.isNotEmpty) {
          ref.read(loggingProvider.notifier).loadLogEntries(userId: userId);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Logging'),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.calendar),
            onPressed: () {
              final entries = loggingState.value ?? <LogEntryModel>[];
              _showCalendar(context, ref, entries);
            },
          ),
        ],
      ),
      body: loggingState.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.book,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text('No entries yet', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Start logging your daily mood and habits',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Hero(
                tag: 'log_entry_${entry.id}',
                child: AnimatedCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.zero,
                  animationDuration: Duration(milliseconds: 300 + (index * 50)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Icon(
                        _getMoodIcon(entry.mood),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      DateFormatter.formatDate(entry.date),
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      entry.mood != null
                          ? 'Mood: ${entry.mood}/5'
                          : 'No mood logged',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Icon(
                      FontAwesomeIcons.chevronRight,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    onTap: () {
                      context.push('/logging/detail/${entry.id}', extra: entry);
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(child: ShimmerLoading(width: 40, height: 40)),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text('Error loading entries', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/logging/create');
        },
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('New Entry'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  IconData _getMoodIcon(int? mood) {
    if (mood == null) {
      return FontAwesomeIcons.smile;
    }
    switch (mood) {
      case 1:
        return FontAwesomeIcons.faceFrown;
      case 2:
        return FontAwesomeIcons.faceMeh;
      case 3:
        return FontAwesomeIcons.faceSmile;
      case 4:
        return FontAwesomeIcons.faceSmileBeam;
      case 5:
        return FontAwesomeIcons.faceGrinStars;
      default:
        return FontAwesomeIcons.faceSmile;
    }
  }

  void _showCalendar(
    BuildContext context,
    WidgetRef ref,
    List<LogEntryModel> entries,
  ) {
    showDialog(
      context: context,
      builder: (context) => LoggingCalendar(
        entries: entries,
        onDateSelected: (date) {
          // Find entry for this date and navigate to it
          try {
            final entry = entries.firstWhere((e) {
              // Normalize entry date to local time for comparison
              final localDate = e.date.isUtc ? e.date.toLocal() : e.date;
              final entryDate = DateTime(
                localDate.year,
                localDate.month,
                localDate.day,
              );
              final selectedDate = DateTime(date.year, date.month, date.day);
              return entryDate.isAtSameMomentAs(selectedDate);
            });
            if (context.mounted) {
              context.push('/logging/detail/${entry.id}', extra: entry);
            }
          } catch (e) {
            // Entry not found for this date, do nothing
          }
        },
      ),
    );
  }
}
