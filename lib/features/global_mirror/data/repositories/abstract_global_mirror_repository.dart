import 'package:geolocator/geolocator.dart';
import '../models/mood_pin_model.dart';
import '../models/mood_pin_comment_model.dart';
import '../models/video_post_model.dart';

/// Abstract interface for GlobalMirrorRepository.
/// Allows test doubles to be injected without touching Supabase.
abstract class AbstractGlobalMirrorRepository {
  Stream<List<MoodPinModel>> streamMoodPins();

  Future<String?> addMoodPin({
    required String sentiment,
    required double latitude,
    required double longitude,
  });

  Future<String?> uploadVideo({
    required String videoPath,
    required String moodTag,
  });

  Future<String?> uploadImage({
    required String imagePath,
    required String moodTag,
  });

  Future<List<VideoPostModel>> getVideoFeed({
    int offset = 0,
    int limit = 10,
  });

  Future<Position?> getCurrentLocation();

  Future<String?> addComment({
    required String moodPinId,
    required String text,
  });

  Future<List<MoodPinCommentModel>> getCommentsForPin(String moodPinId);

  Future<String> generateClusterEncouragement(
    String sentiment,
    int nearbyCount,
  );

  void dispose();
}
