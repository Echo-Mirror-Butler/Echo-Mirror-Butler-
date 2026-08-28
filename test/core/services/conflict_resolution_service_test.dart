import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/core/models/local_models.dart';
import 'package:echomirror/core/services/conflict_resolution_service.dart';

void main() {
  late ConflictResolutionService resolver;

  setUp(() {
    resolver = ConflictResolutionService.instance;
  });

  group('ConflictResolutionService (Issue #702)', () {
    test('non-diverging server record returns hadConflict: false without mutation', () {
      final baseTime = DateTime.utc(2026, 8, 1, 10, 0);
      final local = LocalLogEntry(
        id: 'entry-1',
        userId: 'user-1',
        date: '2026-08-01',
        mood: 4,
        habits: ['meditate'],
        notes: 'Feeling calm',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      final server = {
        'id': 'entry-1',
        'mood': 4,
        'habits': ['meditate'],
        'notes': 'Feeling calm',
        'created_at': baseTime.toIso8601String(),
        'updated_at': baseTime.toIso8601String(),
      };

      final result = resolver.resolveLogEntry(local: local, server: server);

      expect(result.hadConflict, isFalse);
      expect(result.resolvedPayload['mood'], equals(4));
      expect(result.resolvedPayload['notes'], equals('Feeling calm'));
    });

    test('smartFieldMerge unions habits non-destructively and preserves both notes', () {
      final baseTime = DateTime.utc(2026, 8, 1, 10, 0);
      final serverEditTime = DateTime.utc(2026, 8, 1, 12, 0);
      final offlineLocalEditTime = DateTime.utc(2026, 8, 1, 14, 0);

      // Local offline edit: added 'walk' habit, changed mood to 5, updated notes
      final local = LocalLogEntry(
        id: 'entry-1',
        userId: 'user-1',
        date: '2026-08-01',
        mood: 5,
        habits: ['meditate', 'walk'],
        notes: 'Walked 5 miles outdoors in the evening.',
        createdAt: baseTime,
        updatedAt: offlineLocalEditTime,
      );

      // Server record modified in parallel: added 'read' habit, AI insight in notes
      final server = {
        'id': 'entry-1',
        'mood': 3,
        'habits': ['meditate', 'read'],
        'notes': 'Morning mood analysis: elevated stress noted.',
        'created_at': baseTime.toIso8601String(),
        'updated_at': serverEditTime.toIso8601String(),
      };

      final result = resolver.resolveLogEntry(local: local, server: server);

      expect(result.hadConflict, isTrue);

      // 1. Mood: Local was newer (14:00 > 12:00), so local mood (5) wins
      expect(result.resolvedPayload['mood'], equals(5));

      // 2. Habits: Set union of both (['meditate', 'read', 'walk'])
      final resolvedHabits = (result.resolvedPayload['habits'] as List).cast<String>();
      expect(resolvedHabits, containsAll(['meditate', 'read', 'walk']));
      expect(resolvedHabits.length, equals(3));

      // 3. Notes: Non-destructive preservation of both revisions
      final resolvedNotes = result.resolvedPayload['notes'] as String;
      expect(resolvedNotes.contains('Morning mood analysis'), isTrue);
      expect(resolvedNotes.contains('Walked 5 miles outdoors'), isTrue);
    });

    test('serverWins strategy strictly honors remote server record', () {
      final baseTime = DateTime.utc(2026, 8, 1, 10, 0);
      final serverEditTime = DateTime.utc(2026, 8, 1, 12, 0);

      final local = LocalLogEntry(
        id: 'entry-1',
        userId: 'user-1',
        date: '2026-08-01',
        mood: 5,
        habits: ['walk'],
        notes: 'Local offline note',
        createdAt: baseTime,
        updatedAt: DateTime.utc(2026, 8, 1, 14, 0),
      );

      final server = {
        'id': 'entry-1',
        'mood': 2,
        'habits': ['hydrate'],
        'notes': 'Server authoritative note',
        'created_at': baseTime.toIso8601String(),
        'updated_at': serverEditTime.toIso8601String(),
      };

      final result = resolver.resolveLogEntry(
        local: local,
        server: server,
        strategyOverride: ConflictResolutionStrategy.serverWins,
      );

      expect(result.hadConflict, isTrue);
      expect(result.resolvedPayload['mood'], equals(2));
      expect(result.resolvedPayload['habits'], equals(['hydrate']));
      expect(result.resolvedPayload['notes'], equals('Server authoritative note'));
    });
  });
}
