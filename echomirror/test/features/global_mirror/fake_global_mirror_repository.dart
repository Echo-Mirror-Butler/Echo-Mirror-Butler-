import 'package:geolocator/geolocator.dart';
import 'package:echomirror/features/global_mirror/data/models/mood_pin_model.dart';
import 'package:echomirror/features/global_mirror/data/models/mood_pin_comment_model.dart';
import 'package:echomirror/features/global_mirror/data/models/video_post_model.dart';
import 'package:echomirror/features/global_mirror/data/repositories/abstract_global_mirror_repository.dart';

/// Fake implementation of [AbstractGlobalMirrorRepository] for use in tests.
/// All methods return empty/default values and never access Supabase.
class FakeGlobalMirrorRepository implements AbstractGlobalMirrorRepository {
  @override
  Stream<List<MoodPinModel>> streamMoodPins() => Stream.value([]);

  @override
  Future<String?> addMoodPin({
    required String sentiment,
    required double latitude,
    required double longitude,
  }) =>
      Future.value(null);

  @override
  Future<String?> uploadVideo({
    required String videoPath,
    required String moodTag,
  }) =>
      Future.value(null);

  @override
  Future<String?> uploadImage({
    required String imagePath,
    required String moodTag,
  }) =>
      Future.value(null);

  @override
  Future<List<VideoPostModel>> getVideoFeed({
    int offset = 0,
    int limit = 10,
  }) =>
      Future.value([]);

  @override
  Future<Position?> getCurrentLocation() => Future.value(null);

  @override
  Future<String?> addComment({
    required String moodPinId,
    required String text,
  }) =>
      Future.value(null);

  @override
  Future<List<MoodPinCommentModel>> getCommentsForPin(String moodPinId) =>
      Future.value([]);

  @override
  Future<String> generateClusterEncouragement(
    String sentiment,
    int nearbyCount,
  ) =>
      Future.value('');

  @override
  void dispose() {}
}
