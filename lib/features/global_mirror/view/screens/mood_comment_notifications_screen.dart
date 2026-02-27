import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/mood_comment_notification_provider.dart';

/// Screen showing notifications when someone comments on your mood pins
class MoodCommentNotificationsScreen extends ConsumerWidget {
  const MoodCommentNotificationsScreen({super.key});

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
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifications = ref.watch(moodCommentNotificationProvider);
    final unreadCount = ref
        .watch(moodCommentNotificationProvider.notifier)
        .unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mood Support',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ref
                    .read(moodCommentNotificationProvider.notifier)
                    .markAllAsRead();
              },
              icon: const Icon(FontAwesomeIcons.checkDouble, size: 16),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(FontAwesomeIcons.trash),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Notifications?'),
                    content: const Text(
                      'This will delete all notifications. This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(moodCommentNotificationProvider.notifier)
                              .clearAll();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Clear All',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(moodCommentNotificationProvider.notifier)
            .refreshNotifications(),
        child: notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FontAwesomeIcons.heart,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When someone comments on your mood,\nyou\'ll see it here',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final sentimentColor = _getSentimentColor(
                    notification.sentiment,
                  );

                  return Dismissible(
                    key: Key(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.trash,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) {
                      ref
                          .read(moodCommentNotificationProvider.notifier)
                          .deleteNotification(notification.id);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? theme.colorScheme.surface
                            : sentimentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: notification.isRead
                              ? theme.colorScheme.outline.withOpacity(0.2)
                              : sentimentColor.withOpacity(0.3),
                          width: notification.isRead ? 1 : 2,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sentiment indicator
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: sentimentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Content
                          Expanded(
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
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Someone sent you support',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withOpacity(0.1),
                                    ),
                                  ),
                                  child: Text(
                                    notification.commentText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      _getTimeAgo(notification.timestamp),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sentimentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        notification.sentiment,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: sentimentColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: unreadCount > 0
          ? FloatingActionButton.extended(
              onPressed: () {
                ref
                    .read(moodCommentNotificationProvider.notifier)
                    .markAllAsRead();
              },
              icon: const Icon(FontAwesomeIcons.checkDouble),
              label: Text('Mark all read ($unreadCount)'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
