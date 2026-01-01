import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
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
  bool _isPickingMedia = false; // Track if media picker is open
  XFile? _selectedVideo;
  XFile? _selectedImage;
  bool _isImage = false; // Track if selected media is image or video
  VideoPlayerController? _previewController;
  final TextEditingController _customTagController = TextEditingController();
  bool _isUsingCustomTag = false;
  String? _fileSizeError; // Store file size error message

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
    debugPrint('[VideoRecorderSheet] Loading video preview: ${video.path}');
    // Dispose previous controller if any
    await _previewController?.dispose();
    
    if (mounted) {
    setState(() {
      _selectedVideo = video;
        _selectedImage = null; // Clear any selected image
        _isImage = false; // Mark as video
      _previewController = null;
    });
      debugPrint('[VideoRecorderSheet] State updated: _isImage=$_isImage, _selectedVideo=${_selectedVideo?.path}');
    }

    // Initialize video player for preview
    try {
      final controller = VideoPlayerController.file(File(video.path));
      await controller.initialize();
      
      if (mounted) {
        setState(() {
          _previewController = controller;
        });
        debugPrint('[VideoRecorderSheet] Video preview initialized successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('[VideoRecorderSheet] Error loading video preview: $e');
      debugPrint('[VideoRecorderSheet] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video preview: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      debugPrint('[VideoRecorderSheet] Picking video from gallery...');
      setState(() {
        _isPickingMedia = true;
        _fileSizeError = null;
      });

      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      debugPrint('[VideoRecorderSheet] Video picker returned: ${video?.path}');

      if (video != null) {
        debugPrint('[VideoRecorderSheet] Video selected: ${video.path}');
        
        // Check file size before loading preview
        final file = File(video.path);
        final fileSize = await file.length();
        const maxSize = 400 * 1024; // 400KB
        
        if (fileSize > maxSize) {
          final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
          final sizeKB = (fileSize / 1024).toStringAsFixed(0);
          if (mounted) {
            setState(() {
              _isPickingMedia = false;
              _fileSizeError = 'Video is too large ($sizeMB MB / $sizeKB KB). Maximum size is 400KB. Please choose a shorter video (8-10 seconds).';
            });
            _showFileSizeError();
          }
          return;
        }
        
        await _loadVideoPreview(video);
        if (mounted) {
          setState(() {
            _isPickingMedia = false;
            _fileSizeError = null;
          });
      }
      } else {
        debugPrint('[VideoRecorderSheet] No video selected (user cancelled)');
      if (mounted) {
          setState(() {
            _isPickingMedia = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[VideoRecorderSheet] Error picking video: $e');
      debugPrint('[VideoRecorderSheet] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isPickingMedia = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      debugPrint('[VideoRecorderSheet] Picking image from gallery...');
      setState(() {
        _isPickingMedia = true;
        _fileSizeError = null;
      });

      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Lower quality for better compression
      );

      debugPrint('[VideoRecorderSheet] Image picker returned: ${image?.path}');
      
      if (image != null) {
        debugPrint('[VideoRecorderSheet] Image selected: ${image.path}');
        
        // Check file size before setting state
        final file = File(image.path);
        final fileSize = await file.length();
        const maxSize = 400 * 1024; // 400KB
        
        if (fileSize > maxSize) {
          final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
          final sizeKB = (fileSize / 1024).toStringAsFixed(0);
          if (mounted) {
            setState(() {
              _isPickingMedia = false;
              _fileSizeError = 'Image is too large ($sizeMB MB / $sizeKB KB). Maximum size is 400KB. Please choose a smaller image.';
            });
            _showFileSizeError();
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            _selectedImage = image;
            _selectedVideo = null;
            _isImage = true;
            _isPickingMedia = false;
            _fileSizeError = null;
            _previewController?.dispose();
            _previewController = null;
          });
          debugPrint('[VideoRecorderSheet] State updated: _isImage=$_isImage, _selectedImage=${_selectedImage?.path}');
        }
      } else {
        debugPrint('[VideoRecorderSheet] No image selected (user cancelled)');
        if (mounted) {
          setState(() {
            _isPickingMedia = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[VideoRecorderSheet] Error picking image: $e');
      debugPrint('[VideoRecorderSheet] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isPickingMedia = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showFileSizeError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _fileSizeError ?? 'File is too large. Maximum size is 400KB.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      debugPrint('[VideoRecorderSheet] Taking photo with camera...');
      setState(() {
        _isPickingMedia = true;
        _fileSizeError = null;
      });

      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Lower quality for better compression
      );

      debugPrint('[VideoRecorderSheet] Camera returned: ${image?.path}');
      
      if (image != null) {
        debugPrint('[VideoRecorderSheet] Photo taken: ${image.path}');
        
        // Check file size before setting state
        final file = File(image.path);
        final fileSize = await file.length();
        const maxSize = 400 * 1024; // 400KB
        
        if (fileSize > maxSize) {
          final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
          final sizeKB = (fileSize / 1024).toStringAsFixed(0);
          if (mounted) {
            setState(() {
              _isPickingMedia = false;
              _fileSizeError = 'Photo is too large ($sizeMB MB / $sizeKB KB). Maximum size is 400KB. Please take another photo.';
            });
            _showFileSizeError();
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            _selectedImage = image;
            _selectedVideo = null;
            _isImage = true;
            _isPickingMedia = false;
            _fileSizeError = null;
            _previewController?.dispose();
            _previewController = null;
          });
          debugPrint('[VideoRecorderSheet] State updated: _isImage=$_isImage, _selectedImage=${_selectedImage?.path}');
        }
      } else {
        debugPrint('[VideoRecorderSheet] No photo taken (user cancelled)');
        if (mounted) {
          setState(() {
            _isPickingMedia = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[VideoRecorderSheet] Error taking photo: $e');
      debugPrint('[VideoRecorderSheet] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isPickingMedia = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedVideo == null && _selectedImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No media selected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check if file exists
    final filePath = _isImage ? _selectedImage!.path : _selectedVideo!.path;
    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_isImage ? "Image" : "Video"} file not found. Please select again.'),
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
      final success = _isImage
          ? await ref.read(globalMirrorProvider.notifier).uploadImage(
                imagePath: _selectedImage!.path,
                moodTag: moodTag,
              )
          : await ref.read(globalMirrorProvider.notifier).uploadVideo(
            videoPath: _selectedVideo!.path,
            moodTag: moodTag,
          );

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_isImage ? "Image" : "Video"} shared successfully! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        } else {
          // Get error message from state if available
          final error = ref.read(globalMirrorProvider).error;
          String errorMessage = error ?? 'Failed to upload ${_isImage ? "image" : "video"}.';
          
          // Check for specific error types
          bool isFileSizeError = errorMessage.contains('524288') || 
              errorMessage.contains('Request size exceeds') ||
              errorMessage.contains('512KB') ||
              errorMessage.contains('400KB') ||
              errorMessage.contains('exceeds safe upload limit') ||
              errorMessage.contains('too large');
          
          bool isMethodNotFound = errorMessage.contains('Method not found') ||
              errorMessage.contains('statusCode = 400') ||
              errorMessage.contains('Bad request');
          
          if (isFileSizeError) {
            errorMessage = 'File is too large (max 400KB). Please ${_isImage ? "choose a smaller image" : "record a shorter video (8-10 seconds)"}.';
          } else if (isMethodNotFound) {
            errorMessage = 'Upload service is temporarily unavailable. Please try again in a moment.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  FaIcon(
                    isFileSizeError 
                        ? FontAwesomeIcons.fileCircleExclamation
                        : FontAwesomeIcons.triangleExclamation,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: isFileSizeError ? Colors.orange : Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                  'Share Mood Media',
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
            child: _isPickingMedia
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShimmerLoading(
                          width: 50,
                          height: 50,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading media...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : (_selectedVideo == null && _selectedImage == null)
                    ? _buildRecordOptions()
                    : _buildMediaPreview(),
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
                    'Media is anonymous and expires in 24 hours',
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

          // Record video button
          _buildActionCard(
            icon: FontAwesomeIcons.video,
            title: 'Record New Video',
            description: 'Record up to 10 seconds (400KB max)',
            color: AppTheme.primaryColor,
            onTap: _recordVideo,
          ),
          const SizedBox(height: 16),

          // Pick video from gallery
          _buildActionCard(
            icon: FontAwesomeIcons.film,
            title: 'Choose Video from Gallery',
            description: 'Select video up to 400KB (8-10 seconds)',
            color: AppTheme.secondaryColor,
            onTap: _pickVideo,
          ),
          const SizedBox(height: 16),

          // Take photo button
          _buildActionCard(
            icon: FontAwesomeIcons.camera,
            title: 'Take Photo',
            description: 'Capture a photo (400KB max)',
            color: AppTheme.accentColor,
            onTap: _takePhoto,
          ),
          const SizedBox(height: 16),

          // Pick image from gallery
          _buildActionCard(
            icon: FontAwesomeIcons.image,
            title: 'Choose Image from Gallery',
            description: 'Select image up to 400KB',
            color: Colors.purple,
            onTap: _pickImage,
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

  Widget _buildMediaPreview() {
    debugPrint('[VideoRecorderSheet] Building media preview: _isImage=$_isImage, _selectedImage=${_selectedImage?.path}, _selectedVideo=${_selectedVideo?.path}');
    if (_isImage && _selectedImage != null) {
      return _buildImagePreview();
    } else if (_selectedVideo != null) {
      return _buildVideoPreview();
    } else {
      // Fallback: should not happen, but show record options if no media selected
      debugPrint('[VideoRecorderSheet] WARNING: No media selected but preview was requested');
      return _buildRecordOptions();
    }
  }

  Widget _buildImagePreview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
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
            child: _selectedImage != null
                ? Image.file(
                    File(_selectedImage!.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('[VideoRecorderSheet] Error loading image: $error');
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
                  )
                : const Center(
                    child: ShimmerLoading(
                      width: 40,
                      height: 40,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          // Rest of the preview UI (mood tags, upload button, etc.)
          ..._buildPreviewControls(),
        ],
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
                    child: ShimmerLoading(
                      width: 40,
                      height: 40,
                      baseColor: Colors.white24,
                      highlightColor: Colors.white70,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          // Rest of the preview UI (mood tags, upload button, etc.)
          ..._buildPreviewControls(),
        ],
      ),
    );
  }

  List<Widget> _buildPreviewControls() {
    return [
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
                  _selectedImage = null;
                  _isImage = false;
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
                      ? const ShimmerLoading(
                          width: 20,
                          height: 20,
                          baseColor: Colors.white70,
                          highlightColor: Colors.white,
                        )
                      : Text(
                          _isImage ? 'Share Image' : 'Share Video',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
    ];
  }
}
