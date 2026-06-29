import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';

/// Returns true when loggingProvider contains at least one entry
/// whose date (in local timezone) matches today's local calendar date.
/// Returns false while loading, on error, or when no entry exists for today.
final hasLoggedTodayProvider = Provider<bool>((ref) {
  final loggingState = ref.watch(loggingProvider);

  return loggingState.when(
    data: (entries) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return entries.any((entry) {
        final local = entry.date.isUtc ? entry.date.toLocal() : entry.date;
        final d = DateTime(local.year, local.month, local.day);
        return d.isAtSameMomentAs(today);
      });
    },
    loading: () => false,
    error: (_, __) => false,
  );
});
