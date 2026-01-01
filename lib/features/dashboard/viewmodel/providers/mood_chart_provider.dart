import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../logging/data/models/log_entry_model.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';

/// Provider that computes chart data from recent logs (last 30 days)
final moodChartDataProvider = Provider<List<LogEntryModel>>((ref) {
  final loggingState = ref.watch(loggingProvider);
  final authState = ref.watch(authProvider);

  // Return empty if not authenticated
  if (!authState.isAuthenticated || authState.user == null) {
    return [];
  }

  final allLogs = loggingState.value ?? [];
  
  if (allLogs.isEmpty) {
    return [];
  }

  // Filter logs from last 30 days
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  
  final recentLogs = allLogs
      .where((log) {
        final logDate = log.date.isUtc ? log.date.toLocal() : log.date;
        return logDate.isAfter(thirtyDaysAgo) || 
               logDate.isAtSameMomentAs(thirtyDaysAgo);
      })
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return recentLogs;
});

