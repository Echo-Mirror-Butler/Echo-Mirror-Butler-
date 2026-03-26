import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/mood_comment_notification_model.dart';

final moodCommentNotificationProvider =
    StateNotifierProvider<
      MoodCommentNotificationNotifier,
      List<MoodCommentNotificationModel>
    >((ref) {
      return MoodCommentNotificationNotifier();
    });

class MoodCommentNotificationNotifier
    extends StateNotifier<List<MoodCommentNotificationModel>> {
  MoodCommentNotificationNotifier() : super([]) {
    _loadNotifications();
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _loadNotifications() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        state = [];
        return;
      }

      final response = await _client
          .from('mood_comment_notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      state = response
          .map(
            (json) => MoodCommentNotificationModel(
              id: json['id']?.toString() ?? '',
              moodPinId: json['mood_pin_id']?.toString() ?? '',
              commentId: json['comment_id']?.toString() ?? '',
              commentText: json['comment_text'] ?? '',
              sentiment: json['sentiment'] ?? 'neutral',
              timestamp: json['created_at'] != null
                  ? DateTime.parse(json['created_at'])
                  : DateTime.now(),
              isRead: json['is_read'] ?? false,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error loading notifications: $e',
      );
      state = [];
    }
  }

  Future<void> refreshNotifications() async {
    await _loadNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('mood_comment_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      await _loadNotifications();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking notification as read: $e',
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('mood_comment_notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);
      await _loadNotifications();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking all notifications as read: $e',
      );
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _client
          .from('mood_comment_notifications')
          .delete()
          .eq('id', notificationId);
      await _loadNotifications();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error deleting notification: $e',
      );
    }
  }

  Future<void> clearAll() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('mood_comment_notifications')
          .delete()
          .eq('user_id', user.id);
      await _loadNotifications();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error clearing all notifications: $e',
      );
    }
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}
