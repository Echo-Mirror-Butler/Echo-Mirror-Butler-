import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/view/screens/login_screen.dart';
import '../../features/auth/view/screens/signup_screen.dart';
import '../../features/auth/view/screens/verification_screen.dart';
import '../../features/auth/viewmodel/providers/auth_provider.dart';
import '../../features/dashboard/view/screens/mood_analytics_screen.dart';
import '../../features/logging/view/screens/create_entry_screen.dart';
import '../../features/logging/view/screens/entry_detail_screen.dart';
import '../../features/logging/data/models/log_entry_model.dart';
import '../../core/navigation/main_navigation_screen.dart';

/// Refresh notifier for GoRouter
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this.ref) {
    ref.listen(
      authProvider.select((state) => state.isAuthenticated),
      (_, __) => notifyListeners(),
    );
  }
  
  final Ref ref;
}

/// App router configuration with GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterRefreshNotifier(ref);
  
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      final isVerifying = state.matchedLocation == '/verify';
      final isAuthRoute = isLoggingIn || isSigningUp || isVerifying;

      // If authenticated and on auth pages, redirect to dashboard
      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      // If not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Allow navigation between auth screens when not authenticated
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify',
        name: 'verify',
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          return VerificationScreen(
            email: queryParams['email'] ?? '',
            accountRequestId: queryParams['accountRequestId'] ?? '',
            password: queryParams['password'] ?? '',
            name: queryParams['name'],
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/dashboard/mood-analytics',
        name: 'mood-analytics',
        builder: (context, state) => const MoodAnalyticsScreen(),
      ),
      GoRoute(
        path: '/logging',
        name: 'logging',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/logging/create',
        name: 'create-entry',
        builder: (context, state) => const CreateEntryScreen(),
      ),
      GoRoute(
        path: '/logging/detail/:id',
        name: 'entry-detail',
        builder: (context, state) {
          // Get entry from extra parameter passed during navigation
          final entry = state.extra as LogEntryModel?;
          if (entry == null) {
            // If no extra data, we'll handle it in the screen
            return Scaffold(
              appBar: AppBar(title: const Text('Entry Detail')),
              body: const Center(child: Text('Entry not found')),
            );
          }
          return EntryDetailScreen(entry: entry);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const MainNavigationScreen(),
      ),
    ],
  );
});

