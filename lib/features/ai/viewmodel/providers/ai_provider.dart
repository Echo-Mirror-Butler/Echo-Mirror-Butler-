import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/ai_insight_model.dart';
import '../../data/repositories/ai_repository.dart';
import '../../../logging/data/models/log_entry_model.dart';

/// AI repository provider
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository();
});

/// SharedPreferences key for cached AI insight
const String _cachedInsightKey = 'cached_ai_insight';

/// AI insight state notifier
class AiInsightNotifier extends StateNotifier<AsyncValue<AiInsightModel?>> {
  AiInsightNotifier(this._repository) : super(const AsyncValue.data(null)) {
    _loadCachedInsight();
  }

  final AiRepository _repository;
  AiInsightModel? _cachedInsight;

  /// Load cached insight from SharedPreferences
  Future<void> _loadCachedInsight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cachedInsightKey);
      if (cachedJson != null) {
        final jsonMap = jsonDecode(cachedJson) as Map<String, dynamic>;
        _cachedInsight = AiInsightModel.fromJson(jsonMap);
        state = AsyncValue.data(_cachedInsight);
        debugPrint('[AiInsightNotifier] ✅ Loaded cached insight from storage');
      }
    } catch (e) {
      debugPrint('[AiInsightNotifier] Error loading cached insight: $e');
    }
  }

  /// Save insight to SharedPreferences
  Future<void> _saveCachedInsight(AiInsightModel insight) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(insight.toJson());
      await prefs.setString(_cachedInsightKey, jsonString);
      debugPrint('[AiInsightNotifier] ✅ Saved insight to cache');
    } catch (e) {
      debugPrint('[AiInsightNotifier] Error saving cached insight: $e');
    }
  }

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
      await _saveCachedInsight(insight);
      debugPrint(
        '[AiInsightNotifier] ✅ Successfully generated insight from Gemini',
      );
      state = AsyncValue.data(insight);
    } catch (e, stackTrace) {
      // If error, try to restore cached insight
      if (_cachedInsight != null) {
        debugPrint(
          '[AiInsightNotifier] ⚠️ Error generating new insight, using cached',
        );
        state = AsyncValue.data(_cachedInsight);
      } else {
        // Show error state if no cache available
        debugPrint(
          '[AiInsightNotifier] ❌ Error generating insight from Gemini: $e',
        );
        debugPrint('[AiInsightNotifier] Stack trace: $stackTrace');
        state = AsyncValue.error(e, stackTrace);
      }
    }
  }

  /// Get cached insight (if available)
  AiInsightModel? get cachedInsight => _cachedInsight;

  /// Clear cached insight
  void clearInsight() {
    _cachedInsight = null;
    state = const AsyncValue.data(null);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_cachedInsightKey);
    });
  }
}

/// AI insight provider
final aiInsightProvider =
    StateNotifierProvider<AiInsightNotifier, AsyncValue<AiInsightModel?>>((
      ref,
    ) {
      final repository = ref.watch(aiRepositoryProvider);
      return AiInsightNotifier(repository);
    });
