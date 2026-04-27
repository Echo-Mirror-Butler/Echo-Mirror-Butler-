import 'package:echomirror/features/global_mirror/data/models/mood_pin_model.dart';
import 'package:echomirror/features/global_mirror/data/models/video_post_model.dart';
import 'package:echomirror/features/global_mirror/data/models/mood_pin_comment_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/global_mirror_repository.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/global_mirror_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

final _now = DateTime.utc(2026, 4, 1, 12, 0);

VideoPostModel _makeVideoPost({String id = 'video-1'}) => VideoPostModel(
  id: id,
  videoUrl: 'https://example.com/video.mp4',
  moodTag: 'happy',
  timestamp: _now,
  expiresAt: _now.add(const Duration(hours: 24)),
);

MoodPinCommentModel _makeComment({String id = 'comment-1'}) => MoodPinCommentModel(
  id: id,
  moodPinId: 'pin-1',
  text: 'Test comment',
  timestamp: _now,
  userId: 'user-1',
);

class _FakeGlobalMirrorRepository extends GlobalMirrorRepository {
  _FakeGlobalMirrorRepository({
    this.locationPosition,
    this.failLocation = false,
    this.addMoodPinResult,
    this.failAddMoodPin = false,
    this.uploadVideoResult,
    this.failUploadVideo = false,
    this.uploadImageResult,
    this.failUploadImage = false,
    this.videoFeed = const [],
    this.failVideoFeed = false,
    this.addCommentResult,
    this.failAddComment = false,
    this.commentsForPin = const [],
    this.failGetComments = false,
  });

  final Position? locationPosition;
  final bool failLocation;
  final String? addMoodPinResult;
  final bool failAddMoodPin;
  final String? uploadVideoResult;
  final bool failUploadVideo;
  final String? uploadImageResult;
  final bool failUploadImage;
  final List<VideoPostModel> videoFeed;
  final bool failVideoFeed;
  final String? addCommentResult;
  final bool failAddComment;
  final List<MoodPinCommentModel> commentsForPin;
  final bool failGetComments;

  @override
  Future<Position?> getCurrentLocation() async {
    if (failLocation) throw Exception('location error');
    return locationPosition;
  }

  @override
  Future<String?> addMoodPin({
    required String sentiment,
    required double latitude,
    required double longitude,
  }) async {
    if (failAddMoodPin) throw Exception('addMoodPin error');
    return addMoodPinResult;
  }

  @override
  Future<String?> uploadVideo({
    required String videoPath,
    required String moodTag,
  }) async {
    if (failUploadVideo) throw Exception('uploadVideo error');
    return uploadVideoResult;
  }

  @override
  Future<String?> uploadImage({
    required String imagePath,
    required String moodTag,
  }) async {
    if (failUploadImage) throw Exception('uploadImage error');
    return uploadImageResult;
  }

  @override
  Future<List<VideoPostModel>> getVideoFeed({
    int offset = 0,
    int limit = 10,
  }) async {
    if (failVideoFeed) throw Exception('videoFeed error');
    return videoFeed;
  }

  @override
  Future<String?> addComment({
    required String moodPinId,
    required String text,
  }) async {
    if (failAddComment) throw Exception('addComment error');
    return addCommentResult;
  }

  @override
  Future<List<MoodPinCommentModel>> getCommentsForPin(String moodPinId) async {
    if (failGetComments) throw Exception('getComments error');
    return commentsForPin;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlobalMirrorNotifier.shareMood', () {
    test('success — returns true and isSharing is false after success', () async {
      final notifier = GlobalMirrorNotifier(
        _FakeGlobalMirrorRepository(
          locationPosition: _FakePosition(),
          addMoodPinResult: 'pin-123',
        ),
      );

      final result = await notifier.shareMood('happy');

      expect(result, isTrue);
      expect(notifier.state.isSharing, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('error — returns false and state has error message', () async {
      final notifier = GlobalMirrorNotifier(
        _FakeGlobalMirrorRepository(failLocation: true),
      );

      final result = await notifier.shareMood('happy');

      expect(result, isFalse);
      expect(notifier.state.isSharing, isFalse);
      expect(notifier.state.error, isNotNull);
    });

    test('location denied — returns false with location error message', () async {
      final notifier = GlobalMirrorNotifier(
        _FakeGlobalMirrorRepository(locationPosition: null),
      );

      final result = await notifier.shareMood('happy');

      expect(result, isFalse);
      expect(notifier.state.hasLocationPermission, isFalse);
      expect(notifier.state.error, contains('Location'));
    });
  });

  group('GlobalMirrorNotifier.loadVideoFeed', () {
    test('success — videoPosts populated in state', () async {
      final videos = [_makeVideoPost(), _makeVideoPost(id: 'video-2')];
      final notifier = GlobalMirrorNotifier(
        _FakeGlobalMirrorRepository(videoFeed: videos),
      );

      await notifier.loadVideoFeed();

      expect(notifier.state.videoFeed, videos);
      expect(notifier.state.isLoadingVideoFeed, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('error — state has videoFeedError set', () async {
      final notifier = GlobalMirrorNotifier(
        _FakeGlobalMirrorRepository(failVideoFeed: true),
      );

      await notifier.loadVideoFeed();

      expect(notifier.state.videoFeed, isEmpty);
      expect(notifier.state.isLoadingVideoFeed, isFalse);
      expect(notifier.state.error, isNotNull);
    });
  });

  group('GlobalMirrorNotifier.addComment', () {
    test('success — returns non-null comment ID', () async {
      final fakeRef = _FakeWidgetRef();
      final notifier = GlobalMirrorNotifier(
        _FakeGlobalMirrorRepository(addCommentResult: 'comment-123'),
      );

      final result = await notifier.addComment(
        moodPinId: 'pin-1',
        text: 'Nice!',
        ref: fakeRef,
      );

      expect(result, isTrue);
    });

    test('error — returns false', () async {
      final fakeRef = _FakeWidgetRef();
      final notifier = GlobalMirrorNotifier(
        _FakeGlobalMirrorRepository(failAddComment: true),
      );

      final result = await notifier.addComment(
        moodPinId: 'pin-1',
        text: 'Nice!',
        ref: fakeRef,
      );

      expect(result, isFalse);
    });
  });
}

class _FakePosition implements Position {
  _FakePosition({
    this.latitude = 37.7749,
    this.longitude = -122.4194,
    this.timestamp,
    this.accuracy = 0.0,
    this.altitude = 0.0,
    this.altitudeAccuracy = 0.0,
    this.heading = 0.0,
    this.headingAccuracy = 0.0,
    this.speed = 0.0,
    this.speedAccuracy = 0.0,
    this.floor = 0,
    this.isMocked = false,
    this.extras = const {},
  });

  @override
  final double latitude;

  @override
  final double longitude;

  @override
  final DateTime? timestamp;

  @override
  final double accuracy;

  @override
  final double altitude;

  @override
  final double altitudeAccuracy;

  @override
  final double heading;

  @override
  final double headingAccuracy;

  @override
  final double speed;

  @override
  final double speedAccuracy;

  @override
  final int? floor;

  @override
  final bool isMocked;

  @override
  final Map<String, dynamic> extras;

  @override
  double get speedAccuracyMetersPerSecond => 0.0;

  @override
  String toString() => '_FakePosition($latitude, $longitude)';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWidgetRef implements WidgetRef {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}