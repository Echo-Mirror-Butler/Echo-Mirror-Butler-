import 'dart:async';

import 'package:echomirror/features/dashboard/data/models/insight_model.dart';
import 'package:echomirror/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockLoggingRepository extends Mock implements LoggingRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakeFutureLettersBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  FakeFutureLettersBuilder(this._result);

  final PostgrestList _result;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList) onValue, {
    Function? onError,
  }) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

LogEntryModel _entry({
  required String userId,
  required DateTime date,
  int? mood,
  List<String> habits = const [],
  String? notes,
}) {
  final normalized = DateTime(date.year, date.month, date.day);
  return LogEntryModel(
    id: '${userId}_${normalized.toIso8601String()}_${mood ?? 'none'}',
    userId: userId,
    date: normalized,
    mood: mood,
    habits: habits,
    notes: notes,
    createdAt: normalized,
  );
}

void main() {
  group('DashboardRepository.getInsights', () {
    const userId = 'user_1';
    final fixedNow = DateTime(2026, 3, 25, 12, 0);

    late MockLoggingRepository loggingRepository;
    late MockSupabaseClient supabaseClient;
    late MockFunctionsClient functionsClient;
    late MockSupabaseQueryBuilder queryBuilder;
    late DashboardRepository repository;

    setUp(() {
      loggingRepository = MockLoggingRepository();
      supabaseClient = MockSupabaseClient();
      functionsClient = MockFunctionsClient();
      queryBuilder = MockSupabaseQueryBuilder();
      when(() => supabaseClient.functions).thenReturn(functionsClient);
      repository = DashboardRepository(
        loggingRepository,
        supabaseClient: supabaseClient,
        now: () => fixedNow,
      );
    });

    test('returns empty list when there are no log entries', () async {
      when(
        () => loggingRepository.getLogEntries(userId),
      ).thenAnswer((_) async => []);

      final insights = await repository.getInsights(userId);
      expect(insights, isEmpty);
      verify(() => loggingRepository.getLogEntries(userId)).called(1);
    });

    test(
      'adds "Mood Improvement Detected" when recent average is higher',
      () async {
        // Overall avg = (2+2+2+4+4) / 5 = 2.8
        // Recent (last 7 days) avg = (4+4+4) / 3 = 4.0 => improvement > 0.5
        final entries = <LogEntryModel>[
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 1)),
            mood: 4,
          ),
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 2)),
            mood: 4,
          ),
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 3)),
            mood: 4,
          ),
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 20)),
            mood: 2,
          ),
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 21)),
            mood: 2,
          ),
        ];

        when(
          () => loggingRepository.getLogEntries(userId),
        ).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        expect(
          insights.any(
            (i) =>
                i.title == 'Mood Improvement Detected' &&
                i.type == InsightType.mood,
          ),
          isTrue,
        );
      },
    );

    test('adds "Mood Trend Notice" when recent average is lower', () async {
      // Overall avg = (4+4+4+2+2) / 5 = 3.2
      // Recent avg = (2+2+2) / 3 = 2.0 => declining > 0.5
      final entries = <LogEntryModel>[
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 1)),
          mood: 2,
        ),
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 2)),
          mood: 2,
        ),
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 3)),
          mood: 2,
        ),
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 20)),
          mood: 4,
        ),
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 21)),
          mood: 4,
        ),
      ];

      when(
        () => loggingRepository.getLogEntries(userId),
      ).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      expect(
        insights.any(
          (i) => i.title == 'Mood Trend Notice' && i.type == InsightType.mood,
        ),
        isTrue,
      );
    });

    test('adds "Great Mood Day" when best mood entry is >= 4', () async {
      final entries = <LogEntryModel>[
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 1)),
          mood: 4,
        ),
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 2)),
          mood: 3,
        ),
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 3)),
          mood: 2,
        ),
      ];
      when(
        () => loggingRepository.getLogEntries(userId),
      ).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      final greatMood = insights
          .where((i) => i.title == 'Great Mood Day')
          .toList();
      expect(greatMood, isNotEmpty);
      expect(greatMood.first.type, InsightType.mood);
    });

    test('adds "Consistent Habit" when top habit logged >= 5 times', () async {
      final entries = List.generate(
        5,
        (i) => _entry(
          userId: userId,
          date: fixedNow.subtract(Duration(days: i)),
          mood: 3,
          habits: const ['Meditation'],
        ),
      );
      when(
        () => loggingRepository.getLogEntries(userId),
      ).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      expect(
        insights.any(
          (i) => i.title == 'Consistent Habit' && i.type == InsightType.habit,
        ),
        isTrue,
      );
    });

    test(
      'adds "Habit Variety" when recent 7 days contain >= 3 unique habits',
      () async {
        final entries = <LogEntryModel>[
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 1)),
            habits: const ['Meditation'],
          ),
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 2)),
            habits: const ['Walk'],
          ),
          _entry(
            userId: userId,
            date: fixedNow.subtract(const Duration(days: 3)),
            habits: const ['Journaling'],
          ),
        ];
        when(
          () => loggingRepository.getLogEntries(userId),
        ).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        expect(
          insights.any(
            (i) => i.title == 'Habit Variety' && i.type == InsightType.habit,
          ),
          isTrue,
        );
      },
    );

    test('adds "Logging Milestone" when there are >= 7 entries', () async {
      final entries = List.generate(
        7,
        (i) => _entry(
          userId: userId,
          date: fixedNow.subtract(Duration(days: i)),
          mood: 3,
        ),
      );
      when(
        () => loggingRepository.getLogEntries(userId),
      ).thenAnswer((_) async => entries);

      final insights = await repository.getInsights(userId);
      expect(
        insights.any(
          (i) =>
              i.title == 'Logging Milestone' && i.type == InsightType.general,
        ),
        isTrue,
      );
    });

    test(
      'adds "Pattern Detected" prediction when there are >= 5 mood entries',
      () async {
        // Provide 5 mood entries spread across weekdays. Monday will have the highest avg.
        final monday = DateTime(2026, 3, 23); // Monday
        final entries = <LogEntryModel>[
          _entry(userId: userId, date: monday, mood: 5),
          _entry(
            userId: userId,
            date: monday.subtract(const Duration(days: 7)),
            mood: 5,
          ),
          _entry(
            userId: userId,
            date: monday.add(const Duration(days: 1)),
            mood: 3,
          ), // Tuesday
          _entry(
            userId: userId,
            date: monday.add(const Duration(days: 2)),
            mood: 3,
          ), // Wednesday
          _entry(
            userId: userId,
            date: monday.add(const Duration(days: 3)),
            mood: 3,
          ), // Thursday
        ];

        when(
          () => loggingRepository.getLogEntries(userId),
        ).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        final pattern = insights.singleWhere(
          (i) =>
              i.title == 'Pattern Detected' &&
              i.type == InsightType.prediction,
        );
        expect(pattern.description, contains('Mondays'));
        expect(pattern.description, contains('average 5.0 across 2 entries'));
        expect(pattern.description, contains('2.0 points above'));
      },
    );

    test(
      'does not predict a weekday pattern from single observations',
      () async {
        final monday = DateTime(2026, 3, 23);
        final entries = List.generate(
          5,
          (index) => _entry(
            userId: userId,
            date: monday.add(Duration(days: index)),
            mood: index == 0 ? 5 : 3,
          ),
        );
        when(
          () => loggingRepository.getLogEntries(userId),
        ).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        expect(
          insights.where((i) => i.title == 'Pattern Detected'),
          isEmpty,
        );
      },
    );

    test(
      'does not predict a weekday pattern when averages are too close',
      () async {
        final monday = DateTime(2026, 3, 23);
        final entries = <LogEntryModel>[
          _entry(userId: userId, date: monday, mood: 4),
          _entry(
            userId: userId,
            date: monday.subtract(const Duration(days: 7)),
            mood: 4,
          ),
          _entry(
            userId: userId,
            date: monday.add(const Duration(days: 1)),
            mood: 4,
          ),
          _entry(
            userId: userId,
            date: monday.add(const Duration(days: 2)),
            mood: 3,
          ),
          _entry(
            userId: userId,
            date: monday.add(const Duration(days: 3)),
            mood: 4,
          ),
        ];
        when(
          () => loggingRepository.getLogEntries(userId),
        ).thenAnswer((_) async => entries);

        final insights = await repository.getInsights(userId);
        expect(
          insights.where((i) => i.title == 'Pattern Detected'),
          isEmpty,
        );
      },
    );

    test('getPredictions returns mapped prediction from edge function', () async {
      final entries = <LogEntryModel>[
        _entry(
          userId: userId,
          date: fixedNow.subtract(const Duration(days: 1)),
          mood: 4,
          habits: const ['Meditation'],
          notes: 'Felt grounded',
        ),
      ];

      when(
        () => loggingRepository.getLogEntries(userId),
      ).thenAnswer((_) async => entries);
      when(
        () => functionsClient.invoke(
          'generate-insight',
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => FunctionResponse(
          data: {
            'prediction':
                'Your recent consistency suggests your mood will stay steady if you keep journaling and meditation in place.',
          },
          status: 200,
        ),
      );

      final predictions = await repository.getPredictions(userId);

      expect(predictions, hasLength(1));
      expect(predictions.first.type, InsightType.prediction);
      expect(predictions.first.title, 'AI Prediction');
      expect(
        predictions.first.description,
        contains('Your recent consistency suggests'),
      );
    });

    test(
      'getPredictions returns empty list when edge function fails',
      () async {
        when(
          () => loggingRepository.getLogEntries(userId),
        ).thenAnswer((_) async => [_entry(userId: userId, date: fixedNow)]);
        when(
          () => functionsClient.invoke(
            'generate-insight',
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('edge down'));

        final predictions = await repository.getPredictions(userId);

        expect(predictions, isEmpty);
      },
    );

    test('getFutureLetters returns mapped rows from Supabase', () async {
      final futureLettersBuilder = FakeFutureLettersBuilder([
        {
          'id': 'letter-1',
          'user_id': userId,
          'title': 'A note from tomorrow',
          'content': 'You made it through a difficult stretch.',
          'delivery_date': fixedNow.toIso8601String(),
          'created_at': fixedNow
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        },
      ]);

      when(
        () => supabaseClient.from('future_letters'),
      ).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.select()).thenAnswer((_) => futureLettersBuilder);

      final futureLetters = await repository.getFutureLetters(userId);

      expect(futureLetters, hasLength(1));
      expect(futureLetters.first.userId, userId);
      expect(futureLetters.first.title, 'A note from tomorrow');
      expect(
        futureLetters.first.description,
        'You made it through a difficult stretch.',
      );
      expect(futureLetters.first.type, InsightType.general);
    });

    test('getFutureLetters returns empty list when query fails', () async {
      when(
        () => supabaseClient.from('future_letters'),
      ).thenThrow(Exception('db'));

      final futureLetters = await repository.getFutureLetters(userId);

      expect(futureLetters, isEmpty);
    });
  });
}
