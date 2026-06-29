import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../logging/data/models/log_entry_model.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';

/// A compact banner shown on the dashboard when the user has already
/// logged today. Displays a success indicator and a "View log →" button.
class DailyLogStatusBanner extends ConsumerWidget {
  const DailyLogStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(loggingProvider).value ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final LogEntryModel? todayEntry =
        entries.cast<LogEntryModel?>().firstWhere(
      (e) {
        if (e == null) return false;
        final local = e.date.isUtc ? e.date.toLocal() : e.date;
        final d = DateTime(local.year, local.month, local.day);
        return d.isAtSameMomentAs(today);
      },
      orElse: () => null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                '✓ Logged today',
                style: TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  if (todayEntry != null) {
                    context.push(
                      '/logging/detail/${todayEntry.id}',
                      extra: todayEntry,
                    );
                  } else {
                    context.push('/logging/create');
                  }
                },
                child: const Text('View log →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
