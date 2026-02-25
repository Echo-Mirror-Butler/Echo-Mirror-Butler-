import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/view/screens/login_screen.dart';
import '../../features/auth/view/screens/signup_screen.dart';
import '../../features/auth/view/screens/verification_screen.dart';
import '../../features/auth/view/screens/forgot_password_screen.dart';
import '../../features/auth/view/screens/reset_password_screen.dart';
import '../../features/settings/view/screens/change_password_screen.dart';
import '../../features/auth/viewmodel/providers/auth_provider.dart';
import '../../features/dashboard/view/screens/mood_analytics_screen.dart';
import '../../features/logging/view/screens/create_entry_screen.dart';
import '../../features/logging/view/screens/entry_detail_screen.dart';
import '../../features/logging/data/models/log_entry_model.dart';
import '../../features/onboarding/view/screens/onboarding_screen.dart';
import '../../features/onboarding/viewmodel/providers/onboarding_provider.dart';
import '../../features/dashboard/view/screens/main_navigation_screen.dart';
import '../../features/global_mirror/view/screens/mood_comment_notifications_screen.dart';
import '../../features/ai/view/screens/breathing_exercise_screen.dart';
import '../../features/ai/view/screens/music_recommendations_screen.dart';
import '../../features/global_mirror/view/screens/gift_screen.dart';
import '../../features/global_mirror/view/screens/gift_history_screen.dart';

/// Refresh notifier for GoRouter
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this.ref) {
    ref.listen(
      authProvider.select((state) => state.isAuthenticated),
      (_, _) => notifyListeners(),
    );
  }

  final Ref ref;
}

/// App router configuration with GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = GoRouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: notifier,
    redirect: (context, state) async {
      // Wait for auth check to complete if it's still loading
      final authState = ref.read(authProvider);
      if (authState.isLoading) {
        // Wait for auth check to complete
        await ref.read(authProvider.notifier).checkAuthStatus();
      }

      final updatedAuthState = ref.read(authProvider);
      final isAuthenticated = updatedAuthState.isAuthenticated;
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      final isVerifying = state.matchedLocation == '/verify';
      final isAuthRoute = isLoggingIn || isSigningUp || isVerifying;

      // Check if onboarding is completed
      // Use try-catch to handle any errors gracefully
      bool onboardingCompleted = false;
      try {
        onboardingCompleted = await ref.read(
          onboardingCompletedProvider.future,
        );
      } catch (e) {
        // If there's an error reading, assume not completed to be safe
        onboardingCompleted = false;
      }

      // If onboarding not completed and not on onboarding screen, redirect to onboarding
      if (!onboardingCompleted && !isOnboarding) {
        return '/onboarding';
      }

      // If onboarding completed and on onboarding screen, redirect to login
      if (onboardingCompleted && isOnboarding) {
        return '/login';
      }

      // If authenticated and on auth pages, redirect to dashboard
      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      // If not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute && !isOnboarding) {
        return '/login';
      }

      // Allow navigation between auth screens when not authenticated
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          return ResetPasswordScreen(
            email: queryParams['email'] ?? '',
            token: queryParams['token'] ?? '',
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
      GoRoute(
        path: '/settings/change-password',
        name: 'change-password',
        builder: (context, state) {
          // Import needed
          return const ChangePasswordScreen();
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const MoodCommentNotificationsScreen(),
      ),
      GoRoute(
        path: '/breathing',
        name: 'breathing',
        builder: (context, state) => const BreathingExerciseScreen(),
      ),
      GoRoute(
        path: '/music-recommendations',
        name: 'music-recommendations',
        builder: (context, state) => const MusicRecommendationsScreen(),
      ),
      GoRoute(
        path: '/gift/:userId',
        name: 'gift',
        builder: (context, state) => GiftScreen(
          recipientUserId: int.parse(state.pathParameters['userId']!),
        ),
      ),
      GoRoute(
        path: '/gift-history',
        name: 'giftHistory',
        builder: (context, state) => const GiftHistoryScreen(),
      ),
    ],
  );
});
