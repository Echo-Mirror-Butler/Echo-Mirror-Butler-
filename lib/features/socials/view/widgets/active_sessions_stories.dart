import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/themes/app_theme.dart';
import '../../data/models/video_session_model.dart';

/// Instagram stories-style widget for active sessions
class ActiveSessionsStories extends StatelessWidget {
  final List<VideoSessionModel> sessions;
  final Function(VideoSessionModel) onSessionTap;

  const ActiveSessionsStories({
    super.key,
    required this.sessions,
    required this.onSessionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sessions.length + 1, // +1 for "Your Story" placeholder
        itemBuilder: (context, index) {
          if (index == 0) {
            // "Your Story" placeholder (for starting new session)
            return _buildYourStoryItem(context, theme);
          }
          final session = sessions[index - 1];
          return _buildStoryItem(context, theme, session, index - 1);
        },
      ),
    );
  }

  Widget _buildYourStoryItem(BuildContext context, ThemeData theme) {
    return FadeInLeft(
      delay: Duration(milliseconds: 100),
      child: GestureDetector(
        onTap: () {
          // This will be handled by the parent's start session button
        },
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              // Story circle with plus icon
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                      ),
                      child: Icon(
                        Icons.add,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your Story',
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

  Widget _buildStoryItem(
    BuildContext context,
    ThemeData theme,
    VideoSessionModel session,
    int index,
  ) {
    final isActive = session.isActive;
    final participantCount = session.participantCount;

    return FadeInLeft(
      delay: Duration(milliseconds: 100 + (index * 50)),
      child: GestureDetector(
        onTap: () => onSessionTap(session),
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              // Story circle with gradient border
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive
                          ? LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withOpacity(0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive
                          ? null
                          : theme.colorScheme.onSurface.withOpacity(0.2),
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
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            )
                          : null,
                    ),
                  ),
                  // Participant count badge
                  if (participantCount > 0)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          participantCount.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // Active indicator
                  if (isActive)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                session.hostName,
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
}
