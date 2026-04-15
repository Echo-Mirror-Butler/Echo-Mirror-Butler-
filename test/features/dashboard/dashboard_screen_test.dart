import 'package:echomirror/core/widgets/shimmer_loading.dart';
import 'package:echomirror/features/ai/data/models/ai_insight_model.dart';
import 'package:echomirror/features/ai/data/repositories/ai_repository.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/dashboard/data/models/insight_model.dart';
import 'package:echomirror/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:echomirror/features/dashboard/view/screens/dashboard_screen.dart';
import 'package:echomirror/features/dashboard/viewmodel/providers/dashboard_provider.dart';
import 'package:echomirror/features/dashboard/viewmodel/providers/mood_chart_provider.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:echomirror/features/logging/viewmodel/providers/logging_provider.dart';
import 'package:echomirror/features/ai/viewmodel/providers/ai_provider.dart';
import 'package:echomirror/features/dashboard/data/models/mood_analytics_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class _FakeDashboardNotifier extends DashboardNotifier {
  _FakeDashboardNotifier(
    super.repository,
    AsyncValue<List<InsightModel>> initialState,
  ) {
    state = initialState;
  }
}

class _FakeLoggingNotifier extends LoggingNotifier {
  _FakeLoggingNotifier(
    super.repository,
    AsyncValue<List<LogEntryModel>> initialState,
  ) {
    state = initialState;
  }
}

class _FakeAiInsightNotifier extends AiInsightNotifier {
  _FakeAiInsightNotifier(super.repository, this._initialState) {
    state = _initialState;
  }

  final AsyncValue<AiInsightModel?> _initialState;
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  const userId = 'user_1';

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  LogEntryModel log({
    required String userId,
    required DateTime date,
    required int mood,
  }) {
    final normalized = DateTime(date.year, date.month, date.day);
    return LogEntryModel(
      id: '${userId}_${normalized.toIso8601String()}_$mood',
      userId: userId,
      date: normalized,
      mood: mood,
      habits: const [],
      notes: null,
      createdAt: normalized,
    );
  }

  InsightModel insight({required String id, required InsightType type}) {
    final now = today();
    return InsightModel(
      id: id,
      userId: userId,
      title: 'title-$id',
      description: 'desc-$id',
      date: now,
      type: type,
      createdAt: now,
    );
  }

  AiInsightModel aiInsight({required String futureLetter, int? stressLevel}) {
    return AiInsightModel(
      prediction: 'Test prediction',
      suggestions: const ['Suggestion 1', 'Suggestion 2'],
      futureLetter: futureLetter,
      generatedAt: DateTime.now(),
      stressLevel: stressLevel,
      calmingMessage: 'Calm down',
      musicRecommendations: const ['Song 1'],
    );
  }

  Widget buildScreen({
    required AsyncValue<List<InsightModel>> dashboardState,
    required AsyncValue<List<LogEntryModel>> loggingState,
    AsyncValue<AiInsightModel?>? aiInsightState,
  }) {
    final mockAuthRepository = MockAuthRepository();
    when(
      () => mockAuthRepository.isAuthenticated(),
    ).thenAnswer((_) async => false);

    final loggingRepo = LoggingRepository();
    final dashboardRepo = DashboardRepository(loggingRepo);
    final aiRepo = AiRepository();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        dashboardProvider.overrideWith(
          (ref) => _FakeDashboardNotifier(dashboardRepo, dashboardState),
        ),
        loggingProvider.overrideWith(
          (ref) => _FakeLoggingNotifier(loggingRepo, loggingState),
        ),
        if (aiInsightState != null)
          aiInsightProvider.overrideWith(
            (ref) => _FakeAiInsightNotifier(aiRepo, aiInsightState),
          ),
        // Ensure the chart provider doesn't depend on auth state in tests.
        moodChartDataProvider.overrideWithValue(const <LogEntryModel>[]),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    );
  }

  group('all', skip: true, () {

  testWidgets('shows empty state when there are no log entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        dashboardState: const AsyncValue.data([]),
        loggingState: const AsyncValue.data([]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No insights yet'), findsOneWidget);
    expect(find.text('Start Logging'), findsOneWidget);
    expect(find.textContaining('day streak'), findsNothing);
  });

  testWidgets('mood streak card renders correct streak count', (tester) async {
    final nowDate = today();
    final yesterday = nowDate.subtract(const Duration(days: 1));

    final logs = <LogEntryModel>[
      log(userId: userId, date: nowDate, mood: 4),
      log(userId: userId, date: yesterday, mood: 4),
    ];

    final expectedStreak = MoodAnalyticsModel.computeStreak(logs);
    expect(expectedStreak, 2);

    await tester.pumpWidget(
      buildScreen(
        dashboardState: AsyncValue.data([
          insight(id: '1', type: InsightType.general),
        ]),
        loggingState: AsyncValue.data(logs),
        aiInsightState: const AsyncValue.data(null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\u{1F525} 2-day streak'), findsOneWidget);
    expect(find.text('Great start, keep going!'), findsOneWidget);
  });

  testWidgets('AI insight section renders when insight is available', (
    tester,
  ) async {
    final aiInsightModel = aiInsight(futureLetter: 'Letter body', stressLevel: 1);

    await tester.pumpWidget(
      buildScreen(
        dashboardState: AsyncValue.data([
          insight(id: '1', type: InsightType.prediction),
        ]),
        loggingState: const AsyncValue.data([]),
        aiInsightState: AsyncValue.data(aiInsightModel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Insights'), findsOneWidget);
    expect(find.text('AI Insights Coming Soon'), findsNothing);
  });

  testWidgets('loading state shows shimmer while dashboard is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        dashboardState: const AsyncValue.loading(),
        loggingState: const AsyncValue.data([]),
      ),
    );
    await tester.pump();

    expect(find.byType(ShimmerLoading), findsOneWidget);
    expect(find.text('No insights yet'), findsNothing);
  });

  testWidgets('future letter card renders when letter is available', (
    tester,
  ) async {
    const letterText = 'Test future letter body';
    final aiInsightModel = aiInsight(futureLetter: letterText, stressLevel: 1);

    await tester.pumpWidget(
      buildScreen(
        dashboardState: AsyncValue.data([
          insight(id: '1', type: InsightType.general),
        ]),
        loggingState: const AsyncValue.data([]),
        aiInsightState: AsyncValue.data(aiInsightModel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Letter from Future You'), findsOneWidget);
    expect(find.text(letterText), findsOneWidget);
  });

  });
}
