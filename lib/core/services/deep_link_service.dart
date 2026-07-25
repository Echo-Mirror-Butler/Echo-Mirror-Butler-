import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  static const _pendingRouteKey = 'deep_link_pending_route';

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Function(String)? _onNavigate;
  String? _pendingRoute;

  Future<void> initialize({required Function(String) onNavigate}) async {
    _onNavigate = onNavigate;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

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

    // Auth callback: echomirror://auth/callback#access_token=...
    if (uri.scheme == 'echomirror' && uri.host == 'auth') {
      await _handleAuthCallback(uri);
      return;
    }

    // HTTPS universal links
    if (uri.scheme == 'https') {
      if (uri.host == 'echomirrorbutler.vercel.app') {
        if (uri.path.startsWith('/auth/callback')) {
          await _handleAuthCallback(uri);
          return;
        }
        // Content deep links via universal links
        final route = _mapUniversalLink(uri);
        if (route != null) {
          _navigateToContent(route);
          return;
        }
      }
      debugPrint('Unrecognized universal link: $uri');
      return;
    }

    // Custom scheme content deep links
    if (uri.scheme == 'echomirror') {
      final route = _mapCustomSchemeLink(uri);
      if (route != null) {
        _navigateToContent(route);
        return;
      }
    }

    debugPrint('Unrecognized deep link: $uri');
  }

  String? _mapCustomSchemeLink(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    switch (segments[0]) {
      case 'gift':
        if (segments.length >= 2 && segments[1].isNotEmpty) {
          return '/gift/${segments[1]}';
        }
        return null;
      case 'leaderboard':
        return '/leaderboard';
      case 'log':
        if (segments.length >= 2 && segments[1].isNotEmpty) {
          return '/logging/detail/${segments[1]}';
        }
        return null;
      default:
        return null;
    }
  }

  String? _mapUniversalLink(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    switch (segments[0]) {
      case 'gift':
        if (segments.length >= 2 && segments[1].isNotEmpty) {
          return '/gift/${segments[1]}';
        }
        return null;
      case 'leaderboard':
        return '/leaderboard';
      case 'log':
        if (segments.length >= 2 && segments[1].isNotEmpty) {
          return '/logging/detail/${segments[1]}';
        }
        return null;
      default:
        return null;
    }
  }

  void _navigateToContent(String route) {
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;

    if (isAuthenticated) {
      debugPrint('User authenticated, navigating to: $route');
      _onNavigate?.call(route);
    } else {
      debugPrint('User not authenticated, saving pending route: $route');
      _savePendingRoute(route);
      _onNavigate?.call('/login');
    }
  }

  Future<void> _savePendingRoute(String route) async {
    _pendingRoute = route;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingRouteKey, route);
    } catch (e) {
      debugPrint('Failed to save pending route: $e');
    }
  }

  /// Returns the saved pending route and clears it.
  /// Should be called after a successful login.
  Future<String?> consumePendingRoute() async {
    if (_pendingRoute != null) {
      final route = _pendingRoute;
      _pendingRoute = null;
      _clearStoredPendingRoute();
      return route;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_pendingRouteKey);
      if (route != null) {
        await prefs.remove(_pendingRouteKey);
      }
      return route;
    } catch (e) {
      debugPrint('Failed to read pending route: $e');
      return null;
    }
  }

  Future<void> _clearStoredPendingRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingRouteKey);
    } catch (e) {
      debugPrint('Failed to clear pending route: $e');
    }
  }

  Future<void> _handleAuthCallback(Uri uri) async {
    try {
      final fragment = uri.fragment;
      final queryParams = Uri.splitQueryString(fragment);

      final accessToken = queryParams['access_token'];
      final refreshToken = queryParams['refresh_token'];
      final type = queryParams['type'];

      debugPrint('Auth callback type: $type');

      if (accessToken != null && refreshToken != null) {
        final response = await Supabase.instance.client.auth.setSession(
          refreshToken: refreshToken,
          accessToken: accessToken,
        );

        if (response.session != null) {
          debugPrint('Session set successfully');

          // Check for pending deep link
          final pendingRoute = await consumePendingRoute();
          if (pendingRoute != null) {
            debugPrint('Resuming pending route after auth: $pendingRoute');
            _onNavigate?.call(pendingRoute);
            return;
          }

          if (type == 'signup') {
            _onNavigate?.call('/verify-email-confirmed');
          } else if (type == 'recovery') {
            _onNavigate?.call('/reset-password?token=$accessToken');
          } else {
            _onNavigate?.call('/dashboard');
          }
        }
      } else if (type == 'recovery' && accessToken != null) {
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
