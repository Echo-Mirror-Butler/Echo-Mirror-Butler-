import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/view/screens/login_screen.dart';
import '../../features/auth/view/screens/signup_screen.dart';
import '../../features/auth/view/screens/forgot_password_screen.dart';
import '../../features/auth/view/screens/reset_password_screen.dart';
import '../../features/auth/view/screens/verify_email_screen.dart';
import '../../features/auth/view/verify_email_confirmed_screen.dart';
import '../../features/settings/view/screens/change_password_screen.dart';
import '../../features/settings/view/screens/security_screen.dart';
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
import '../../features/global_mirror/view/screens/wallet_screen.dart';
import '../../features/profile/view/screens/profile_screen.dart';
import '../../features/habits/view/screens/habits_screen.dart';

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
      final authState = ref.read(authProvider);
      if (authState.isLoading) {
        await ref.read(authProvider.notifier).checkAuthStatus();
      }
      final updatedAuthState = ref.read(authProvider);
      final isAuthenticated = updatedAuthState.isAuthenticated;
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      final isVerifyEmail = state.matchedLocation == '/verify-email';
      final isVerifyEmailConfirmed = state.matchedLocation == '/verify-email-confirmed';
      final isAuthRoute = isLoggingIn || isSigningUp;

      // /verify-email and /verify-email-confirmed are always accessible
      if (isVerifyEmail || isVerifyEmailConfirmed) return null;

      bool onboardingCompleted = false;
      try {
        onboardingCompleted = await ref.read(
          onboardingCompletedProvider.future,
        );
      } catch (e) {
        onboardingCompleted = false;
      }

      if (!onboardingCompleted && !isOnboarding) {
        return '/onboarding';
      }
      if (onboardingCompleted && isOnboarding) {
        return '/login';
      }
      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }
      if (!isAuthenticated && !isAuthRoute && !isOnboarding) {
        return '/login';
      }
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
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/verify-email-confirmed',
        name: 'verify-email-confirmed',
        builder: (context, state) => const VerifyEmailConfirmedScreen(),
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
          final entry = state.extra as LogEntryModel?;
          if (entry == null) {
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
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/security',
        name: 'security',
        builder: (context, state) => const SecurityScreen(),
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
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/gift/:userId',
        name: 'gift',
        builder: (context, state) =>
            GiftScreen(recipientUserId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/habits',
        name: 'habits',
        builder: (context, state) => const HabitsScreen(),
      ),
    ],
  );
});
