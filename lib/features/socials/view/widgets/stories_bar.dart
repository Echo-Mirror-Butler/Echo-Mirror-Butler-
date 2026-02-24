import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/themes/app_theme.dart';
import '../../data/models/video_session_model.dart';
import '../../data/models/story_model.dart';

/// Stories bar that shows both stories and live sessions
class StoriesBar extends StatefulWidget {
  final List<VideoSessionModel> liveSessions;
  final List<StoryModel> stories;
  final Function(VideoSessionModel)? onSessionTap;
  final Function(StoryModel)? onStoryTap;
  final VoidCallback? onAddStory;

  const StoriesBar({
    super.key,
    required this.liveSessions,
    required this.stories,
    this.onSessionTap,
    this.onStoryTap,
    this.onAddStory,
  });

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allItems = <_StoryItem>[];

    // Add "Your Story" button
    allItems.add(
      _StoryItem(type: _StoryItemType.addStory, onTap: widget.onAddStory),
    );

    // Group stories by userId - only show one circle per user (like Instagram)
    final Map<String, StoryModel> storiesByUser = {};
    for (var story in widget.stories) {
      // If user already has a story, keep the most recent one
      if (!storiesByUser.containsKey(story.userId) ||
          story.createdAt.isAfter(storiesByUser[story.userId]!.createdAt)) {
        storiesByUser[story.userId] = story;
      }
    }

    // Add one story circle per user
    for (var story in storiesByUser.values) {
      allItems.add(
        _StoryItem(
          type: _StoryItemType.story,
          story: story,
          onTap: () => widget.onStoryTap?.call(story),
        ),
      );
    }

    // Add live sessions with pulsing animation
    for (var session in widget.liveSessions) {
      allItems.add(
        _StoryItem(
          type: _StoryItemType.liveSession,
          session: session,
          onTap: () => widget.onSessionTap?.call(session),
        ),
      );
    }

    // Always show the stories bar, even if only "Your Story" button exists
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allItems.length,
        itemBuilder: (context, index) {
          final item = allItems[index];
          return _buildStoryItem(context, theme, item, index);
        },
      ),
    );
  }

  Widget _buildStoryItem(
    BuildContext context,
    ThemeData theme,
    _StoryItem item,
    int index,
  ) {
    return FadeInLeft(
      delay: Duration(milliseconds: 100 + (index * 50)),
      child: GestureDetector(
        onTap: item.onTap,
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              _buildStoryCircle(context, theme, item),
              const SizedBox(height: 8),
              Text(
                _getStoryLabel(item),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCircle(
    BuildContext context,
    ThemeData theme,
    _StoryItem item,
  ) {
    switch (item.type) {
      case _StoryItemType.addStory:
        return _buildAddStoryCircle(theme);
      case _StoryItemType.story:
        return _buildStoryCircleWidget(theme, item.story!);
      case _StoryItemType.liveSession:
        return _buildLiveSessionCircle(theme, item.session!);
    }
  }

  Widget _buildAddStoryCircle(ThemeData theme) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
        ),
        child: Icon(Icons.add, color: AppTheme.primaryColor, size: 28),
      ),
    );
  }

  Widget _buildStoryCircleWidget(ThemeData theme, StoryModel story) {
    final hasViewed =
        story.viewCount > 0; // Simplified - should check if current user viewed

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasViewed
            ? null
            : LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasViewed ? theme.colorScheme.onSurface.withValues(alpha: 0.2) : null,
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
          image: story.userAvatarUrl != null
              ? DecorationImage(
                  image: NetworkImage(story.userAvatarUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: story.userAvatarUrl == null
            ? Center(
                child: Text(
                  story.userName.isNotEmpty
                      ? story.userName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildLiveSessionCircle(ThemeData theme, VideoSessionModel session) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.red, Colors.red.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 
                  0.3 + (_pulseController.value * 0.3),
                ),
                blurRadius: 10 + (_pulseController.value * 10),
                spreadRadius: 2 + (_pulseController.value * 2),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              image: session.hostAvatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(session.hostAvatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: session.hostAvatarUrl == null
                ? Center(
                    child: FaIcon(
                      session.isVoiceOnly
                          ? FontAwesomeIcons.phone
                          : FontAwesomeIcons.video,
                      color: Colors.red,
                      size: 24,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  String _getStoryLabel(_StoryItem item) {
    switch (item.type) {
      case _StoryItemType.addStory:
        return 'Your Story';
      case _StoryItemType.story:
        return item.story!.userName;
      case _StoryItemType.liveSession:
        return '${item.session!.hostName} (LIVE)';
    }
  }
}

enum _StoryItemType { addStory, story, liveSession }

class _StoryItem {
  final _StoryItemType type;
  final StoryModel? story;
  final VideoSessionModel? session;
  final VoidCallback? onTap;

  _StoryItem({required this.type, this.story, this.session, this.onTap});
}
