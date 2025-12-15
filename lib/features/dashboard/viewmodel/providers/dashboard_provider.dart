import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/insight_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../../logging/viewmodel/providers/logging_provider.dart';

/// Dashboard repository provider
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final loggingRepository = ref.watch(loggingRepositoryProvider);
  return DashboardRepository(loggingRepository);
});

/// Dashboard state notifier
class DashboardNotifier extends StateNotifier<AsyncValue<List<InsightModel>>> {
  DashboardNotifier(this._repository) : super(const AsyncValue.data([])) {
    // Don't load on init - wait for userId to be provided
  }

  final DashboardRepository _repository;
  String? _currentUserId;
  bool _hasLoaded = false;

  /// Load insights for the current user
  Future<void> loadInsights({String? userId, bool forceReload = false}) async {
    // If userId is provided and different from current, reset
    if (userId != null && userId != _currentUserId) {
      _currentUserId = userId;
      _hasLoaded = false;
    }
    
    // If no userId, return empty list instead of staying in loading state
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    // If already loaded for this user and not forcing reload, don't reload
    if (_hasLoaded && _currentUserId != null && !forceReload) {
      return;
    }

    state = const AsyncValue.loading();
    try {
      final insights = await _repository.getInsights(_currentUserId!);
      _hasLoaded = true;
      state = AsyncValue.data(insights);
    } catch (e, stackTrace) {
      _hasLoaded = false;
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Load predictions
  Future<List<InsightModel>> loadPredictions({String? userId}) async {
    if (userId != null) {
      _currentUserId = userId;
    }
    if (_currentUserId == null) return [];

    try {
      return await _repository.getPredictions(_currentUserId!);
    } catch (e) {
      return [];
    }
  }

  /// Load future letters
  Future<List<InsightModel>> loadFutureLetters({String? userId}) async {
    if (userId != null) {
      _currentUserId = userId;
    }
    if (_currentUserId == null) return [];

    try {
      return await _repository.getFutureLetters(_currentUserId!);
    } catch (e) {
      return [];
    }
  }
}

/// Dashboard provider
final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<List<InsightModel>>>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  return DashboardNotifier(repository);
});

