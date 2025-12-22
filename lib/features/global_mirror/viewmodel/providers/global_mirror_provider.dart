import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/mood_pin_model.dart';
import '../../data/models/video_post_model.dart';
import '../../data/models/mood_pin_comment_model.dart';
import '../../data/repositories/global_mirror_repository.dart';
import 'mood_comment_notification_provider.dart';

/// Provider for Global Mirror repository
final globalMirrorRepositoryProvider = Provider<GlobalMirrorRepository>((ref) {
  return GlobalMirrorRepository();
});

/// Provider for streaming mood pins
final moodPinsStreamProvider = StreamProvider<List<MoodPinModel>>((ref) {
  final repository = ref.watch(globalMirrorRepositoryProvider);
  return repository.streamMoodPins();
});

/// Provider for video feed with pagination
final videoFeedProvider = FutureProvider.family<List<VideoPostModel>, int>((ref, page) async {
  final repository = ref.watch(globalMirrorRepositoryProvider);
  return repository.getVideoFeed(offset: page * 10, limit: 10);
});

/// Provider for current location
final currentLocationProvider = FutureProvider<Position?>((ref) async {
  final repository = ref.watch(globalMirrorRepositoryProvider);
  return repository.getCurrentLocation();
});

/// State notifier for managing Global Mirror state
class GlobalMirrorState {
  final bool isSharing;
  final bool hasLocationPermission;
  final String? error;
  final List<VideoPostModel> videoFeed;
  final int currentVideoPage;
  final bool isLoadingMore;

  GlobalMirrorState({
    this.isSharing = false,
    this.hasLocationPermission = false,
    this.error,
    this.videoFeed = const [],
    this.currentVideoPage = 0,
    this.isLoadingMore = false,
  });

