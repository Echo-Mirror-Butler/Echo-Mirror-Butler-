import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth state class
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
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
  bool _isCheckingAuth = false;

  /// Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    if (_isCheckingAuth) return;
    _isCheckingAuth = true;
    state = state.copyWith(isLoading: true);
    try {
      final isAuth = await _repository.isAuthenticated();
      debugPrint('[AuthNotifier] Auth check result: $isAuth');

      if (isAuth) {
        final userData = await _repository.getCurrentUser();
        if (userData != null) {
          debugPrint('[AuthNotifier] âœ… User authenticated, loading user data');
          state = state.copyWith(
            user: UserModel.fromJson(userData),
            isLoading: false,
          );
        } else {
          debugPrint(
            '[AuthNotifier] âš ï¸ Authenticated but no user data available',
          );
          state = state.copyWith(isLoading: false);
        }
      } else {
        debugPrint('[AuthNotifier] User not authenticated');
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Error checking auth status: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _isCheckingAuth = false;
    }
  }

  /// Public method to check auth status (for router)
  Future<void> checkAuthStatus() async {
    await _checkAuthStatus();
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
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Sign up with email, password, and optional name
  Future<String?> signUp(String email, String password, String? name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = await _repository.signUp(email, password, name);

      debugPrint('[AuthNotifier] signUp received userId: $userId');

      state = state.copyWith(isLoading: false);
      return userId;
    } catch (e, stackTrace) {
      debugPrint('[AuthNotifier] signUp error: $e');
      debugPrint('[AuthNotifier] signUp stackTrace: $stackTrace');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Clear loading state after navigation
  void clearLoadingState() {
    state = state.copyWith(isLoading: false);
  }

  /// Sign out current user
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _repository.requestPasswordReset(email);
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Reset password with token
  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _repository.resetPassword(
        email,
        token,
        newPassword,
      );
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Change password for authenticated user
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _repository.changePassword(
        currentPassword,
        newPassword,
      );
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
