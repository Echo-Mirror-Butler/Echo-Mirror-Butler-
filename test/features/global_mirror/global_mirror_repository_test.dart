import 'dart:async';

import 'package:echomirror/features/global_mirror/data/models/mood_pin_model.dart';
import 'package:echomirror/features/global_mirror/data/models/video_post_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/global_mirror_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

class MockPosition extends Mock implements Position {}

class FakePostgrestBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  final dynamic _result;
  FakePostgrestBuilder([this._result]);

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> neq(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> gt(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> gte(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> lt(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> lte(String column, Object value) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> match(Map<String, Object> query) => this;
  @override
  PostgrestFilterBuilder<PostgrestList> filter(String column, String operator, Object? value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> limit(int count, {String? referencedTable}) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> range(
    int from,
    int to, {
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap> single() =>
      _FakeSingleBuilder(_result);

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeMaybeSingleBuilder(_result);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList) onValue, {
    Function? onError,
  }) {
    final list =
        _result is List<Map<String, dynamic>>
            ? _result
            : _result is Map<String, dynamic>
            ? [_result]
            : _result is List
            ? _result.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];
    return Future.value(list).then(onValue, onError: onError);
  }
}

class _FakeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap> {
  final dynamic _result;
  _FakeSingleBuilder(this._result);

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) =>
      FakePostgrestBuilder(_result);

  @override
  PostgrestTransformBuilder<PostgrestMap> order(
    String column, {
    bool ascending = true,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap> limit(int count, {String? referencedTable}) => this;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestMap) onValue, {
    Function? onError,
  }) {
    final map = _result is List && _result.isNotEmpty
        ? _result.first as Map<String, dynamic>
        : _result as Map<String, dynamic>;
    return Future.value(map).then(onValue, onError: onError);
  }
}

class _FakeMaybeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap?> {
  final dynamic _result;
  _FakeMaybeSingleBuilder(this._result);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestMap?) onValue, {
    Function? onError,
  }) {
    return Future.value(
      _result as PostgrestMap?,
    ).then(onValue, onError: onError);
  }
}

// Fake stream builder that returns a controllable stream
class MockSupabaseStreamBuilder extends Mock
    implements SupabaseStreamFilterBuilder {}


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

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(const LocationSettings());
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    repository = GlobalMirrorRepository(supabaseClient: mockSupabase);

    // Mock Geolocator
    final mockGeolocatorPlatform = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocatorPlatform;

    when(() => mockGeolocatorPlatform.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(
      () => mockGeolocatorPlatform.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer(
      (_) async => Position(
        latitude: 51.52,
        longitude: -0.13,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ),
    );
  });

  // -------------------------------------------------------------------------
  // addMoodPin
  // -------------------------------------------------------------------------

  group('addMoodPin', () {
    setUp(() {
      when(
        () => mockSupabase.from('mood_pins'),
      ).thenAnswer((_) => mockQueryBuilder);
    });

    test('returns non-null ID on success', () async {
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenReturn(FakePostgrestBuilder(_moodPinJson()));

      final result = await repository.addMoodPin(
        sentiment: 'positive',
        latitude: 51.52,
        longitude: -0.13,
      );

      expect(result, 'pin-1');
    });

    test('inserts anonymized coordinates', () async {
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenReturn(FakePostgrestBuilder(_moodPinJson()));

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

  group('addComment', () {
    setUp(() {
      when(
        () => mockSupabase.from('mood_pin_comments'),
      ).thenAnswer((_) => mockQueryBuilder);
      // auth.currentUser returns null in tests — that's fine
      when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());
    });

    test('returns non-null ID on success', () async {
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenReturn(FakePostgrestBuilder(_commentJson()));

      final result = await repository.addComment(
        moodPinId: 'pin-1',
        text: 'Feeling this too',
      );

      expect(result, 'comment-1');
    });

    test('inserts correct mood_pin_id and text', () async {
      when(
        () => mockQueryBuilder.insert(any()),
      ).thenReturn(FakePostgrestBuilder(_commentJson()));

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

  group('getVideoFeed', () {
    setUp(() {
      when(
        () => mockSupabase.from('video_posts'),
      ).thenAnswer((_) => mockQueryBuilder);
    });

    test('returns list of VideoPostModel on success', () async {
      when(
        () => mockQueryBuilder.select(),
      ).thenReturn(FakePostgrestBuilder([_videoPostJson()]));

      final result = await repository.getVideoFeed();

      expect(result, hasLength(1));
      expect(result.first, isA<VideoPostModel>());
      expect(result.first.id, 'post-1');
      expect(result.first.videoUrl, 'https://example.com/video.mp4');
      expect(result.first.moodTag, 'happy');
    });

    test('returns paginated results using offset and limit', () async {
      when(
        () => mockQueryBuilder.select(),
      ).thenReturn(FakePostgrestBuilder([_videoPostJson(id: 'post-2')]));

      final result = await repository.getVideoFeed(offset: 10, limit: 5);

      expect(result, hasLength(1));
      expect(result.first.id, 'post-2');
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

  group('streamMoodPins', () {
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
