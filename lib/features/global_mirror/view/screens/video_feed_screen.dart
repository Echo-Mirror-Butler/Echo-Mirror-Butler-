import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../viewmodel/providers/global_mirror_provider.dart';
import '../widgets/video_recorder_sheet.dart';

/// Video feed screen with reels-style vertical scroll
class VideoFeedScreen extends ConsumerStatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hasLoadedInitial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load initial videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedInitial) {
        _loadVideos();
        _hasLoadedInitial = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload videos when app comes back to foreground
      _loadVideos();
    }
  }

  void _loadVideos() {
    final currentVideos = ref.read(globalMirrorProvider).videoFeed;
    // Only reload if we don't have videos or if explicitly refreshing
    if (currentVideos.isEmpty) {
      ref.read(globalMirrorProvider.notifier).loadVideoFeed(refresh: true);
    }
  }


  void _showRecorder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VideoRecorderSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalMirrorProvider);
    final videos = state.videoFeed;

    return Scaffold(
      body: Stack(
        children: [
          // Video feed
          videos.isEmpty
              ? _buildEmptyState()
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: videos.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });

                    // Load more when near end
                    if (index >= videos.length - 2) {
                      ref.read(globalMirrorProvider.notifier).loadMoreVideos();
                    }
                  },
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return VideoReelItem(
                      video: video,
                      isActive: index == _currentPage,
                    );
                  },
                ),

          // Record button
          Positioned(
            bottom: 100,
            right: 16,
            child: FadeInRight(
              child: FloatingActionButton.extended(
                onPressed: _showRecorder,
                backgroundColor: AppTheme.primaryColor,
                icon: const FaIcon(FontAwesomeIcons.video, color: Colors.white),
                label: Text(
                  'Share',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Page indicator
          if (videos.isNotEmpty)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 2 - 50,
              child: Column(
                children: List.generate(
                  videos.length.clamp(0, 5),
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    width: 8,
                    height: index == _currentPage ? 24 : 8,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.video,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Videos Yet',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share a mood video!',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showRecorder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.video),
              label: Text(
                'Record Video',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual video reel item
class VideoReelItem extends StatefulWidget {
  final dynamic video;
  final bool isActive;

  const VideoReelItem({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<VideoReelItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  File? _localVideoFile;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only handle play/pause for videos, not images
    if (!widget.video.isImage) {
      if (widget.isActive && !oldWidget.isActive) {
        _controller?.play();
      } else if (!widget.isActive && oldWidget.isActive) {
        _controller?.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      // Check if this is an image or video
      if (widget.video.isImage) {
        debugPrint('[VideoReelItem] Detected image, skipping video initialization: ${widget.video.videoUrl}');
        if (mounted) {
          setState(() {
            _isInitialized = true; // Mark as initialized so image can be displayed
          });
        }
        return;
      }

      debugPrint('[VideoReelItem] Initializing video: ${widget.video.videoUrl}');
      
      // Download video first to avoid byte range issues with Serverpod Cloud Storage
      final videoUrl = widget.video.videoUrl;
      final response = await http.get(Uri.parse(videoUrl));
      
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/video_${widget.video.id}.mp4';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        _localVideoFile = file;
        _controller = VideoPlayerController.file(file);
        await _controller!.initialize();
        await _controller!.setLooping(true);
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          
          if (widget.isActive) {
            _controller!.play();
          }
        }
        debugPrint('[VideoReelItem] Video initialized successfully from local file');
      } else {
        throw Exception('Failed to download video: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[VideoReelItem] Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Clean up local video file after a delay (in case video is still playing)
    if (_localVideoFile != null && _localVideoFile!.existsSync()) {
      Future.delayed(const Duration(seconds: 5), () {
        try {
          _localVideoFile!.deleteSync();
        } catch (e) {
          debugPrint('[VideoReelItem] Error deleting temp file: $e');
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.video.isImage;
    
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media content (image or video)
          if (isImage)
            // Display image
            _isInitialized
                ? Center(
                    child: Image.network(
                      widget.video.videoUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: ShimmerLoading(
                            width: 40,
                            height: 40,
                            baseColor: Colors.white24,
                            highlightColor: Colors.white70,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('[VideoReelItem] Error loading image: $error');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.triangleExclamation,
                                color: Colors.white70,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading image',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : const Center(
                    child: ShimmerLoading(
                      width: 40,
                      height: 40,
                      baseColor: Colors.white24,
                      highlightColor: Colors.white70,
                    ),
                  )
          else
            // Display video
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ShimmerLoading(
                      width: 40,
                      height: 40,
                      baseColor: Colors.white24,
                      highlightColor: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading video...',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

          // Video info overlay
          Positioned(
            left: 16,
            bottom: 100,
            right: 80,
            child: FadeInUp(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mood tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${widget.video.moodTag}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Time info
                  Text(
                    _getTimeAgo(widget.video.timestamp),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expires in ${_getTimeRemaining(widget.video.expiresAt)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tap to pause/play (only for videos)
          if (!isImage)
            GestureDetector(
              onTap: () {
                if (_controller != null) {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                  setState(() {});
                }
              },
              child: Container(color: Colors.transparent),
            ),

          // Play/pause indicator (only for videos)
          if (!isImage && _controller != null && !_controller!.value.isPlaying && _isInitialized)
            Center(
              child: FadeIn(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.play,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          
          // Image indicator badge
          if (isImage && _isInitialized)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.image,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Image',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _getTimeRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'soon';
  }
}
