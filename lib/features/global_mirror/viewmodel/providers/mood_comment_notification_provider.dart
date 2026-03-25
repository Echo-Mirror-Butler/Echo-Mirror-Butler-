import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// NOTE: Supabase endpoint migration pending
class MoodCommentNotificationNotifier
    extends StateNotifier<List<MoodCommentNotificationModel>> {
  MoodCommentNotificationNotifier() : super([]) {
    _loadNotifications();
  }

  /// Load notifications
  /// Note: Returns empty list until Supabase endpoints are implemented
  Future<void> _loadNotifications() async {
    try {
      // TODO: Implement via Supabase once endpoints are ready
      debugPrint(
        '[MoodCommentNotificationNotifier] Notifications require Supabase endpoint - not yet implemented',
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
  /// NOTE: Requires Supabase endpoint to be implemented
  Future<void> markAsRead(String notificationId) async {
    try {
      final notifIdInt = int.tryParse(notificationId);
      if (notifIdInt == null) return;

      // TODO: Implement via Supabase
      debugPrint(
        '[MoodCommentNotificationNotifier] markAsRead not yet implemented for Supabase',
      );
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking notification as read: $e',
      );
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      // TODO: Implement via Supabase
      debugPrint(
        '[MoodCommentNotificationNotifier] markAllAsRead not yet implemented for Supabase',
      );
      await _loadNotifications();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking all notifications as read: $e',
      );
    }
  }

  /// Delete a notification
  /// NOTE: Requires Supabase endpoint to be implemented
  Future<void> deleteNotification(String notificationId) async {
    try {
      final notifIdInt = int.tryParse(notificationId);
      if (notifIdInt == null) return;

      // TODO: Implement via Supabase
      debugPrint(
        '[MoodCommentNotificationNotifier] deleteNotification not yet implemented for Supabase',
      );
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error deleting notification: $e',
      );
    }
  }

  /// Clear all notifications (delete all)
  /// NOTE: Requires Supabase endpoint to be implemented
  Future<void> clearAll() async {
    try {
      // TODO: Implement via Supabase
      debugPrint(
        '[MoodCommentNotificationNotifier] clearAll not yet implemented for Supabase',
      );
      await _loadNotifications();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error clearing all notifications: $e',
      );
    }
  }

  /// Get unread count
  int get unreadCount => state.where((n) => !n.isRead).length;
}
