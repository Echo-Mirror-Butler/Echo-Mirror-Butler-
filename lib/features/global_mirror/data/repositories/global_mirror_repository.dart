import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:echomirror_server_client/echomirror_server_client.dart';
import '../../../../core/services/serverpod_client_service.dart';
import '../models/mood_pin_model.dart';
import '../models/video_post_model.dart';
import '../models/mood_pin_comment_model.dart';

/// Repository for Global Mirror feature
/// Handles anonymous mood sharing and video posts
class GlobalMirrorRepository {
  // Use real Serverpod backend
  // DISABLED - app uses real-time data only
  final bool _useMockData = false;

  GlobalMirrorRepository() {
    // Use shared client with persistent authentication
  }

  Client get _client => ServerpodClientService.instance.client;
  final List<MoodPinModel> _mockPins = [];
  final List<VideoPostModel> _mockVideos = [];
  final List<MoodPinCommentModel> _mockComments = [];
  Timer? _mockTimer;

  /// Stream mood pins in real-time
  Stream<List<MoodPinModel>> streamMoodPins() async* {
    if (_useMockData) {
      // Initialize mock data
      _initializeMockData();

      // Stream updates every 5 seconds
      while (true) {
        yield List.from(_mockPins);
        await Future.delayed(const Duration(seconds: 5));

        // Occasionally add new mock pins
        if (_mockPins.length < 50 && DateTime.now().second % 10 == 0) {
          _addRandomMockPin();
        }
      }
    } else {
      // Connect to Serverpod streaming endpoint
      debugPrint('[GlobalMirrorRepository] Connecting to streamMoodPins...');
      try {
        int attemptCount = 0;
        while (true) {
          try {
            await for (final pins in _client.global.streamMoodPins()) {
              attemptCount++;
              final mappedPins = pins.map((p) {
                return MoodPinModel(
                  id: p.id.toString(),
                  sentiment: p.sentiment,
                  gridLat: p.gridLat,
                  gridLon: p.gridLon,
                  timestamp: p.timestamp,
                  expiresAt: p.expiresAt,
                );
              }).toList();

              debugPrint(
                '[GlobalMirrorRepository] Received ${mappedPins.length} mood pins (attempt $attemptCount)',
              );
              yield mappedPins;
            }
          } catch (e, stackTrace) {
            debugPrint('[GlobalMirrorRepository] Stream error: $e');
            debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');

            // Yield empty list but keep trying
            yield [];

            // Wait before retrying
            await Future.delayed(const Duration(seconds: 5));
            debugPrint(
              '[GlobalMirrorRepository] Retrying stream connection...',
            );
          }
        }
      } catch (e, stackTrace) {
        debugPrint(
          '[GlobalMirrorRepository] Fatal error in streamMoodPins: $e',
        );
        debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
        // Fallback to empty list on error
        yield [];
      }
    }
  }

