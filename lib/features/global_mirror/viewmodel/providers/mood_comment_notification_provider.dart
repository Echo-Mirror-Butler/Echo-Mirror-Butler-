import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echomirror_server_client/echomirror_server_client.dart';
import '../../../../core/services/serverpod_client_service.dart';
import '../../data/models/mood_comment_notification_model.dart';

/// Provider for mood comment notifications
final moodCommentNotificationProvider =
    StateNotifierProvider<
      MoodCommentNotificationNotifier,
      List<MoodCommentNotificationModel>
    >((ref) {
      return MoodCommentNotificationNotifier();
    });

/// State notifier for managing mood comment notifications
/// NOTE: Requires Serverpod endpoints to be implemented (see SERVERPOD_COMMENTS_SETUP.md)
class MoodCommentNotificationNotifier
    extends StateNotifier<List<MoodCommentNotificationModel>> {
  MoodCommentNotificationNotifier() : super([]) {
    _loadNotifications();
  }

  Client get _client => ServerpodClientService.instance.client;

  /// Load notifications from Serverpod
  /// Note: Requires userId parameter - returns empty list if not authenticated
  Future<void> _loadNotifications() async {
    try {
      // TODO: Get userId from authentication when available
      // For now, notifications require userId, so return empty list
      // Once authentication is implemented, uncomment and use actual userId:
      // final userId = await getCurrentUserId(); // Implement this when auth is ready
      // if (userId == null) {
      //   state = [];
      //   return;
      // }
      // final notifications = await _client.global.getNotifications(userId);
      // state = notifications.map((n) {
      //   return MoodCommentNotificationModel(
      //     id: n.id?.toString() ?? '',
      //     moodPinId: n.moodPinId.toString(),
      //     commentId: n.commentId.toString(),
      //     commentText: n.commentText,
      //     sentiment: n.sentiment,
      //     timestamp: n.timestamp,
      //     isRead: n.isRead,
      //   );
      // }).toList()
      //   ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // For now, return empty list until authentication is implemented
      debugPrint(
        '[MoodCommentNotificationNotifier] Notifications require userId - authentication not yet implemented',
      );
      state = [];
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error loading notifications: $e',
      );
      state = [];
    }
  }

  /// Refresh notifications from server
  Future<void> refreshNotifications() async {
    await _loadNotifications();
  }

  /// Mark notification as read
  /// NOTE: Requires Serverpod endpoint to be implemented (see SERVERPOD_COMMENTS_SETUP.md)
  Future<void> markAsRead(String notificationId) async {
    try {
      final notifIdInt = int.tryParse(notificationId);
      if (notifIdInt == null) return;

      final success = await _client.global.markNotificationAsRead(notifIdInt);
      if (success) {
        await _loadNotifications(); // Refresh from server
      }
      await _loadNotifications(); // Refresh from server
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking notification as read: $e',
      );
    }
  }

  /// Mark all notifications as read
  /// Note: Requires userId - will be implemented when authentication is ready
  Future<void> markAllAsRead() async {
    try {
      // TODO: Get userId from authentication when available
      // final userId = await getCurrentUserId();
      // if (userId == null) return;
      // final success = await _client.global.markAllNotificationsAsRead(userId);
      // if (success) {
      //   await _loadNotifications(); // Refresh from server
      // }
      debugPrint(
        '[MoodCommentNotificationNotifier] markAllNotificationsAsRead requires userId - authentication not yet implemented',
      );
      await _loadNotifications(); // Refresh from server
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking all notifications as read: $e',
      );
    }
  }

  /// Delete a notification
  /// NOTE: Requires Serverpod endpoint to be implemented (see SERVERPOD_COMMENTS_SETUP.md)
  Future<void> deleteNotification(String notificationId) async {
    try {
      final notifIdInt = int.tryParse(notificationId);
      if (notifIdInt == null) return;

      final success = await _client.global.deleteNotification(notifIdInt);
      if (success) {
        await _loadNotifications(); // Refresh from server
      }
      await _loadNotifications(); // Refresh from server
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error deleting notification: $e',
      );
    }
  }

  /// Clear all notifications (delete all)
  /// NOTE: Requires Serverpod endpoint to be implemented (see SERVERPOD_COMMENTS_SETUP.md)
  Future<void> clearAll() async {
    try {
      // TODO: Uncomment after serverpod generate
      // Delete all notifications one by one
      // final notifications = List<MoodCommentNotificationModel>.from(state);
      // for (final notification in notifications) {
      //   final notifIdInt = int.tryParse(notification.id);
      //   if (notifIdInt != null) {
      //     await _client.global.deleteNotification(notifIdInt);
      //   }
      // }
      debugPrint(
        '[MoodCommentNotificationNotifier] clearAll endpoint not yet available',
      );
      await _loadNotifications(); // Refresh from server
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error clearing all notifications: $e',
      );
    }
  }

  /// Get unread count
  int get unreadCount => state.where((n) => !n.isRead).length;
}
