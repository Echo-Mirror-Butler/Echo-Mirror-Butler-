import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/mood_pin_model.dart';
import '../../data/models/mood_pin_comment_model.dart';
import '../../viewmodel/providers/global_mirror_provider.dart';
import 'gift_button_widget.dart';

/// Dialog for viewing and adding comments on a mood pin
class MoodPinCommentDialog extends ConsumerStatefulWidget {
  final MoodPinModel pin;

  const MoodPinCommentDialog({super.key, required this.pin});

  @override
  ConsumerState<MoodPinCommentDialog> createState() =>
      _MoodPinCommentDialogState();
}

class _MoodPinCommentDialogState extends ConsumerState<MoodPinCommentDialog> {
  final TextEditingController _commentController = TextEditingController();
  final List<MoodPinCommentModel> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _clusterEncouragement;
  bool _isLoadingEncouragement = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadClusterEncouragement();
  }

  Future<void> _loadClusterEncouragement() async {
    setState(() => _isLoadingEncouragement = true);
    try {
      // Count nearby pins with same sentiment (simplified - count all pins with same sentiment)
      final allPinsAsync = ref.read(moodPinsStreamProvider);
      final allPins = allPinsAsync.value ?? [];
      final nearbyCount = allPins
          .where((p) => p.sentiment == widget.pin.sentiment)
          .length;

      final encouragement = await ref
          .read(globalMirrorProvider.notifier)
          .generateClusterEncouragement(widget.pin.sentiment, nearbyCount);

      if (mounted) {
        setState(() {
          _clusterEncouragement = encouragement;
          _isLoadingEncouragement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEncouragement = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await ref
          .read(globalMirrorProvider.notifier)
          .getCommentsForPin(widget.pin.id);
      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll(comments);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final success = await ref
          .read(globalMirrorProvider.notifier)
          .addComment(moodPinId: widget.pin.id, text: text, ref: ref);

      if (mounted) {
        if (success) {
          _commentController.clear();
          _loadComments(); // Reload comments
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment sent! 💙'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send comment. Please try again.'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
      case 'happy':
      case 'excited':
        return Colors.green;
      case 'calm':
      case 'grateful':
        return Colors.blue;
      case 'neutral':
      case 'reflective':
        return Colors.amber;
      case 'negative':
      case 'sad':
        return Colors.red;
      case 'anxious':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentimentColor = _getSentimentColor(widget.pin.sentiment);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sentimentColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: sentimentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support This Mood',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Send a message of support',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.pin.userId != null)
                    GiftButtonWidget(
                      recipientUserId: widget.pin.userId!,
                      compact: true,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Cluster encouragement message (if available)
            if (_clusterEncouragement != null &&
                _clusterEncouragement!.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.heart,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _clusterEncouragement!,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isLoadingEncouragement)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                child: ShimmerLoading(
                  width: double.infinity,
                  height: 40,
                  shape: ShimmerShape.rectangle,
                  radius: 12,
                ),
              ),

            // Comments list
            Expanded(
              child: _isLoading
                  ? const Center(child: ShimmerLoading(width: 40, height: 40))
                  : _comments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FontAwesomeIcons.heart,
                              size: 48,
                              color: theme.colorScheme.onSurface.withValues(alpha: 
                                0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface.withValues(alpha: 
                                  0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to send support!',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    FontAwesomeIcons.heart,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      comment.text,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getTimeAgo(comment.timestamp),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Comment input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      minLines: 1,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText:
                            'Send support... (e.g., "How are you?", "You\'re not alone")',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        counterText: '',
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSubmitting
                          ? const ShimmerLoading(
                              width: 20,
                              height: 20,
                              baseColor: Colors.white70,
                              highlightColor: Colors.white,
                            )
                          : const Icon(
                              FontAwesomeIcons.paperPlane,
                              color: Colors.white,
                              size: 18,
                            ),
                      onPressed: _isSubmitting ? null : _submitComment,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
