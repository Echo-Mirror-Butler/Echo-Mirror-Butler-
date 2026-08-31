import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/core/sync/conflict_policy.dart';
import 'package:echomirror/core/sync/hlc.dart';
import 'package:echomirror/core/sync/sync_mutation.dart';

void main() {
  group('Conflict Resolution Policies', () {
    group('MoodEntryConflictPolicy', () {
      final policy = MoodEntryConflictPolicy();

      test('merges habits with Set-Union and selects newer mood rating', () {
        final localHlc = Hlc(millis: 1000, counter: 0, nodeId: 'deviceA');
        final remoteHlc = Hlc(millis: 2000, counter: 0, nodeId: 'deviceB');

        final local = {
          'mood': 3,
          'habits': ['running', 'meditation'],
          'notes': 'Morning run',
          'updated_at': '2026-08-29T10:00:00.000Z',
        };

        final remote = {
          'mood': 5,
          'habits': ['meditation', 'reading'],
          'notes': 'Morning run',
          'updated_at': '2026-08-29T11:00:00.000Z',
        };

        final result = policy.resolve(
          local: local,
          remote: remote,
          localHlc: localHlc,
          remoteHlc: remoteHlc,
        );

        final merged = result.resolvedData;
        expect(merged['mood'], 5); // Remote was newer
        expect(merged['habits'], ['meditation', 'reading', 'running']); // Union
        expect(result.hasConflict, isFalse);
      });

      test('notes conflict: surfaces conflicting note in backup metadata without silent loss', () {
        final localHlc = Hlc(millis: 1000, counter: 0, nodeId: 'deviceA');
        final remoteHlc = Hlc(millis: 2000, counter: 0, nodeId: 'deviceB');

        final local = {
          'mood': 4,
          'habits': ['walk'],
          'notes': 'Device A unique thought about the day',
          'updated_at': '2026-08-29T10:00:00.000Z',
        };

        final remote = {
          'mood': 4,
          'habits': ['walk'],
          'notes': 'Device B edited reflections during offline evening',
          'updated_at': '2026-08-29T11:00:00.000Z',
        };

        final result = policy.resolve(
          local: local,
          remote: remote,
          localHlc: localHlc,
          remoteHlc: remoteHlc,
        );

        final merged = result.resolvedData;
        expect(result.hasConflict, isTrue);
        expect(merged['notes'], 'Device B edited reflections during offline evening');
        expect(merged['conflict_surfaced'], isTrue);
        expect(merged['conflicted_note_backup'], 'Device A unique thought about the day');
        expect(result.surfacedConflicts['conflicting_notes'], 'Device A unique thought about the day');
      });
    });

    group('HabitLogConflictPolicy', () {
      final policy = HabitLogConflictPolicy();

      test('Add-Wins / boolean OR ensures completion on any device is preserved', () {
        final localHlc = Hlc(millis: 1000, counter: 0, nodeId: 'deviceA');
        final remoteHlc = Hlc(millis: 2000, counter: 0, nodeId: 'deviceB');

        final local = {
          'completed': true,
          'habits': ['stretching'],
          'streak': 7,
        };

        final remote = {
          'completed': false,
          'habits': ['water'],
          'streak': 6,
        };

        final result = policy.resolve(
          local: local,
          remote: remote,
          localHlc: localHlc,
          remoteHlc: remoteHlc,
        );

        final merged = result.resolvedData;
        expect(merged['completed'], isTrue); // true || false = true
        expect(merged['habits'], ['stretching', 'water']); // Union
        expect(merged['streak'], 7); // Max streak
      });
    });

    group('FollowConflictPolicy', () {
      final policy = FollowConflictPolicy();

      test('Causal Last-State-Wins based on HLC orders follow vs unfollow', () {
        final followHlc = Hlc(millis: 1000, counter: 0, nodeId: 'deviceA');
        final unfollowHlc = Hlc(millis: 2000, counter: 0, nodeId: 'deviceB');

        final followData = {
          'follower_id': 'u1',
          'following_id': 'u2',
          'active': true,
        };

        final unfollowData = {
          'follower_id': 'u1',
          'following_id': 'u2',
          'active': false,
        };

        // Unfollow happened later (unfollowHlc > followHlc)
        final result = policy.resolve(
          local: followData,
          remote: unfollowData,
          localHlc: followHlc,
          remoteHlc: unfollowHlc,
        );

        expect(result.resolvedData['active'], isFalse);
      });
    });

    group('StoryConflictPolicy', () {
      final policy = StoryConflictPolicy();

      test('Viewed_by list merges as Set-Union and view count takes maximum', () {
        final localHlc = Hlc(millis: 1000, counter: 0, nodeId: 'deviceA');
        final remoteHlc = Hlc(millis: 2000, counter: 0, nodeId: 'deviceB');

        final local = {
          'id': 101,
          'view_count': 3,
          'viewed_by': ['user_1', 'user_2'],
        };

        final remote = {
          'id': 101,
          'view_count': 2,
          'viewed_by': ['user_2', 'user_3'],
        };

        final result = policy.resolve(
          local: local,
          remote: remote,
          localHlc: localHlc,
          remoteHlc: remoteHlc,
        );

        final merged = result.resolvedData;
        expect((merged['viewed_by'] as List).toSet(), {'user_1', 'user_2', 'user_3'});
        expect(merged['view_count'], 3);
      });
    });

    group('GiftConflictPolicy', () {
      final policy = GiftConflictPolicy();

      test('Completed transaction status is terminal and preserves Stellar hash', () {
        final pendingHlc = Hlc(millis: 2000, counter: 0, nodeId: 'deviceB');
        final completedHlc = Hlc(millis: 1000, counter: 0, nodeId: 'deviceA');

        final localCompleted = {
          'id': 'tx-123',
          'status': 'completed',
          'stellar_tx_hash': 'txhash999',
        };

        final remotePending = {
          'id': 'tx-123',
          'status': 'pending',
          'stellar_tx_hash': null,
        };

        final result = policy.resolve(
          local: localCompleted,
          remote: remotePending,
          localHlc: completedHlc,
          remoteHlc: pendingHlc,
        );

        expect(result.resolvedData['status'], 'completed');
        expect(result.resolvedData['stellar_tx_hash'], 'txhash999');
      });
    });

    group('ConflictPolicyRegistry', () {
      test('resolves registered policy for every SyncEntityType', () {
        for (final type in SyncEntityType.values) {
          final policy = ConflictPolicyRegistry.getPolicy(type);
          expect(policy, isNotNull);
        }
      });
    });
  });
}
