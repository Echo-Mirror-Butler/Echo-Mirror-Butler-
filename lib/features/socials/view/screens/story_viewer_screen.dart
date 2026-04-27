import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/story_model.dart';
import '../../viewmodel/providers/socials_provider.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instagram-style story viewer
class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late PageController _pageController;
  late int _currentStoryIndex;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentStoryIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _markStoryAsViewed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markStoryAsViewed() async {
    if (widget.stories.isEmpty) return;
    final story = widget.stories[_currentStoryIndex];
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated && authState.user != null) {
      final userId = authState.user!.id;
      final repository = ref.read(socialsRepositoryProvider);
      await repository.viewStory(story.id, userId);
    }
  }

  void _nextStory() {
    if (_currentStoryIndex < widget.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _currentImageIndex = 0;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _markStoryAsViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _currentImageIndex = 0;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _markStoryAsViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _nextImage() {
    final story = widget.stories[_currentStoryIndex];
    if (_currentImageIndex < story.imageUrls.length - 1) {
      setState(() {
        _currentImageIndex++;
      });
    } else {
      _nextStory();
    }
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      setState(() {
        _currentImageIndex--;
      });
    } else {
      _previousStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'No stories available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final story = widget.stories[_currentStoryIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _nextImage(),
        child: Stack(
          children: [
            // Story image
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStoryIndex = index;
                  _currentImageIndex = 0;
                });
                _markStoryAsViewed();
              },
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final s = widget.stories[index];
                return _buildStoryContent(s);
              },
            ),

            // Progress indicators
            Positioned(
              top: 40,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  // Story progress bars
                  Row(
                    children: List.generate(
                      story.imageUrls.length,
                      (index) => Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: index <= _currentImageIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // User info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: story.userAvatarUrl != null
                            ? NetworkImage(story.userAvatarUrl!)
                            : null,
                        child: story.userAvatarUrl == null
                            ? Text(
                                story.userName.isNotEmpty
                                    ? story.userName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.userName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_formatTime(story.createdAt)} • ${story.viewCount} views',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Swipe areas
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.25,
              child: GestureDetector(
                onTap: _previousImage,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.25,
              child: GestureDetector(
                onTap: _nextImage,
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(StoryModel story) {
    return PageView.builder(
      itemCount: story.imageUrls.length,
      onPageChanged: (index) {
        setState(() {
          _currentImageIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final imageUrl = story.imageUrls[index];

        // Check if it's a local file path or a URL
        if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
          // It's a URL - use CachedNetworkImage
          return CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) =>
                const Center(child: Icon(Icons.error, color: Colors.white)),
          );
        } else {
          // It's a local file path - use Image.file
          try {
            return Image.file(
              File(imageUrl),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.error, color: Colors.white)),
            );
          } catch (e) {
            return const Center(child: Icon(Icons.error, color: Colors.white));
          }
        }
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