  /// Add a mood pin with anonymized location
  /// Returns the pin ID if successful, null otherwise
  Future<String?> addMoodPin({
    required String sentiment,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Anonymize coordinates
      final gridLat = MoodPinModel.anonymizeCoordinate(latitude);
      final gridLon = MoodPinModel.anonymizeCoordinate(longitude);

      if (_useMockData) {
        final pinId = DateTime.now().millisecondsSinceEpoch.toString();
        final pin = MoodPinModel(
          id: pinId,
          sentiment: sentiment,
          gridLat: gridLat,
          gridLon: gridLon,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        _mockPins.add(pin);
        debugPrint(
          '[GlobalMirrorRepository] Mock pin added: $sentiment at ($gridLat, $gridLon)',
        );
        return pinId;
      } else {
        // Call Serverpod endpoint (returns pin ID)
        try {
          debugPrint(
            '[GlobalMirrorRepository] Adding mood pin: $sentiment at ($latitude, $longitude) -> ($gridLat, $gridLon)',
          );
          final pinIdInt = await _client.global.addMoodPin(
            sentiment,
            latitude,
            longitude,
          );
          final pinId = pinIdInt?.toString();
          debugPrint(
            '[GlobalMirrorRepository] Added mood pin: $sentiment at ($gridLat, $gridLon) - Pin ID: $pinId',
          );
          if (pinId != null) {
            debugPrint(
              '[GlobalMirrorRepository] Mood pin successfully added to database. It should appear in the stream within 5 seconds.',
            );
          } else {
            debugPrint(
              '[GlobalMirrorRepository] WARNING: addMoodPin returned null - pin may not have been saved',
            );
          }
          return pinId;
        } catch (e, stackTrace) {
          debugPrint(
            '[GlobalMirrorRepository] Error adding mood pin to server: $e',
          );
          debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
          return null;
        }
      }
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error adding mood pin: $e');
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
        '[GlobalMirrorRepository] Starting video upload: path=$videoPath, moodTag=$moodTag',
      );

      // Check if file exists
      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint(
          '[GlobalMirrorRepository] ERROR: Video file does not exist at path: $videoPath',
        );
        return null;
      }

      // Check file size
      final fileSize = await file.length();
      debugPrint(
        '[GlobalMirrorRepository] Video file size: ${fileSize / (1024 * 1024)} MB',
      );

      if (_useMockData) {
        // Simulate upload delay
        debugPrint(
          '[GlobalMirrorRepository] Using mock data - simulating upload...',
        );
        await Future.delayed(const Duration(seconds: 2));

        final post = VideoPostModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          videoUrl: 'mock://video/${DateTime.now().millisecondsSinceEpoch}.mp4',
          moodTag: moodTag,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        _mockVideos.insert(0, post);
        debugPrint(
          '[GlobalMirrorRepository] Mock video uploaded successfully: $moodTag',
        );
        return post.videoUrl;
      } else {
        // Upload to Serverpod
        try {
          // Check file size - Serverpod endpoints have a 512KB limit by default
          // Serialization overhead is significant (~20-25%), so use 400KB as safe limit
          const maxDirectUploadSize =
              400 * 1024; // 400KB to account for request serialization overhead

          if (fileSize > maxDirectUploadSize) {
            debugPrint(
              '[GlobalMirrorRepository] ERROR: Video file (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB / ${(fileSize / 1024).toStringAsFixed(0)} KB) exceeds safe upload limit of 400KB',
            );
            debugPrint(
              '[GlobalMirrorRepository] Serverpod endpoint limit is 512KB, but request serialization adds significant overhead (~20-25%)',
            );
            debugPrint(
              '[GlobalMirrorRepository] Please use a video smaller than 400KB (typically 8-10 seconds), enable mock data mode for testing, or implement FileUploader on server for larger files',
            );
            return null;
          }

          debugPrint('[GlobalMirrorRepository] Reading video file bytes...');
          final bytes = await file.readAsBytes();
          debugPrint(
            '[GlobalMirrorRepository] Read ${bytes.length} bytes from video file',
          );

          final byteData = ByteData.view(bytes.buffer);

          debugPrint('[GlobalMirrorRepository] Uploading to Serverpod...');
          final videoUrl = await _client.global.uploadVideo(byteData, moodTag);

          if (videoUrl != null && videoUrl.isNotEmpty) {
            debugPrint(
              '[GlobalMirrorRepository] Video uploaded successfully: $moodTag - URL: $videoUrl',
            );
          } else {
            debugPrint(
              '[GlobalMirrorRepository] WARNING: Upload returned null or empty URL',
            );
          }
          return videoUrl;
        } catch (e, stackTrace) {
          debugPrint(
            '[GlobalMirrorRepository] Error uploading video to server: $e',
          );
          debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');

          // Check if it's a size limit error
          if (e.toString().contains('Request size exceeds') ||
              e.toString().contains('413') ||
              e.toString().contains('524288')) {
            debugPrint(
              '[GlobalMirrorRepository] File too large for direct upload (exceeds 512KB limit)',
            );
            debugPrint(
              '[GlobalMirrorRepository] Consider: 1) Using a smaller video (<500KB), 2) Implementing FileUploader on server, or 3) Using mock data mode',
            );
          }

          return null;
        }
      }
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
        '[GlobalMirrorRepository] Starting image upload: path=$imagePath, moodTag=$moodTag',
      );

      // Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint(
          '[GlobalMirrorRepository] ERROR: Image file does not exist at path: $imagePath',
        );
        return null;
      }

      // Check file size
      final fileSize = await file.length();
      debugPrint(
        '[GlobalMirrorRepository] Image file size: ${fileSize / (1024 * 1024)} MB',
      );

      if (_useMockData) {
        // Simulate upload delay
        debugPrint(
          '[GlobalMirrorRepository] Using mock data - simulating upload...',
        );
        await Future.delayed(const Duration(seconds: 1));

        final post = VideoPostModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          videoUrl: 'mock://image/${DateTime.now().millisecondsSinceEpoch}.jpg',
          moodTag: moodTag,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        _mockVideos.insert(0, post);
        debugPrint(
          '[GlobalMirrorRepository] Mock image uploaded successfully: $moodTag',
        );
        return post.videoUrl;
      } else {
        // Upload to Serverpod
        try {
          // Check file size - Serverpod endpoints have a 512KB limit by default
          // Serialization overhead is significant (~20-25%), so use 400KB as safe limit
          const maxDirectUploadSize =
              400 * 1024; // 400KB to account for request serialization overhead

          if (fileSize > maxDirectUploadSize) {
            debugPrint(
              '[GlobalMirrorRepository] ERROR: Image file (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB / ${(fileSize / 1024).toStringAsFixed(0)} KB) exceeds safe upload limit of 400KB',
            );
            debugPrint(
              '[GlobalMirrorRepository] Please compress the image or use a smaller file',
            );
            return null;
          }

          debugPrint('[GlobalMirrorRepository] Reading image file bytes...');
          final bytes = await file.readAsBytes();
          debugPrint(
            '[GlobalMirrorRepository] Read ${bytes.length} bytes from image file',
          );

          final byteData = ByteData.view(bytes.buffer);

          debugPrint('[GlobalMirrorRepository] Uploading to Serverpod...');
          final imageUrl = await _client.global.uploadImage(byteData, moodTag);

          if (imageUrl != null && imageUrl.isNotEmpty) {
            debugPrint(
              '[GlobalMirrorRepository] Image uploaded successfully: $moodTag - URL: $imageUrl',
            );
          } else {
            debugPrint(
              '[GlobalMirrorRepository] WARNING: Upload returned null or empty URL',
            );
          }
          return imageUrl;
        } catch (e, stackTrace) {
          debugPrint(
            '[GlobalMirrorRepository] Error uploading image to server: $e',
          );
          debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');

          // Check if it's a size limit error
          if (e.toString().contains('Request size exceeds') ||
              e.toString().contains('413') ||
              e.toString().contains('524288')) {
            debugPrint(
              '[GlobalMirrorRepository] File too large for direct upload (exceeds 512KB limit)',
            );
            debugPrint(
              '[GlobalMirrorRepository] Please compress the image or use a smaller file',
            );
            // Return a specific error message for size errors
            throw Exception(
              'Image file exceeds 400KB limit. Please choose a smaller image.',
            );
          }

          // Check if it's a method not found error (server endpoint not deployed)
          if (e.toString().contains('Method not found') ||
              e.toString().contains('statusCode = 400') ||
              e.toString().contains('Bad request')) {
            debugPrint(
              '[GlobalMirrorRepository] uploadImage endpoint not found on server',
            );
            throw Exception(
              'Upload service is temporarily unavailable. Please try again in a moment.',
            );
          }

          return null;
        }
      }
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
      if (_useMockData) {
        if (_mockVideos.isEmpty) {
          _initializeMockVideos();
        }

        final end = (offset + limit).clamp(0, _mockVideos.length);
        return _mockVideos.sublist(offset, end);
      } else {
        // Call Serverpod endpoint
        try {
          final posts = await _client.global.getVideoFeed(offset, limit);
          return posts.map((p) {
            return VideoPostModel(
              id: p.id.toString(),
              videoUrl: p.videoUrl,
              moodTag: p.moodTag,
              timestamp: p.timestamp,
              expiresAt: p.expiresAt,
            );
          }).toList();
        } catch (e) {
          debugPrint(
            '[GlobalMirrorRepository] Error getting video feed from server: $e',
          );
          return [];
        }
      }
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error getting video feed: $e');
      return [];
    }
  }

  /// Get current location with permission handling
  Future<Position?> getCurrentLocation() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GlobalMirrorRepository] Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          '[GlobalMirrorRepository] Location permission denied forever',
        );
        return null;
      }

      // Get location
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:
              LocationAccuracy.low, // Low accuracy is fine for anonymized data
        ),
      );
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error getting location: $e');
      return null;
    }
  }

  /// Initialize mock data for testing
  void _initializeMockData() {
    if (_mockPins.isNotEmpty) return;

    // Add sample pins around the world
    final sentiments = [
      'positive',
      'neutral',
      'negative',
      'excited',
      'calm',
      'anxious',
    ];
    final locations = [
      {'lat': 40.7, 'lon': -74.0}, // New York
      {'lat': 51.5, 'lon': -0.1}, // London
      {'lat': 35.7, 'lon': 139.7}, // Tokyo
      {'lat': -33.9, 'lon': 151.2}, // Sydney
      {'lat': 48.9, 'lon': 2.3}, // Paris
      {'lat': 37.8, 'lon': -122.4}, // San Francisco
      {'lat': 19.4, 'lon': -99.1}, // Mexico City
      {'lat': -23.6, 'lon': -46.7}, // São Paulo
      {'lat': 55.8, 'lon': 37.6}, // Moscow
      {'lat': 28.6, 'lon': 77.2}, // Delhi
    ];

    for (var i = 0; i < 20; i++) {
      final loc = locations[i % locations.length];
      _mockPins.add(
        MoodPinModel(
          id: 'mock_$i',
          sentiment: sentiments[i % sentiments.length],
          gridLat: loc['lat']! + (i * 0.1),
          gridLon: loc['lon']! + (i * 0.1),
          timestamp: DateTime.now().subtract(Duration(minutes: i * 5)),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        ),
      );
    }
  }

  void _addRandomMockPin() {
    final sentiments = [
      'positive',
      'neutral',
      'negative',
      'excited',
      'calm',
      'anxious',
    ];
    final lat = (DateTime.now().millisecond % 180 - 90).toDouble();
    final lon = (DateTime.now().millisecond % 360 - 180).toDouble();

    _mockPins.add(
      MoodPinModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sentiment: sentiments[DateTime.now().second % sentiments.length],
        gridLat: MoodPinModel.anonymizeCoordinate(lat),
        gridLon: MoodPinModel.anonymizeCoordinate(lon),
        timestamp: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
    );

    // Keep max 50 pins
    if (_mockPins.length > 50) {
      _mockPins.removeAt(0);
    }
  }

  void _initializeMockVideos() {
    final moodTags = ['happy', 'sad', 'motivated', 'reflective', 'grateful'];
    for (var i = 0; i < 15; i++) {
      _mockVideos.add(
        VideoPostModel(
          id: 'mock_video_$i',
          videoUrl:
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          moodTag: moodTags[i % moodTags.length],
          timestamp: DateTime.now().subtract(Duration(hours: i)),
          expiresAt: DateTime.now().add(Duration(hours: 24 - i)),
        ),
      );
    }
  }

  /// Add a comment to a mood pin
  /// Returns comment ID (Serverpod handles notifications automatically)
  Future<String?> addComment({
    required String moodPinId,
    required String text,
  }) async {
    try {
      final pinIdInt = int.tryParse(moodPinId);
      if (pinIdInt == null) {
        debugPrint('[GlobalMirrorRepository] Invalid mood pin ID: $moodPinId');
        return null;
      }

      if (_useMockData) {
        final commentId = DateTime.now().millisecondsSinceEpoch.toString();
        final comment = MoodPinCommentModel(
          id: commentId,
          moodPinId: moodPinId,
          text: text,
          timestamp: DateTime.now(),
        );
        _mockComments.add(comment);
        return commentId;
      } else {
        // Call Serverpod endpoint
        try {
          debugPrint(
            '[GlobalMirrorRepository] Adding comment to mood pin: $moodPinId',
          );
          final commentIdInt = await _client.global.addComment(pinIdInt, text);
          final commentId = commentIdInt?.toString();
          debugPrint('[GlobalMirrorRepository] Comment added: $commentId');
          return commentId;
        } catch (e, stackTrace) {
          debugPrint(
            '[GlobalMirrorRepository] Error adding comment to server: $e',
          );
          debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
          return null;
        }
      }
    } catch (e) {
      debugPrint('[GlobalMirrorRepository] Error adding comment: $e');
      return null;
    }
  }

  /// Get comments for a mood pin
  Future<List<MoodPinCommentModel>> getCommentsForPin(String moodPinId) async {
    try {
      final pinIdInt = int.tryParse(moodPinId);
      if (pinIdInt == null) {
        debugPrint('[GlobalMirrorRepository] Invalid mood pin ID: $moodPinId');
        return [];
      }

      if (_useMockData) {
        return _mockComments.where((c) => c.moodPinId == moodPinId).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        // Call Serverpod endpoint
        try {
          final comments = await _client.global.getCommentsForPin(pinIdInt);
          return comments.map((c) {
            return MoodPinCommentModel(
              id: c.id?.toString() ?? '',
              moodPinId: c.moodPinId.toString(),
              text: c.text,
              timestamp: c.timestamp,
              userId: c.userId?.toString(),
            );
          }).toList();
        } catch (e, stackTrace) {
          debugPrint(
            '[GlobalMirrorRepository] Error getting comments from server: $e',
          );
          debugPrint('[GlobalMirrorRepository] Stack trace: $stackTrace');
          return [];
        }
      }
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
    if (_useMockData) {
      return 'Others nearby are feeling similar—many found short walks or deep breathing helped today.';
    }

    try {
      final message = await _client.global.generateClusterEncouragement(
        sentiment,
        nearbyCount,
      );
      return message;
    } catch (e) {
      debugPrint(
        '[GlobalMirrorRepository] Error generating cluster encouragement: $e',
      );
      return 'Others nearby are feeling similar—many found short walks or deep breathing helped today.';
    }
  }

  void dispose() {
    _mockTimer?.cancel();
  }
}
