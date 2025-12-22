import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ai_insight_model.dart';
import '../../data/repositories/ai_repository.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// AI repository provider
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

/// AI insight state notifier
class AiInsightNotifier extends StateNotifier<AsyncValue<AiInsightModel?>> {
  AiInsightNotifier(this._repository) : super(const AsyncValue.data(null));

  final AiRepository _repository;
  AiInsightModel? _cachedInsight;

  /// Generate insight based on recent logs
  /// 
  /// Takes a list of UserLog (LogEntryModel) and generates AI insights
  /// Uses Gemini AI - will show error state if API fails (no mock data fallback)
  Future<void> generateInsight(List<LogEntryModel> recentLogs) async {
    // Need at least 3 logs to generate meaningful insights
    if (recentLogs.length < 3) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      debugPrint('[AiInsightNotifier] Generating insight with Gemini...');
      final insight = await _repository.generateInsight(recentLogs);
      _cachedInsight = insight;
      debugPrint('[AiInsightNotifier] ✅ Successfully generated insight from Gemini');
      state = AsyncValue.data(insight);
    } catch (e, stackTrace) {
      // Show error state instead of silently falling back to null
      // This ensures users know when Gemini API is not working
      debugPrint('[AiInsightNotifier] ❌ Error generating insight from Gemini: $e');
      debugPrint('[AiInsightNotifier] Stack trace: $stackTrace');
      // Set to error state so UI can show appropriate message
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Get cached insight (if available)
  AiInsightModel? get cachedInsight => _cachedInsight;

  /// Clear cached insight
  void clearInsight() {
    _cachedInsight = null;
    state = const AsyncValue.data(null);
  }
}

/// AI insight provider
final aiInsightProvider =
    StateNotifierProvider<AiInsightNotifier, AsyncValue<AiInsightModel?>>((ref) {
  final repository = ref.watch(aiRepositoryProvider);
  return AiInsightNotifier(repository);
});

