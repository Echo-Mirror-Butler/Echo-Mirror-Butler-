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
import '../widgets/pending_sync_badge.dart';

/// Daily logging screen with infinite-scroll pagination (Issue #637).
class LoggingScreen extends ConsumerStatefulWidget {
  const LoggingScreen({super.key});

  @override
  ConsumerState<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends ConsumerState<LoggingScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      final userId = authState.user?.id;
      if (userId != null && userId.isNotEmpty) {
        ref.read(loggingProvider.notifier).loadLogEntries(userId: userId);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(loggingProvider.notifier).loadMoreLogEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggingState = ref.watch(loggingProvider);
    final authState = ref.watch(authProvider);
    final userId = authState.user?.id;
    final theme = Theme.of(context);
    final notifier = ref.read(loggingProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Logging'),
        actions: [
          const Center(child: PendingSyncBadge()),
          IconButton(
            icon: Icon(FontAwesomeIcons.calendar.data),
            onPressed: () {
              final entries = loggingState.value ?? <LogEntryModel>[];
              _showCalendar(context, entries);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          if (userId != null && userId.isNotEmpty) {
            await ref
                .read(loggingProvider.notifier)
                .loadLogEntries(userId: userId, force: true);
          }
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
                            FontAwesomeIcons.book.data,
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
            final showFooter = notifier.hasMore || notifier.isLoadingMore;
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: entries.length + (showFooter ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= entries.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: notifier.isLoadingMore
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }
                final entry = entries[index];
                return Hero(
                  tag: 'log_entry_${entry.id}',
                  child: AnimatedCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.zero,
                    animationDuration: Duration(
                      milliseconds: 300 + (index.clamp(0, 10) * 50),
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
                        FontAwesomeIcons.chevronRight.data,
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
          error: (error, stack) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: NoConnectionWidget(
                  message:
                      'We could not load your daily logs. '
                      'This can happen when Supabase tables are missing. '
                      'Run migrations and try again.',
                  onRetry: () => _retryLoadEntries(userId),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/logging/create');
        },
        icon: Icon(FontAwesomeIcons.plus.data),
        label: const Text('New Entry'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _retryLoadEntries(String? userId) {
    if (userId == null || userId.isEmpty) return;
    ref.read(loggingProvider.notifier).loadLogEntries(userId: userId, force: true);
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
