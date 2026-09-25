import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_logger.dart';

/// Service for tracking user sessions for security management
class SessionTrackingService {
  SessionTrackingService._();

  /// Track the current session in the user_sessions table
  /// Should be called after successful authentication
  static Future<void> trackCurrentSession() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;

      if (session == null || user == null) {
        AppLogger.debug('SessionTracking', 'No active session to track');
        return;
      }

      // Extract refresh token ID from the session
      // Supabase stores this in the session object
      final refreshToken = session.refreshToken;
      if (refreshToken == null) {
        AppLogger.warning('SessionTracking', 'No refresh token available');
        return;
      }

      // Get device information
      final deviceName = _getDeviceName();
      final userAgent = _getUserAgent();

      // Check if we already have a session for this refresh token
      final existing = await client
          .from('user_sessions')
          .select('id')
          .eq('user_id', user.id)
          .eq('refresh_token_id', refreshToken)
          .maybeSingle();

      if (existing != null) {
        // Update existing session
        await client
            .from('user_sessions')
            .update({
              'last_active': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
        AppLogger.debug('SessionTracking', 'Updated existing session');
      } else {
        // Create new session entry
        await client.from('user_sessions').insert({
          'user_id': user.id,
          'device_name': deviceName,
          'user_agent': userAgent,
          'refresh_token_id': refreshToken,
          'last_active': DateTime.now().toIso8601String(),
        });
        AppLogger.info('SessionTracking', 'Created new session entry');
      }
    } catch (e, stackTrace) {
      AppLogger.error('SessionTracking', e, stackTrace);
      // Don't throw - session tracking should not block authentication
    }
  }

  /// Get a human-readable device name
  static String _getDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    } else if (Platform.isAndroid) {
      return 'Android Device';
    } else if (Platform.isIOS) {
      return 'iOS Device';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isWindows) {
      return 'Windows PC';
    } else if (Platform.isLinux) {
      return 'Linux PC';
    }
    return 'Unknown Device';
  }

  /// Get user agent string
  static String _getUserAgent() {
    if (kIsWeb) {
      // In web, this would ideally come from the browser
      return 'Web/${Platform.operatingSystemVersion}';
    }
    return '${Platform.operatingSystem}/${Platform.operatingSystemVersion}';
  }

  /// Clean up session tracking for the current session on sign out
  static Future<void> clearCurrentSession() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;

      if (session == null || user == null) {
        return;
      }

      final refreshToken = session.refreshToken;
      if (refreshToken != null) {
        await client
            .from('user_sessions')
            .delete()
            .eq('user_id', user.id)
            .eq('refresh_token_id', refreshToken);
        AppLogger.info('SessionTracking', 'Cleared current session');
      }
    } catch (e, stackTrace) {
      AppLogger.error('SessionTracking', e, stackTrace);
      // Don't throw - session cleanup should not block sign out
    }
  }
}
