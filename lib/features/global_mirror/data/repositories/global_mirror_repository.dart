import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mood_pin_model.dart';
import '../models/video_post_model.dart';
import '../models/mood_pin_comment_model.dart';

/// Repository for Global Mirror feature
/// Handles anonymous mood sharing and video posts
class GlobalMirrorRepository {
  final SupabaseClient? _supabaseClient;

  GlobalMirrorRepository({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient;

  SupabaseClient get supabase => _supabaseClient ?? Supabase.instance.client;

  /// Stream mood pins in real-time
  Stream<List<MoodPinModel>> streamMoodPins() {
    debugPrint(
      '[GlobalMirrorRepository] Connecting to '
      'streamMoodPins using Supabase Realtime...',
    );
    try {
      return supabase
          .from('mood_pins')
          .stream(primaryKey: ['id'])
          .gt('expires_at', DateTime.now().toIso8601String())
          .map((events) {
            return events.map((p) {
              return MoodPinModel(
                id: p['id'].toString(),
                sentiment: p['sentiment'] as String,
                gridLat: (p['grid_lat'] as num).toDouble(),
                gridLon: (p['grid_lon'] as num).toDouble(),
                timestamp: DateTime.parse(p['created_at'] as String),
                expiresAt: p['expires_at'] != null
                    ? DateTime.parse(p['expires_at'] as String)
                    : null,
              );
            }).toList();
          });
    } catch (e, stackTrace) {
      debugPrint('[GlobalMirrorRepository] Fatal error in streamMoodPins: $e');
      debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
      return Stream.value([]);
    }
  }

  /// Add a mood pin with anonymized location
  Future<String?> addMoodPin({
    required String sentiment,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final gridLat = MoodPinModel.anonymizeCoordinate(latitude);
      final gridLon = MoodPinModel.anonymizeCoordinate(longitude);

      debugPrint(
        '[GlobalMirrorRepository] Adding mood pin: '
        '$sentiment at ($gridLat, $gridLon)',
      );

      final response = await supabase
          .from('mood_pins')
          .insert({
            'sentiment': sentiment,
            'grid_lat': gridLat,
            'grid_lon': gridLon,
          })
          .select('id')
          .single();

      final pinId = response['id'].toString();
      debugPrint('[GlobalMirrorRepository] Added mood pin - Pin ID: $pinId');
      return pinId;
    } catch (e, stackTrace) {
      debugPrint('[GlobalMirrorRepository] Error adding mood pin: $e');
      debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload video and create post
  Future<String?> uploadVideo({
    required String videoPath,
    required String moodTag,
  }) async {
    try {
      debugPrint(
        '[GlobalMirrorRepository] Starting video upload: '
        'path=$videoPath, moodTag=$moodTag',
      );

      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('[GlobalMirrorRepository] ERROR: Video file does not exist');
        return null;
      }

      final bytes = await file.readAsBytes();
      final ext = videoPath.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '${supabase.auth.currentUser?.id ?? "anon"}/$fileName';

      debugPrint(
        '[GlobalMirrorRepository] Uploading video to Supabase Storage...',
      );
      await supabase.storage.from('videos').uploadBinary(path, bytes);

      final videoUrl = supabase.storage.from('videos').getPublicUrl(path);

      debugPrint(
        '[GlobalMirrorRepository] Inserting video post to database...',
      );
      await supabase.from('video_posts').insert({
        'video_url': videoUrl,
        'mood_tag': moodTag,
      });

      return videoUrl;
    } catch (e, stackTrace) {
      debugPrint('[GlobalMirrorRepository] Error uploading video: $e');
      debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload image and create post
  Future<String?> uploadImage({
    required String imagePath,
    required String moodTag,
  }) async {
    try {
      debugPrint(
        '[GlobalMirrorRepository] Starting image upload: '
        'path=$imagePath, moodTag=$moodTag',
      );

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('[GlobalMirrorRepository] ERROR: Image file does not exist');
        return null;
      }

      final bytes = await file.readAsBytes();
      final ext = imagePath.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '${supabase.auth.currentUser?.id ?? "anon"}/$fileName';

      debugPrint(
        '[GlobalMirrorRepository] Uploading image to Supabase Storage...',
      );
      await supabase.storage.from('images').uploadBinary(path, bytes);

      final imageUrl = supabase.storage.from('images').getPublicUrl(path);

      debugPrint(
        '[GlobalMirrorRepository] Inserting image post '
        'as video_posts record...',
      );
      await supabase.from('video_posts').insert({
        'video_url': imageUrl,
        'mood_tag': moodTag,
      });

      return imageUrl;
    } catch (e, stackTrace) {
      debugPrint('[GlobalMirrorRepository] Error uploading image: $e');
      debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get video feed (paginated)
  Future<List<VideoPostModel>> getVideoFeed({
    int offset = 0,
    int limit = 10,
  }) async {
    try {
      final response = await supabase
          .from('video_posts')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((p) {
        return VideoPostModel(
          id: p['id'].toString(),
          videoUrl: p['video_url'] as String,
          moodTag: p['mood_tag'] as String? ?? '',
          timestamp: DateTime.parse(p['created_at'] as String),
          expiresAt: p['expires_at'] != null
              ? DateTime.parse(p['expires_at'] as String)
              : DateTime.parse(
                  p['created_at'] as String,
                ).add(const Duration(hours: 24)),
        );
      }).toList();
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error getting video feed: $e');
      return [];
    }
  }

  /// Get current location with permission handling
  Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error getting location: $e');
      return null;
    }
  }

  /// Add a comment to a mood pin
  Future<String?> addComment({
    required String moodPinId,
    required String text,
  }) async {
    try {
      final response = await supabase
          .from('mood_pin_comments')
          .insert({
            'mood_pin_id': moodPinId,
            'text': text,
            'user_id': supabase.auth.currentUser?.id,
          })
          .select('id')
          .single();

      return response['id'].toString();
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error adding comment: $e');
      return null;
    }
  }

  /// Get comments for a mood pin
  Future<List<MoodPinCommentModel>> getCommentsForPin(String moodPinId) async {
    try {
      final response = await supabase
          .from('mood_pin_comments')
          .select()
          .eq('mood_pin_id', moodPinId)
          .order('created_at');

      return (response as List).map((c) {
        return MoodPinCommentModel(
          id: c['id'].toString(),
          moodPinId: c['mood_pin_id'].toString(),
          text: c['text'] as String,
          timestamp: DateTime.parse(c['created_at'] as String),
          userId: c['user_id']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error getting comments: $e');
      return [];
    }
  }

  /// Generate cluster encouragement message for mood clusters
  Future<String> generateClusterEncouragement(
    String sentiment,
    int nearbyCount,
  ) async {
    try {
      final response = await supabase.functions.invoke(
        'generate-encouragement',
        body: {'sentiment': sentiment, 'nearbyCount': nearbyCount},
      );

      final data = response.data;
      if (data != null && data is Map && data.containsKey('message')) {
        return data['message'] as String;
      }
      return 'Others nearby are feeling similar.';
    } catch (e) {
      debugPrint(
        '[GlobalMirrorRepository] Error generating cluster encouragement: $e',
      );
      return 'Others nearby are feeling similar—many found short '
          'walks or deep breathing helped today.';
    }
  }
}
