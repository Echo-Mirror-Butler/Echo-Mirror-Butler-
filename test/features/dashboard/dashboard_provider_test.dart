import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echomirror/features/dashboard/viewmodel/providers/dashboard_provider.dart';
import 'package:echomirror/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:echomirror/features/dashboard/data/models/insight_model.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  group('DashboardNotifier', () {
    late MockDashboardRepository mockRepo;
    late DashboardNotifier notifier;

    setUp(() {
      mockRepo = MockDashboardRepository();
      notifier = DashboardNotifier(mockRepo);
    });

    test('initial state is data([])', () {
      expect(notifier.state, const AsyncValue<List<InsightModel>>.data([]));
    });

    test('loadInsights returns empty when userId is null/empty', () async {
      await notifier.loadInsights(userId: null);
      expect(notifier.state, const AsyncValue<List<InsightModel>>.data([]));
      
      await notifier.loadInsights(userId: '');
      expect(notifier.state, const AsyncValue<List<InsightModel>>.data([]));
    });

    test('loadInsights fetches data successfully', () async {
      final insights = [
        InsightModel(
          id: '1',
          userId: 'user1',
          title: 'Test',
          description: 'Desc',
          date: DateTime.now(),
          type: InsightType.general,
          createdAt: DateTime.now(),
        )
      ];
      when(() => mockRepo.getInsights('user1')).thenAnswer((_) async => insights);

      await notifier.loadInsights(userId: 'user1');
      expect(notifier.state, AsyncValue<List<InsightModel>>.data(insights));
      
      // Call again without forceReload, should not call repo
      await notifier.loadInsights(userId: 'user1');
      verify(() => mockRepo.getInsights('user1')).called(1);
      
      // Call with forceReload, should call repo again
      await notifier.loadInsights(userId: 'user1', forceReload: true);
      verify(() => mockRepo.getInsights('user1')).called(1);
    });

    test('loadInsights sets error state on failure', () async {
      when(() => mockRepo.getInsights('user2')).thenThrow(Exception('error'));

      await notifier.loadInsights(userId: 'user2');
      expect(notifier.state, isA<AsyncError>());
    });

    test('loadPredictions returns data', () async {
      when(() => mockRepo.getPredictions('user1')).thenAnswer((_) async => []);
      
      final result = await notifier.loadPredictions(userId: 'user1');
      expect(result, isEmpty);
      
      when(() => mockRepo.getPredictions('user1')).thenThrow(Exception());
      final errorResult = await notifier.loadPredictions();
      expect(errorResult, isEmpty);
    });

    test('loadFutureLetters returns data', () async {
      when(() => mockRepo.getFutureLetters('user1')).thenAnswer((_) async => []);
      
      final result = await notifier.loadFutureLetters(userId: 'user1');
      expect(result, isEmpty);
      
      when(() => mockRepo.getFutureLetters('user1')).thenThrow(Exception());
      final errorResult = await notifier.loadFutureLetters();
      expect(errorResult, isEmpty);
    });
    
    test('loadPredictions returns empty when userId is null', () async {
      // Create new notifier to ensure _currentUserId is null
      final newNotifier = DashboardNotifier(mockRepo);
      final result = await newNotifier.loadPredictions();
      expect(result, isEmpty);
    });
    
    test('loadFutureLetters returns empty when userId is null', () async {
      // Create new notifier to ensure _currentUserId is null
      final newNotifier = DashboardNotifier(mockRepo);
      final result = await newNotifier.loadFutureLetters();
      expect(result, isEmpty);
    });
  });
}
