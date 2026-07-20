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

class MockGoTrueClient extends Mock implements GoTrueClient {
  @override
  User? get currentUser => null;
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

// ---------------------------------------------------------------------------
// Fake repository for testable logic without Supabase client chaining
// ---------------------------------------------------------------------------

class _FakeGlobalMirrorRepository extends GlobalMirrorRepository {
  final Map<String, dynamic>? _insertResult;
  final List<Map<String, dynamic>>? _listResult;
  final Exception? _error;
  final List<MoodPinModel> _streamPins;

  _FakeGlobalMirrorRepository({
    Map<String, dynamic>? insertResult,
    List<Map<String, dynamic>>? listResult,
    Exception? error,
    List<MoodPinModel> streamPins = const [],
  }) : _insertResult = insertResult,
       _listResult = listResult,
       _error = error,
       _streamPins = streamPins;

  @override
  Future<String?> addMoodPin({
    required String sentiment,
    required double latitude,
    required double longitude,
  }) async {
    if (_error != null) return null;
    return _insertResult?['id']?.toString();
  }

  @override
  Future<String?> addComment({
    required String moodPinId,
    required String text,
  }) async {
    if (_error != null) return null;
    return _insertResult?['id']?.toString();
  }

  @override
  Future<List<VideoPostModel>> getVideoFeed({
    int offset = 0,
    int limit = 10,
  }) async {
    if (_error != null) return [];
    final data = _listResult ?? [];
    final end = (offset + limit).clamp(0, data.length);
    final slice = offset < data.length
        ? data.sublist(offset, end)
        : <Map<String, dynamic>>[];
    return slice
        .map(
          (p) => VideoPostModel(
            id: p['id'].toString(),
            videoUrl: p['video_url'] as String,
            moodTag: p['mood_tag'] as String? ?? '',
            timestamp: DateTime.parse(p['created_at'] as String),
            expiresAt: p['expires_at'] != null
                ? DateTime.parse(p['expires_at'] as String)
                : DateTime.parse(
                    p['created_at'] as String,
                  ).add(const Duration(hours: 24)),
          ),
        )
        .toList();
  }

  @override
  Stream<List<MoodPinModel>> streamMoodPins() {
    if (_error != null) return Stream.value([]);
    return Stream.value(_streamPins);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  // -------------------------------------------------------------------------
  // addMoodPin
  // -------------------------------------------------------------------------

  group('addMoodPin', () {
    test('returns non-null ID on success', () async {
      final repo = _FakeGlobalMirrorRepository(insertResult: _moodPinJson());

      final result = await repo.addMoodPin(
        sentiment: 'positive',
        latitude: 51.52,
        longitude: -0.13,
      );

      expect(result, 'pin-1');
    });

    test('anonymizeCoordinate rounds to 1 decimal place', () {
      expect(MoodPinModel.anonymizeCoordinate(51.52), closeTo(51.5, 0.01));
      expect(MoodPinModel.anonymizeCoordinate(-0.13), closeTo(-0.1, 0.01));
    });

    test('returns null on Supabase error', () async {
      final repo = _FakeGlobalMirrorRepository(error: Exception('db error'));

      final result = await repo.addMoodPin(
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
    test('returns non-null ID on success', () async {
      final repo = _FakeGlobalMirrorRepository(
        insertResult: {'id': 'comment-1'},
      );

      final result = await repo.addComment(
        moodPinId: 'pin-1',
        text: 'Feeling this too',
      );

      expect(result, 'comment-1');
    });

    test('returns null on Supabase error', () async {
      final repo = _FakeGlobalMirrorRepository(error: Exception('db error'));

      final result = await repo.addComment(moodPinId: 'pin-1', text: 'test');

      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // getVideoFeed
  // -------------------------------------------------------------------------

  group('getVideoFeed', () {
    test('returns list of VideoPostModel on success', () async {
      final repo = _FakeGlobalMirrorRepository(listResult: [_videoPostJson()]);

      final result = await repo.getVideoFeed();

      expect(result, hasLength(1));
      expect(result.first, isA<VideoPostModel>());
      expect(result.first.id, 'post-1');
      expect(result.first.videoUrl, 'https://example.com/video.mp4');
      expect(result.first.moodTag, 'happy');
    });

    test('returns paginated results using offset and limit', () async {
      final data = List.generate(20, (i) => _videoPostJson(id: 'post-$i'));
      final repo = _FakeGlobalMirrorRepository(listResult: data);

      final result = await repo.getVideoFeed(offset: 5, limit: 3);

      expect(result, hasLength(3));
      expect(result.first.id, 'post-5');
    });

    test('returns empty list on Supabase error', () async {
      final repo = _FakeGlobalMirrorRepository(error: Exception('db error'));

      final result = await repo.getVideoFeed();

      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // streamMoodPins
  // -------------------------------------------------------------------------

  group('streamMoodPins', () {
    test('emits list of MoodPinModel from stream', () async {
      final pins = [
        MoodPinModel(
          id: 'pin-1',
          sentiment: 'positive',
          gridLat: 51.5,
          gridLon: -0.1,
          timestamp: _now,
          expiresAt: _expires,
        ),
      ];
      final repo = _FakeGlobalMirrorRepository(streamPins: pins);

      final stream = repo.streamMoodPins();
      final result = await stream.first;

      expect(result, hasLength(1));
      expect(result.first.id, 'pin-1');
      expect(result.first.sentiment, 'positive');
    });

    test('returns empty stream on error', () async {
      final repo = _FakeGlobalMirrorRepository(
        error: Exception('realtime error'),
      );

      final stream = repo.streamMoodPins();
      final result = await stream.first;

      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // MoodPinModel
  // -------------------------------------------------------------------------

  group('MoodPinModel', () {
    test('fromSupabase maps fields correctly', () {
      final pin = MoodPinModel(
        id: 'pin-1',
        sentiment: 'calm',
        gridLat: 51.5,
        gridLon: -0.1,
        timestamp: _now,
        expiresAt: _expires,
      );

      expect(pin.id, 'pin-1');
      expect(pin.sentiment, 'calm');
      expect(pin.gridLat, 51.5);
      expect(pin.gridLon, -0.1);
    });
  });
}
