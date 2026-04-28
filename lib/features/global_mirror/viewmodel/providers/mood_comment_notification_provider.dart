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

  MoodCommentNotificationNotifier.forTesting() : super([]);

  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Load notifications
  Future<void> _loadNotifications() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      state = [];
      return;
    }

    try {
      final response = await _supabase
          .from('mood_comment_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      state = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MoodCommentNotificationModel.fromJson)
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

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      await _supabase
          .from('mood_comment_notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);

      state = [
        for (final notification in state)
          if (notification.id == notificationId)
            notification.copyWith(isRead: true)
          else
            notification,
      ];
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking notification as read: $e',
      );
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      await _supabase
          .from('mood_comment_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      state = [
        for (final notification in state) notification.copyWith(isRead: true),
      ];
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error marking all notifications as read: $e',
      );
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      await _supabase
          .from('mood_comment_notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', userId);

      state = state
          .where((notification) => notification.id != notificationId)
          .toList();
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error deleting notification: $e',
      );
    }
  }

  /// Clear all notifications (delete all)
  Future<void> clearAll() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      await _supabase
          .from('mood_comment_notifications')
          .delete()
          .eq('user_id', userId);

      state = [];
    } catch (e) {
      debugPrint(
        '[MoodCommentNotificationNotifier] Error clearing all notifications: $e',
      );
    }
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}
