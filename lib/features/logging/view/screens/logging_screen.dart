import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/widgets/no_connection_widget.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/animated_card.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../data/models/log_entry_model.dart';
import '../../viewmodel/providers/logging_provider.dart';
import '../widgets/logging_calendar.dart';

/// Daily logging screen
class LoggingScreen extends ConsumerStatefulWidget {
  const LoggingScreen({super.key});

  @override
  ConsumerState<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends ConsumerState<LoggingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      final userId = authState.user?.id;
      if (userId != null && userId.isNotEmpty) {
        ref.read(loggingProvider.notifier).loadLogEntries(userId: userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggingState = ref.watch(loggingProvider);
    final authState = ref.watch(authProvider);
    final userId = authState.user?.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Logging'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.calendar),
            onPressed: () {
              final entries = loggingState.value ?? <LogEntryModel>[];
              _showCalendar(context, entries);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(loggingProvider.notifier)
              .loadLogEntries(userId: userId);
        },
        child: loggingState.when(
          data: (entries) {
            if (entries.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FontAwesomeIcons.book,
                            size: 64,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No entries yet',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start logging your daily mood and habits',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Hero(
                  tag: 'log_entry_${entry.id}',
                  child: AnimatedCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.zero,
                    animationDuration: Duration(
                      milliseconds: 300 + (index * 50),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.1,
                        ),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      onTap: () {
                        context.push(
                          '/logging/detail/${entry.id}',
                          extra: entry,
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () =>
              const Center(child: ShimmerLoading(width: 40, height: 40)),
          error: (error, stack) => NoConnectionWidget(
            message:
                'We could not load your daily logs. '
                'This can happen when Supabase tables are missing. '
                'Run migrations and try again.',
            onRetry: () => _retryLoadEntries(userId),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/logging/create');
        },
        icon: const FaIcon(FontAwesomeIcons.plus),
        label: const Text('New Entry'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _retryLoadEntries(String? userId) {
    if (userId == null || userId.isEmpty) return;
    ref.read(loggingProvider.notifier).loadLogEntries(userId: userId);
  }

  IconData _getMoodIcon(int? mood) {
    if (mood == null) {
      return FontAwesomeIcons.faceSmile.data;
    }
    switch (mood) {
      case 1:
        return FontAwesomeIcons.faceFrown.data;
      case 2:
        return FontAwesomeIcons.faceMeh.data;
      case 3:
        return FontAwesomeIcons.faceSmile.data;
      case 4:
        return FontAwesomeIcons.faceSmileBeam.data;
      case 5:
        return FontAwesomeIcons.faceGrinStars.data;
      default:
        return FontAwesomeIcons.faceSmile.data;
    }
  }

  void _showCalendar(BuildContext context, List<LogEntryModel> entries) {
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
