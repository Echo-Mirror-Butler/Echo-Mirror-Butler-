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

class MockSupabaseStreamBuilder extends Mock
    implements SupabaseStreamFilterBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap> {}

class MockPostgrestListTransformBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestList> {}
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
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockPostgrestTransformBuilder mockTransformBuilder;
  late MockPostgrestListTransformBuilder mockListTransformBuilder;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(const LocationSettings());
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockTransformBuilder = MockPostgrestTransformBuilder();
    mockListTransformBuilder = MockPostgrestListTransformBuilder();
    
    repository = GlobalMirrorRepository(supabaseClient: mockSupabase);

    // Default builder chaining stubs
    when(() => mockFilterBuilder.select(any())).thenReturn(mockFilterBuilder);
    when(() => mockFilterBuilder.eq(any(), any())).thenReturn(mockFilterBuilder);
    when(() => mockFilterBuilder.single()).thenReturn(mockTransformBuilder);
    when(() => mockFilterBuilder.maybeSingle()).thenReturn(mockTransformBuilder);
    when(() => mockFilterBuilder.order(any(), 
      ascending: any(named: 'ascending'),
      nullsFirst: any(named: 'nullsFirst'),
      referencedTable: any(named: 'referencedTable'),
    )).thenReturn(mockFilterBuilder);

    when(() => mockListTransformBuilder.order(any(),
      ascending: any(named: 'ascending'),
      nullsFirst: any(named: 'nullsFirst'),
      referencedTable: any(named: 'referencedTable'),
    )).thenReturn(mockListTransformBuilder);
    when(() => mockListTransformBuilder.range(any(), any(),
      referencedTable: any(named: 'referencedTable'),
    )).thenReturn(mockListTransformBuilder);

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
      when(() => mockQueryBuilder.insert(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.single()).thenReturn(mockTransformBuilder);
      when(() => mockTransformBuilder.then(any())).thenAnswer((invocation) {
        final onValue = invocation.positionalArguments[0] as FutureOr<PostgrestMap> Function(PostgrestMap);
        return Future.value(onValue({'id': 'pin-1'}));
      });

      final result = await repository.addMoodPin(
        sentiment: 'positive',
        latitude: 51.52,
        longitude: -0.13,
      );

      expect(result, 'pin-1');
    });

    test('inserts anonymized coordinates', () async {
      when(() => mockQueryBuilder.insert(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.single()).thenReturn(mockTransformBuilder);
      when(() => mockTransformBuilder.then(any())).thenAnswer((invocation) {
        final onValue = invocation.positionalArguments[0] as FutureOr<PostgrestMap> Function(PostgrestMap);
        return Future.value(onValue({'id': 'pin-1'}));
      });

      await repository.addMoodPin(
        sentiment: 'positive',
        latitude: 51.5278,
        longitude: -0.1345,
      );

      verify(
        () => mockQueryBuilder.insert({
          'sentiment': 'positive',
          'grid_lat': 51.53, // Anonymized
          'grid_lon': -0.13, // Anonymized
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
      when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());
      when(() => mockQueryBuilder.insert(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.single()).thenReturn(mockTransformBuilder);
      when(() => mockTransformBuilder.then(any())).thenAnswer((invocation) {
        final onValue = invocation.positionalArguments[0] as FutureOr<PostgrestMap> Function(PostgrestMap);
        return Future.value(onValue({'id': 'comment-1'}));
      });

      final result = await repository.addComment(
        moodPinId: 'pin-1',
        text: 'Great pin!',
      );

      expect(result, 'comment-1');
    });

    test('inserts correct mood_pin_id and text', () async {
      when(() => mockSupabase.auth).thenReturn(MockGoTrueClient());
      when(() => mockQueryBuilder.insert(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.select(any())).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.single()).thenReturn(mockTransformBuilder);
      when(() => mockTransformBuilder.then(any())).thenAnswer((invocation) {
        final onValue = invocation.positionalArguments[0] as FutureOr<PostgrestMap> Function(PostgrestMap);
        return Future.value(onValue({'id': 'comment-1'}));
      });

      await repository.addComment(moodPinId: 'pin-1', text: 'Great pin!');

      verify(
        () => mockQueryBuilder.insert({
          'mood_pin_id': 'pin-1',
          'text': 'Great pin!',
          'user_id': null,
        }),
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
      when(() => mockQueryBuilder.select()).thenReturn(mockListTransformBuilder);
      when(() => mockListTransformBuilder.then(any()))
          .thenAnswer((invocation) {
            final onValue = invocation.positionalArguments[0] as FutureOr<PostgrestList> Function(PostgrestList);
            return Future.value(onValue([_videoPostJson()]));
          });

      final result = await repository.getVideoFeed();

      expect(result, hasLength(1));
      expect(result.first, isA<VideoPostModel>());
      expect(result.first.id, 'post-1');
    });

    test('returns paginated results using offset and limit', () async {
      when(() => mockQueryBuilder.select()).thenReturn(mockListTransformBuilder);
      when(() => mockListTransformBuilder.then(any()))
          .thenAnswer((invocation) {
            final onValue = invocation.positionalArguments[0] as FutureOr<PostgrestList> Function(PostgrestList);
            return Future.value(onValue([_videoPostJson(id: 'post-2')]));
          });

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
      final moodPinMap = {
        'id': 'pin-1',
        'sentiment': 'positive',
        'grid_lat': 51.5,
        'grid_lon': -0.1,
        'created_at': _now.toIso8601String(),
        'expires_at': _now.add(const Duration(hours: 24)).toIso8601String(),
      };

      when(
        () => mockSupabase.from('mood_pins'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.stream(primaryKey: ['id']),
      ).thenReturn(mockStreamBuilder);
      when(
        () => mockStreamBuilder.gt(any(), any()),
      ).thenReturn(mockStreamBuilder);
      
      // Instead of mocking map(), we provide the stream that repository calls map() on
      when(() => mockStreamBuilder.listen(
        any(),
        onError: any(named: 'onError'),
        onDone: any(named: 'onDone'),
        cancelOnError: any(named: 'cancelOnError'),
      )).thenAnswer((invocation) {
        final onData = invocation.positionalArguments[0] as void Function(List<Map<String, dynamic>>);
        final stream = Stream.value([moodPinMap]);
        return stream.listen(onData);
      });

      // Alternatively, just mock the stream itself since SupabaseStreamFilterBuilder implements Stream
      when(() => mockStreamBuilder.asyncMap<List<MoodPinModel>>(any())).thenAnswer((_) => Stream.value([]));
      // Wait, repository calls .map() (from Stream)
      // The easiest way is to mock the stream behavior
      when(() => mockStreamBuilder.map<List<MoodPinModel>>(any())).thenAnswer((invocation) {
        final mapper = invocation.positionalArguments[0] as List<MoodPinModel> Function(List<Map<String, dynamic>>);
        return Stream.value(mapper([moodPinMap]));
      });

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