  GlobalMirrorState copyWith({
    bool? isSharing,
    bool? hasLocationPermission,
    String? error,
    List<VideoPostModel>? videoFeed,
    int? currentVideoPage,
    bool? isLoadingMore,
  }) {
    return GlobalMirrorState(
      isSharing: isSharing ?? this.isSharing,
      hasLocationPermission: hasLocationPermission ?? this.hasLocationPermission,
      error: error,
      videoFeed: videoFeed ?? this.videoFeed,
      currentVideoPage: currentVideoPage ?? this.currentVideoPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// State notifier for Global Mirror
class GlobalMirrorNotifier extends StateNotifier<GlobalMirrorState> {
  final GlobalMirrorRepository _repository;

  GlobalMirrorNotifier(this._repository) : super(GlobalMirrorState());

  /// Share mood with anonymized location
  Future<bool> shareMood(String sentiment) async {
    try {
      debugPrint('[GlobalMirrorNotifier] shareMood called with sentiment: $sentiment');
      state = state.copyWith(isSharing: true, error: null);

      // Get current location
      debugPrint('[GlobalMirrorNotifier] Getting current location...');
      final position = await _repository.getCurrentLocation();
      if (position == null) {
        debugPrint('[GlobalMirrorNotifier] Location permission denied or unavailable');
        state = state.copyWith(
          isSharing: false,
          error: 'Location permission required',
          hasLocationPermission: false,
        );
        return false;
      }

      debugPrint('[GlobalMirrorNotifier] Location obtained: ${position.latitude}, ${position.longitude}');

      // Add mood pin
      debugPrint('[GlobalMirrorNotifier] Adding mood pin to repository...');
      final pinId = await _repository.addMoodPin(
        sentiment: sentiment,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      debugPrint('[GlobalMirrorNotifier] Mood pin added: $pinId');

      state = state.copyWith(
        isSharing: false,
        hasLocationPermission: true,
        error: (pinId != null && pinId.isNotEmpty) ? null : 'Failed to share mood',
      );

      return pinId != null && pinId.isNotEmpty;
    } catch (e, stackTrace) {
      debugPrint('[GlobalMirrorNotifier] Error sharing mood: $e');
      debugPrint('[GlobalMirrorNotifier] Stack trace: $stackTrace');
      state = state.copyWith(
        isSharing: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Upload video
  Future<bool> uploadVideo({
    required String videoPath,
    required String moodTag,
  }) async {
    try {
      state = state.copyWith(isSharing: true, error: null);

      debugPrint('[GlobalMirrorProvider] Starting video upload: $videoPath');
      
      final videoUrl = await _repository.uploadVideo(
        videoPath: videoPath,
        moodTag: moodTag,
      );

      if (videoUrl != null && videoUrl.isNotEmpty) {
        debugPrint('[GlobalMirrorProvider] Video upload successful: $videoUrl');
        state = state.copyWith(
          isSharing: false,
          error: null,
        );

        // Refresh video feed if successful
        await loadVideoFeed(refresh: true);
        return true;
      } else {
        debugPrint('[GlobalMirrorProvider] Video upload failed: returned null or empty URL');
        state = state.copyWith(
          isSharing: false,
          error: 'Failed to upload video. Please check your connection and try again.',
        );
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('[GlobalMirrorProvider] Video upload error: $e');
      debugPrint('[GlobalMirrorProvider] Stack trace: $stackTrace');
      state = state.copyWith(
        isSharing: false,
        error: 'Upload error: ${e.toString()}',
      );
      return false;
    }
  }

  /// Load video feed
  Future<void> loadVideoFeed({bool refresh = false}) async {
    try {
      debugPrint('[GlobalMirrorProvider] Loading video feed (refresh: $refresh)');
      
      if (refresh) {
        state = state.copyWith(currentVideoPage: 0, videoFeed: [], error: null);
      }

      final videos = await _repository.getVideoFeed(
        offset: refresh ? 0 : state.currentVideoPage * 10,
        limit: 10,
      );

      debugPrint('[GlobalMirrorProvider] Loaded ${videos.length} videos');

      state = state.copyWith(
        videoFeed: refresh ? videos : [...state.videoFeed, ...videos],
        currentVideoPage: refresh ? 1 : state.currentVideoPage + 1,
      );
    } catch (e, stackTrace) {
      debugPrint('[GlobalMirrorProvider] Error loading video feed: $e');
      debugPrint('[GlobalMirrorProvider] Stack trace: $stackTrace');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Load more videos
  Future<void> loadMoreVideos() async {
    if (state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    await loadVideoFeed();
    state = state.copyWith(isLoadingMore: false);
  }

  /// Check location permission
  Future<void> checkLocationPermission() async {
    final position = await _repository.getCurrentLocation();
    state = state.copyWith(hasLocationPermission: position != null);
  }

  /// Add a comment to a mood pin
  /// Serverpod automatically creates notifications for pin owners
  Future<bool> addComment({
    required String moodPinId,
    required String text,
    required WidgetRef ref,
  }) async {
    try {
      final commentId = await _repository.addComment(
        moodPinId: moodPinId,
        text: text,
      );
      
      if (commentId != null && commentId.isNotEmpty) {
        // Refresh notifications since Serverpod created them automatically
        ref.read(moodCommentNotificationProvider.notifier).refreshNotifications();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GlobalMirrorNotifier] Error adding comment: $e');
      return false;
    }
  }

  /// Get comments for a mood pin
  Future<List<MoodPinCommentModel>> getCommentsForPin(String moodPinId) async {
    try {
      return await _repository.getCommentsForPin(moodPinId);
    } catch (e) {
      debugPrint('[GlobalMirrorNotifier] Error getting comments: $e');
      return [];
    }
  }

  /// Generate cluster encouragement message
  Future<String> generateClusterEncouragement(String sentiment, int nearbyCount) async {
    try {
      return await _repository.generateClusterEncouragement(sentiment, nearbyCount);
    } catch (e) {
      debugPrint('[GlobalMirrorNotifier] Error generating cluster encouragement: $e');
      return 'Others nearby are feeling similar—many found short walks or deep breathing helped today.';
    }
  }
}

/// Provider for Global Mirror state notifier
final globalMirrorProvider = StateNotifierProvider<GlobalMirrorNotifier, GlobalMirrorState>((ref) {
  final repository = ref.watch(globalMirrorRepositoryProvider);
  return GlobalMirrorNotifier(repository);
});
