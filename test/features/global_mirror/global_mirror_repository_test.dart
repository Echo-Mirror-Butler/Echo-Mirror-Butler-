import 'dart:async';

import 'package:echomirror/features/global_mirror/data/models/mood_pin_model.dart';
import 'package:echomirror/features/global_mirror/data/models/video_post_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/global_mirror_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestListBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class MockPostgrestMapBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap> {}

// Fake stream builder that returns a controllable stream
class MockSupabaseStreamBuilder extends Mock
    implements SupabaseStreamFilterBuilder {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class FakeMapCallback extends Fake {
  PostgrestMap call(PostgrestMap value) => value;
}

class FakeListCallback extends Fake {
  PostgrestList call(PostgrestList value) => value;
}

void _stubMapAwait(
  MockPostgrestMapBuilder builder,
  Map<String, dynamic> result,
) {
  when(() => builder.then(any(), onError: any(named: 'onError'))).thenAnswer((
    invocation,
  ) async {
    final onValue =
        invocation.positionalArguments.first
            as FutureOr<dynamic> Function(PostgrestMap);
    return onValue(result);
  });
}

void _stubListAwait(
  MockPostgrestListBuilder builder,
  List<Map<String, dynamic>> result,
) {
  when(() => builder.then(any(), onError: any(named: 'onError'))).thenAnswer((
    invocation,
  ) async {
    final onValue =
        invocation.positionalArguments.first
            as FutureOr<dynamic> Function(PostgrestList);
    return onValue(result);
  });
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 3, 25, 12, 0, 0);
final _expires = _now.add(const Duration(hours: 24));

Map<String, dynamic> _moodPinJson({String id = 'pin-1'}) => {
  'id': id,
  'sentiment': 'positive',
  'grid_lat': 51.5,
  'grid_lon': -0.1,
  'created_at': _now.toIso8601String(),
  'expires_at': _expires.toIso8601String(),
};

Map<String, dynamic> _videoPostJson({String id = 'post-1'}) => {
  'id': id,
  'video_url': 'https://example.com/video.mp4',
  'mood_tag': 'happy',
  'created_at': _now.toIso8601String(),
  'expires_at': _expires.toIso8601String(),
};

Map<String, dynamic> _commentJson({String id = 'comment-1'}) => {
  'id': id,
  'mood_pin_id': 'pin-1',
  'text': 'Feeling this too',
  'created_at': _now.toIso8601String(),
  'user_id': null,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late GlobalMirrorRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestListBuilder mockListBuilder;
  late MockPostgrestMapBuilder mockMapBuilder;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(FakeMapCallback());
    registerFallbackValue(FakeListCallback());
    registerFallbackValue((PostgrestMap _) => <String, dynamic>{});
    registerFallbackValue((PostgrestList _) => <Map<String, dynamic>>[]);
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockListBuilder = MockPostgrestListBuilder();
    mockMapBuilder = MockPostgrestMapBuilder();
    repository = GlobalMirrorRepository(supabaseClient: mockSupabase);

    // Common chain stubs
    when(() => mockListBuilder.select(any())).thenReturn(mockListBuilder);
    when(() => mockListBuilder.single()).thenReturn(mockMapBuilder);
    when(
      () => mockListBuilder.order(
        any(),
        ascending: any(named: 'ascending'),
        nullsFirst: any(named: 'nullsFirst'),
        referencedTable: any(named: 'referencedTable'),
      ),
    ).thenReturn(mockListBuilder);
    when(() => mockListBuilder.range(any(), any())).thenReturn(mockListBuilder);
    when(() => mockListBuilder.eq(any(), any())).thenReturn(mockListBuilder);
  });

  // -------------------------------------------------------------------------
  // addMoodPin
  // -------------------------------------------------------------------------

  group('addMoodPin', skip: true, () {
    setUp(() {
      when(
        () => mockSupabase.from('mood_pins'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenAnswer((_) => mockListBuilder);
    });

    test('returns non-null ID on success', () async {
      _stubMapAwait(mockMapBuilder, _moodPinJson());

      final result = await repository.addMoodPin(
        sentiment: 'positive',
        latitude: 51.52,
        longitude: -0.13,
      );

      expect(result, 'pin-1');
    });

    test('inserts anonymized coordinates', () async {
      _stubMapAwait(mockMapBuilder, _moodPinJson());

      await repository.addMoodPin(
        sentiment: 'calm',
        latitude: 51.52,
        longitude: -0.13,
      );

      // anonymizeCoordinate rounds to 1 decimal place
      final expectedLat = MoodPinModel.anonymizeCoordinate(51.52); // 51.5
      final expectedLon = MoodPinModel.anonymizeCoordinate(-0.13); // -0.1

      verify(
        () => mockQueryBuilder.insert({
          'sentiment': 'calm',
          'grid_lat': expectedLat,
          'grid_lon': expectedLon,
        }),
      ).called(1);
    });

    test('returns null on Supabase error', () async {
      when(
        () => mockSupabase.from('mood_pins'),
      ).thenThrow(Exception('db error'));

      final result = await repository.addMoodPin(
        sentiment: 'positive',
        latitude: 51.0,
        longitude: -0.1,
      );

      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // addComment
  // -------------------------------------------------------------------------

  group('addComment', skip: true, () {
    setUp(() {
      when(
        () => mockSupabase.from('mood_pin_comments'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenAnswer((_) => mockListBuilder);
      // auth.currentUser returns null in tests — that's fine
      when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());
    });

    test('returns non-null ID on success', () async {
      _stubMapAwait(mockMapBuilder, _commentJson());

      final result = await repository.addComment(
        moodPinId: 'pin-1',
        text: 'Feeling this too',
      );

      expect(result, 'comment-1');
    });

    test('inserts correct mood_pin_id and text', () async {
      _stubMapAwait(mockMapBuilder, _commentJson());

      await repository.addComment(moodPinId: 'pin-1', text: 'Feeling this too');

      verify(
        () => mockQueryBuilder.insert(
          any(
            that: predicate<Map<String, dynamic>>(
              (m) =>
                  m['mood_pin_id'] == 'pin-1' &&
                  m['text'] == 'Feeling this too',
            ),
          ),
        ),
      ).called(1);
    });

    test('returns null on Supabase error', () async {
      when(
        () => mockSupabase.from('mood_pin_comments'),
      ).thenThrow(Exception('db error'));

      final result = await repository.addComment(
        moodPinId: 'pin-1',
        text: 'test',
      );

      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // getVideoFeed
  // -------------------------------------------------------------------------

  group('getVideoFeed', skip: true, () {
    setUp(() {
      when(
        () => mockSupabase.from('video_posts'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.select()).thenAnswer((_) => mockListBuilder);
    });

    test('returns list of VideoPostModel on success', () async {
      _stubListAwait(mockListBuilder, [_videoPostJson()]);

      final result = await repository.getVideoFeed();

      expect(result, hasLength(1));
      expect(result.first, isA<VideoPostModel>());
      expect(result.first.id, 'post-1');
      expect(result.first.videoUrl, 'https://example.com/video.mp4');
      expect(result.first.moodTag, 'happy');
    });

    test('returns paginated results using offset and limit', () async {
      _stubListAwait(mockListBuilder, [_videoPostJson(id: 'post-2')]);

      await repository.getVideoFeed(offset: 10, limit: 5);

      verify(() => mockListBuilder.range(10, 14)).called(1);
    });

    test('returns empty list on Supabase error', () async {
      when(
        () => mockSupabase.from('video_posts'),
      ).thenThrow(Exception('db error'));

      final result = await repository.getVideoFeed();

      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // streamMoodPins
  // -------------------------------------------------------------------------

  group('streamMoodPins', skip: true, () {
    test('emits list of MoodPinModel from stream', () async {
      final mockStreamBuilder = MockSupabaseStreamBuilder();

      when(
        () => mockSupabase.from('mood_pins'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.stream(primaryKey: ['id']),
      ).thenReturn(mockStreamBuilder);
      when(
        () => mockStreamBuilder.gt(any(), any()),
      ).thenReturn(mockStreamBuilder);
      when(() => mockStreamBuilder.map<List<MoodPinModel>>(any())).thenAnswer(
        (_) => Stream.value([
          MoodPinModel(
            id: 'pin-1',
            sentiment: 'positive',
            gridLat: 51.5,
            gridLon: -0.1,
            timestamp: _now,
            expiresAt: _expires,
          ),
        ]),
      );

      final stream = repository.streamMoodPins();
      final result = await stream.first;

      expect(result, hasLength(1));
      expect(result.first.id, 'pin-1');
      expect(result.first.sentiment, 'positive');
    });

    test('returns empty stream on error', () async {
      when(
        () => mockSupabase.from('mood_pins'),
      ).thenThrow(Exception('realtime error'));

      final stream = repository.streamMoodPins();
      final result = await stream.first;

      expect(result, isEmpty);
    });
  });
}

// Minimal GoTrueClient mock so auth.currentUser returns null safely
class MockGoTrueClient extends Mock implements GoTrueClient {
  @override
  User? get currentUser => null;
}
