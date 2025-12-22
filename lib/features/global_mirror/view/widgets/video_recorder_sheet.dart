import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/global_mirror_provider.dart';

/// Video recorder bottom sheet
class VideoRecorderSheet extends ConsumerStatefulWidget {
  const VideoRecorderSheet({super.key});

  @override
  ConsumerState<VideoRecorderSheet> createState() => _VideoRecorderSheetState();
}

class _VideoRecorderSheetState extends ConsumerState<VideoRecorderSheet> {
  final ImagePicker _picker = ImagePicker();
  String _selectedMoodTag = 'reflective';
  bool _isUploading = false;
  XFile? _selectedVideo;
  VideoPlayerController? _previewController;
  final TextEditingController _customTagController = TextEditingController();
  bool _isUsingCustomTag = false;

  final List<String> _moodTags = [
    'happy',
    'sad',
    'motivated',
    'reflective',
    'grateful',
  ];

  @override
  void dispose() {
    _previewController?.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _recordVideo() async {
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );

      if (video != null) {
        await _loadVideoPreview(video);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording video: $e')),
        );
      }
    }
  }

  Future<void> _loadVideoPreview(XFile video) async {
    // Dispose previous controller if any
    await _previewController?.dispose();
    
    setState(() {
      _selectedVideo = video;
      _previewController = null;
    });

    // Initialize video player for preview
    try {
      final controller = VideoPlayerController.file(File(video.path));
      await controller.initialize();
      
      if (mounted) {
        setState(() {
          _previewController = controller;
        });
      }
    } catch (e) {
      debugPrint('Error loading video preview: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      if (video != null) {
        await _loadVideoPreview(video);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedVideo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No video selected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check if file exists
    final file = File(_selectedVideo!.path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video file not found. Please select again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    // Get the mood tag (custom or selected)
    final moodTag = _isUsingCustomTag && _customTagController.text.trim().isNotEmpty
        ? _customTagController.text.trim().toLowerCase()
        : _selectedMoodTag;

    try {
      final success = await ref.read(globalMirrorProvider.notifier).uploadVideo(
            videoPath: _selectedVideo!.path,
            moodTag: moodTag,
          );

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video shared successfully! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        } else {
          // Get error message from state if available
          final error = ref.read(globalMirrorProvider).error;
          String errorMessage = error ?? 'Failed to upload video.';
          
          // Provide helpful message for file size errors
          if (errorMessage.contains('524288') || 
              errorMessage.contains('Request size exceeds') ||
              errorMessage.contains('512KB') ||
              errorMessage.contains('400KB') ||
              errorMessage.contains('470KB') ||
              errorMessage.contains('450KB')) {
            errorMessage = 'Video is too large (max 400KB for upload). Please record a shorter video (8-10 seconds) or use a smaller file.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.video,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Share Mood Video',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _selectedVideo == null
                ? _buildRecordOptions()
                : _buildVideoPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Privacy notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.shieldHalved,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Videos are anonymous and expire in 24 hours',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Record button
          _buildActionCard(
            icon: FontAwesomeIcons.video,
            title: 'Record New Video',
            description: 'Record up to 10 seconds (400KB max)',
            color: AppTheme.primaryColor,
            onTap: _recordVideo,
          ),
          const SizedBox(height: 16),

          // Pick from gallery
          _buildActionCard(
            icon: FontAwesomeIcons.images,
            title: 'Choose from Gallery',
            description: 'Select video up to 400KB (8-10 seconds)',
            color: AppTheme.secondaryColor,
            onTap: _pickVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video preview
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _previewController != null && _previewController!.value.isInitialized
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _previewController!.value.aspectRatio,
                          child: VideoPlayer(_previewController!),
                        ),
                      ),
                      // Play button overlay
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            if (_previewController!.value.isPlaying) {
                              _previewController!.pause();
                            } else {
                              _previewController!.play();
                            }
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: FaIcon(
                              _previewController!.value.isPlaying
                                  ? FontAwesomeIcons.pause
                                  : FontAwesomeIcons.play,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
          const SizedBox(height: 24),

          // Mood tag selector
          Text(
            'Mood Tag',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Custom tag option
          if (_isUsingCustomTag)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _customTagController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type your mood tag...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: FaIcon(
                      FontAwesomeIcons.hashtag,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                    color: Colors.grey[600],
                    onPressed: () {
                      setState(() {
                        _isUsingCustomTag = false;
                        _customTagController.clear();
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textCapitalization: TextCapitalization.none,
                onChanged: (value) {
                  setState(() {});
                },
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isUsingCustomTag = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.hashtag,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Or type your own tag...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const Spacer(),
                          FaIcon(
                            FontAwesomeIcons.pencil,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          if (!_isUsingCustomTag) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _moodTags.map((tag) {
                final isSelected = tag == _selectedMoodTag;
                return ChoiceChip(
                  label: Text(
                    '#$tag',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedMoodTag = tag;
                        _isUsingCustomTag = false;
                        _customTagController.clear();
                      });
                    }
                  },
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.grey[200],
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 32),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _previewController?.dispose();
                    setState(() {
                      _selectedVideo = null;
                      _previewController = null;
                      _isUsingCustomTag = false;
                      _customTagController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Share Video',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
