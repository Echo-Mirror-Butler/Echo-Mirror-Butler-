import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echomirror/features/logging/viewmodel/providers/logging_provider.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';

class MockLoggingRepository extends Mock implements LoggingRepository {}

LogEntryModel _makeEntry({
  String id = 'entry_1',
  String userId = 'user_1',
  int mood = 3,
}) {
  final now = DateTime(2025, 6, 1);
  return LogEntryModel(
    id: id,
    userId: userId,
    date: now,
    mood: mood,
    habits: const ['exercise'],
    notes: 'test note',
    createdAt: now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_makeEntry());
  });

  group('LoggingNotifier', () {
    late MockLoggingRepository mockRepo;
    late LoggingNotifier notifier;

    setUp(() {
      mockRepo = MockLoggingRepository();
      notifier = LoggingNotifier(mockRepo);
    });

    test('initial state is AsyncData([])', () {
      expect(notifier.state, const AsyncValue<List<LogEntryModel>>.data([]));
    });

    test(
      'loadLogEntries returns empty data when userId is null or empty',
      () async {
        await notifier.loadLogEntries(userId: null);
        expect(notifier.state, const AsyncValue<List<LogEntryModel>>.data([]));

        await notifier.loadLogEntries(userId: '');
        expect(notifier.state, const AsyncValue<List<LogEntryModel>>.data([]));

        verifyNever(() => mockRepo.getLogEntries(any()));
      },
    );

    test(
      'loadLogEntries — success: state becomes AsyncData with list',
      () async {
        final entries = [_makeEntry(id: 'e1'), _makeEntry(id: 'e2')];
        when(
          () => mockRepo.getLogEntries('user_1'),
        ).thenAnswer((_) async => entries);

        await notifier.loadLogEntries(userId: 'user_1');

        expect(notifier.state, AsyncValue<List<LogEntryModel>>.data(entries));
        verify(() => mockRepo.getLogEntries('user_1')).called(1);
      },
    );

    test('loadLogEntries — failure: state becomes AsyncError', () async {
      when(
        () => mockRepo.getLogEntries('user_err'),
      ).thenThrow(Exception('network error'));

      await notifier.loadLogEntries(userId: 'user_err');

      expect(notifier.state, isA<AsyncError>());
    });

    test(
      'loadLogEntries does not reload when already loaded for same user',
      () async {
        final entries = [_makeEntry()];
        when(
          () => mockRepo.getLogEntries('user_1'),
        ).thenAnswer((_) async => entries);

        await notifier.loadLogEntries(userId: 'user_1');
        await notifier.loadLogEntries(userId: 'user_1');

        verify(() => mockRepo.getLogEntries('user_1')).called(1);
      },
    );

    test(
      'loadLogEntries skips concurrent calls while already loading',
      () async {
        final entries = [_makeEntry()];
        when(
          () => mockRepo.getLogEntries('user_1'),
        ).thenAnswer((_) async => entries);

        // Fire two concurrent calls without awaiting the first
        final first = notifier.loadLogEntries(userId: 'user_1');
        final second = notifier.loadLogEntries(userId: 'user_1');
        await Future.wait([first, second]);

        verify(() => mockRepo.getLogEntries('user_1')).called(1);
      },
    );

    test(
      'createLogEntry — returns true on success and appends entry to state',
      () async {
        final existing = _makeEntry(id: 'e_old');
        final newEntry = _makeEntry(id: 'e_new', mood: 5);
        final created = _makeEntry(id: 'e_new_server', mood: 5);

        when(
          () => mockRepo.getLogEntries('user_1'),
        ).thenAnswer((_) async => [existing]);
        when(
          () => mockRepo.createLogEntry(any()),
        ).thenAnswer((_) async => created);

        await notifier.loadLogEntries(userId: 'user_1');
        final result = await notifier.createLogEntry(newEntry);

        expect(result, isTrue);
        final data = notifier.state.value;
        expect(data, isNotNull);
        expect(data!.length, 2);
        expect(data.last, created);
      },
    );

    test('createLogEntry — returns false on repository error', () async {
      when(
        () => mockRepo.createLogEntry(any()),
      ).thenThrow(Exception('write failed'));

      final result = await notifier.createLogEntry(_makeEntry());

      expect(result, isFalse);
      expect(notifier.state, isA<AsyncError>());
    });

    test(
      'updateLogEntry — returns true on success and updates entry in state',
      () async {
        final original = _makeEntry(id: 'e1', mood: 2);
        final updated = _makeEntry(id: 'e1', mood: 4);

        when(
          () => mockRepo.getLogEntries('user_1'),
        ).thenAnswer((_) async => [original]);
        when(
          () => mockRepo.updateLogEntry(any()),
        ).thenAnswer((_) async => updated);

        await notifier.loadLogEntries(userId: 'user_1');
        final result = await notifier.updateLogEntry(updated);

        expect(result, isTrue);
        final data = notifier.state.value;
        expect(data, isNotNull);
        expect(data!.first.mood, 4);
      },
    );

    test('updateLogEntry — returns false on repository error', () async {
      when(
        () => mockRepo.updateLogEntry(any()),
      ).thenThrow(Exception('update failed'));

      final result = await notifier.updateLogEntry(_makeEntry());

      expect(result, isFalse);
      expect(notifier.state, isA<AsyncError>());
    });

    test('deleteLogEntry — removes entry from state', () async {
      final e1 = _makeEntry(id: 'e1');
      final e2 = _makeEntry(id: 'e2', mood: 5);

      when(
        () => mockRepo.getLogEntries('user_1'),
      ).thenAnswer((_) async => [e1, e2]);
      when(
        () => mockRepo.deleteLogEntry(any(), any()),
      ).thenAnswer((_) async {});

      await notifier.loadLogEntries(userId: 'user_1');
      final result = await notifier.deleteLogEntry('e1', 'user_1');

      expect(result, isTrue);
      final data = notifier.state.value;
      expect(data, isNotNull);
      expect(data!.length, 1);
      expect(data.first.id, 'e2');
    });

    test('deleteLogEntry — returns false on repository error', () async {
      when(
        () => mockRepo.getLogEntries('user_1'),
      ).thenAnswer((_) async => [_makeEntry()]);
      when(
        () => mockRepo.deleteLogEntry(any(), any()),
      ).thenThrow(Exception('delete failed'));

      await notifier.loadLogEntries(userId: 'user_1');
      final result = await notifier.deleteLogEntry('e1', 'user_1');

      expect(result, isFalse);
      expect(notifier.state, isA<AsyncError>());
    });

    test('getLogEntryForDate — returns null when userId is not set', () async {
      final result = await notifier.getLogEntryForDate(DateTime(2025, 6, 1));
      expect(result, isNull);
    });

    test(
      'getLogEntryForDate — returns entry from repository when userId is set',
      () async {
        final date = DateTime(2025, 6, 1);
        final entry = _makeEntry();

        when(
          () => mockRepo.getLogEntries('user_1'),
        ).thenAnswer((_) async => [entry]);
        when(
          () => mockRepo.getLogEntryForDate(date, 'user_1'),
        ).thenAnswer((_) async => entry);

        await notifier.loadLogEntries(userId: 'user_1');
        final result = await notifier.getLogEntryForDate(date);

        expect(result, entry);
      },
    );

    test(
      'getLogEntryForDate — returns null when repository returns null',
      () async {
        final date = DateTime(2025, 6, 2);

        when(
          () => mockRepo.getLogEntries('user_1'),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepo.getLogEntryForDate(date, 'user_1'),
        ).thenAnswer((_) async => null);

        await notifier.loadLogEntries(userId: 'user_1');
        final result = await notifier.getLogEntryForDate(date);

        expect(result, isNull);
      },
    );

    test('loggingProvider creates a LoggingNotifier via ProviderContainer', () {
      final container = ProviderContainer(
        overrides: [loggingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      final state = container.read(loggingProvider);
      expect(state, const AsyncValue<List<LogEntryModel>>.data([]));
    });
  });
}
