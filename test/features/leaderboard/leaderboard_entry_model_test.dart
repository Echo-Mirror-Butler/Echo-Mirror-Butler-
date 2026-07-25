import 'package:echomirror/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #599 — unit coverage for [LeaderboardEntryModel].
void main() {
  group('LeaderboardEntryModel.fromJson', () {
    test('parses a fully populated row', () {
      final model = LeaderboardEntryModel.fromJson(<String, dynamic>{
        'id': 'user-1',
        'display_name': 'Jane Doe',
        'avatar_url': 'https://example.com/a.png',
        'leaderboard_anonymous': false,
        'echo_earned_this_week': 250,
        'rank': 3,
      });

      expect(model.id, 'user-1');
      expect(model.displayName, 'Jane Doe');
      expect(model.avatarUrl, 'https://example.com/a.png');
      expect(model.leaderboardAnonymous, isFalse);
      expect(model.echoEarnedThisWeek, 250);
      expect(model.rank, 3);
    });

    test('handles a missing avatar and missing display name', () {
      final model = LeaderboardEntryModel.fromJson(<String, dynamic>{
        'id': 'user-2',
        'echo_earned_this_week': 10,
        'rank': 7,
      });

      expect(model.avatarUrl, isNull);
      expect(model.displayName, isNull);
      expect(model.leaderboardAnonymous, isFalse);
    });

    test('defaults echo and rank to 0 when null/absent', () {
      final model = LeaderboardEntryModel.fromJson(<String, dynamic>{
        'id': 'user-3',
        'echo_earned_this_week': null,
        'rank': null,
      });

      expect(model.echoEarnedThisWeek, 0);
      expect(model.rank, 0);
    });

    test('coerces numeric echo/rank from num to int', () {
      final model = LeaderboardEntryModel.fromJson(<String, dynamic>{
        'id': 'user-4',
        'echo_earned_this_week': 42.0,
        'rank': 2.0,
      });

      expect(model.echoEarnedThisWeek, 42);
      expect(model.rank, 2);
    });

    test('reads the anonymous flag when true', () {
      final model = LeaderboardEntryModel.fromJson(<String, dynamic>{
        'id': 'user-5',
        'display_name': 'Secret',
        'leaderboard_anonymous': true,
        'echo_earned_this_week': 5,
        'rank': 9,
      });

      expect(model.leaderboardAnonymous, isTrue);
    });
  });

  group('LeaderboardEntryModel.toJson', () {
    test('round-trips through fromJson/toJson', () {
      const original = LeaderboardEntryModel(
        id: 'user-6',
        displayName: 'Round Trip',
        avatarUrl: 'https://example.com/b.png',
        leaderboardAnonymous: true,
        echoEarnedThisWeek: 77,
        rank: 4,
      );

      final restored = LeaderboardEntryModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.displayName, original.displayName);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.leaderboardAnonymous, original.leaderboardAnonymous);
      expect(restored.echoEarnedThisWeek, original.echoEarnedThisWeek);
      expect(restored.rank, original.rank);
    });
  });

  group('displayText', () {
    test('returns "Anonymous" when anonymous regardless of name', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        displayName: 'Real Name',
        leaderboardAnonymous: true,
        echoEarnedThisWeek: 1,
        rank: 1,
      );
      expect(model.displayText, 'Anonymous');
    });

    test('returns the display name when present and not anonymous', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        displayName: 'Real Name',
        echoEarnedThisWeek: 1,
        rank: 1,
      );
      expect(model.displayText, 'Real Name');
    });

    test('falls back to "User" when the name is empty', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        displayName: '',
        echoEarnedThisWeek: 1,
        rank: 1,
      );
      expect(model.displayText, 'User');
    });
  });

  group('initials', () {
    test('returns "A" when anonymous', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        displayName: 'Jane Doe',
        leaderboardAnonymous: true,
        echoEarnedThisWeek: 1,
        rank: 1,
      );
      expect(model.initials, 'A');
    });

    test('uses first letters of first two words', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        displayName: 'jane doe',
        echoEarnedThisWeek: 1,
        rank: 1,
      );
      expect(model.initials, 'JD');
    });

    test('uses the first letter for a single-word name', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        displayName: 'madonna',
        echoEarnedThisWeek: 1,
        rank: 1,
      );
      expect(model.initials, 'M');
    });

    test('returns "?" when there is no name', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        echoEarnedThisWeek: 1,
        rank: 1,
      );
      expect(model.initials, '?');
    });
  });

  group('copyWith', () {
    test('overrides only the provided fields', () {
      const model = LeaderboardEntryModel(
        id: 'u',
        displayName: 'Old',
        echoEarnedThisWeek: 1,
        rank: 10,
      );

      final updated = model.copyWith(displayName: 'New', rank: 1);

      expect(updated.displayName, 'New');
      expect(updated.rank, 1);
      expect(updated.id, 'u');
      expect(updated.echoEarnedThisWeek, 1);
    });
  });
}
