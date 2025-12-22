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

  // Return mock data for testing if no real data
  if (recentLogs.isEmpty) {
    return _getMockChartData();
  }

  return recentLogs;
});

/// Mock data for testing the chart
List<LogEntryModel> _getMockChartData() {
  final now = DateTime.now();
  final mockLogs = <LogEntryModel>[];
  
  // Generate mock data for last 7 days
  for (int i = 6; i >= 0; i--) {
    final date = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: i));
    
    // Vary mood values for visual interest
    final mood = 2 + (i % 3); // Values between 2-4
    
    mockLogs.add(LogEntryModel(
      id: 'mock_$i',
      userId: 'mock_user',
      date: date,
      mood: mood,
      habits: ['Exercise', 'Meditation'],
      notes: 'Day ${i + 1} of tracking',
      createdAt: date,
    ));
  }
  
  return mockLogs;
}

