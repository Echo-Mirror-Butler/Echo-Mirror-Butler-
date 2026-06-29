import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Function(String)? _onNavigate;

  /// Initialize deep link handling
  /// [onNavigate] callback receives the route to navigate to
  Future<void> initialize({required Function(String) onNavigate}) async {
    _onNavigate = onNavigate;

    // Handle initial link when app is launched cold
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    // Handle links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        await _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link stream error: $err');
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');

    // Handle auth callback: echomirror://auth/callback#access_token=...
    if (uri.scheme == 'echomirror' && uri.host == 'auth') {
      await _handleAuthCallback(uri);
      return;
    }

    // Handle HTTPS universal links: https://echomirrorbutler.vercel.app/auth/callback
    if (uri.scheme == 'https' && uri.host == 'echomirrorbutler.vercel.app') {
      if (uri.path.startsWith('/auth/callback')) {
        await _handleAuthCallback(uri);
      }
    }
  }

  Future<void> _handleAuthCallback(Uri uri) async {
    try {
      // Parse fragment for auth tokens
      final fragment = uri.fragment;
      final queryParams = Uri.splitQueryString(fragment);

      final accessToken = queryParams['access_token'];
      final refreshToken = queryParams['refresh_token'];
      final type = queryParams['type'];

      debugPrint('Auth callback type: $type');

      if (accessToken != null && refreshToken != null) {
        // Set session in Supabase
        final response = await Supabase.instance.client.auth.setSession(
          refreshToken: refreshToken,
          accessToken: accessToken,
        );

        if (response.session != null) {
          debugPrint('Session set successfully');

          // Navigate based on type
          if (type == 'signup') {
            _onNavigate?.call('/verify-email-confirmed');
          } else if (type == 'recovery') {
            _onNavigate?.call('/reset-password?token=$accessToken');
          } else {
            // Default to dashboard for other auth types
            _onNavigate?.call('/dashboard');
          }
        }
      } else if (type == 'recovery' && accessToken != null) {
        // Password reset with just access token
        _onNavigate?.call('/reset-password?token=$accessToken');
      }
    } catch (e) {
      debugPrint('Error handling auth callback: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
