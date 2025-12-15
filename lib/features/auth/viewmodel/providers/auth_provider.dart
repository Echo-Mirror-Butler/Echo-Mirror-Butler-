import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth state class
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState()) {
    _checkAuthStatus();
  }

  final AuthRepository _repository;

  /// Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final isAuth = await _repository.isAuthenticated();
      if (isAuth) {
        final userData = await _repository.getCurrentUser();
        if (userData != null) {
          state = state.copyWith(
            user: UserModel.fromJson(userData),
            isLoading: false,
          );
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = await _repository.signIn(email, password);
      // In a real app, fetch user data after sign in
      final user = UserModel(
        id: userId,
        email: email,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Sign up with email, password, and optional name
  /// Note: Serverpod email auth requires email verification
  /// This only starts the registration process - returns accountRequestId
  /// User needs to verify email before they can login
  Future<String?> signUp(String email, String password, String? name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // This only starts registration - returns accountRequestId, not userId
      // User is NOT authenticated yet - they need to verify email first
      final accountRequestId = await _repository.signUp(email, password, name);
      
      debugPrint('[AuthNotifier] signUp received accountRequestId: $accountRequestId');
      
      // Don't update state here - let the UI handle it after navigation
      // This prevents the router from rebuilding and unmounting the widget
      // state = state.copyWith(isLoading: false);
      
      // Return accountRequestId so the UI can navigate to verification screen
      return accountRequestId;
    } catch (e, stackTrace) {
      debugPrint('[AuthNotifier] signUp error: $e');
      debugPrint('[AuthNotifier] signUp stackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
  
  /// Clear loading state after navigation (call this after navigating to verify screen)
  void clearLoadingState() {
    state = state.copyWith(isLoading: false);
  }

  /// Complete signup with verification code
  Future<bool> completeSignUp({
    required String accountRequestId,
    required String verificationCode,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Complete signup on server - this stores the authentication key automatically
      await _repository.completeSignUp(
        accountRequestId: accountRequestId,
        verificationCode: verificationCode,
        password: password,
      );
      
      debugPrint('[AuthNotifier] completeSignUp server call succeeded');
      
      // After successful verification, check auth status
      // Give it a moment for the auth key to be stored
      await Future.delayed(const Duration(milliseconds: 100));
      
      final isAuth = await _repository.isAuthenticated();
      debugPrint('[AuthNotifier] isAuthenticated after verification: $isAuth');
      
      if (isAuth) {
        // Try to get user data - if not available yet, create a placeholder user
        final userData = await _repository.getCurrentUser();
        if (userData != null && userData['email'] != null && (userData['email'] as String).isNotEmpty) {
          state = state.copyWith(
            user: UserModel.fromJson(userData),
            isLoading: false,
          );
          debugPrint('[AuthNotifier] User data loaded successfully');
        } else {
          // User is authenticated but we don't have full user data yet
          // This is okay - the user can still be considered authenticated
          // We'll fetch full user data later or create a minimal user
          state = state.copyWith(
            isLoading: false,
          );
          debugPrint('[AuthNotifier] User authenticated but user data not yet available');
        }
      } else {
        state = state.copyWith(isLoading: false);
        debugPrint('[AuthNotifier] User not authenticated after verification');
      }
      
      // Return true if server operation succeeded (no exception thrown)
      // The authentication key should be stored by Serverpod after finishRegistration
      return true;
    } catch (e, stackTrace) {
      debugPrint('[AuthNotifier] completeSignUp error: $e');
      debugPrint('[AuthNotifier] completeSignUp stackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

