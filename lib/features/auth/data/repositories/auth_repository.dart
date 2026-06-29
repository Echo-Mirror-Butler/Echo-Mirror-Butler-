import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for authentication operations backed by Supabase
class AuthRepository {
  final SupabaseClient? _injectedClient;

  AuthRepository({SupabaseClient? supabaseClient})
    : _injectedClient = supabaseClient {
    debugPrint('[AuthRepository] Initialized');
  }

  /// Get the Supabase client instance
  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  /// Sign in with email and password
  /// Returns user ID on success, throws exception on failure
  Future<String> signIn(String email, String password) async {
    try {
      debugPrint('[AuthRepository] signIn -> $email');

      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Sign in failed: no user returned');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_id', user.id);

      debugPrint('[AuthRepository] signIn success -> ${user.id}');
      return user.id;
    } catch (e) {
      debugPrint('[AuthRepository] signIn error -> $e');
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign up with email and password
  /// Supabase handles email verification automatically via confirm link.
  /// Returns user id.
  Future<String> signUp(String email, String password, String? name) async {
    try {
      debugPrint('[AuthRepository] signUp -> $email | name: $name');
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Sign up succeeded but no user returned');
      }

      debugPrint('[AuthRepository] signUp started. userId: ${user.id}');
      return user.id;
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] signUp error -> $e');
      debugPrint('[AuthRepository] signUp stackTrace -> $stackTrace');
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Complete signup â€” Supabase handles verification automatically via email link
  Future<String> completeSignUp({
    required String accountRequestId,
    required String verificationCode,
    required String password,
  }) async {
    debugPrint(
      '[AuthRepository] completeSignUp -> Supabase handles verification automatically',
    );
    return accountRequestId;
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      debugPrint('[AuthRepository] signOut');
      await _client.auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_id');

      debugPrint('[AuthRepository] signOut complete');
    } catch (e) {
      debugPrint('[AuthRepository] signOut error -> $e');
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Get current user
  /// Returns user data if authenticated, null otherwise
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('[AuthRepository] getCurrentUser: No active session user');
        return null;
      }

      debugPrint('[AuthRepository] getCurrentUser: Found -> ${user.id}');

      return {
        'id': user.id,
        'email': user.email ?? '',
        'name': user.userMetadata?['name'],
        'createdAt': user.createdAt,
      };
    } catch (e) {
      debugPrint('[AuthRepository] getCurrentUser error -> $e');
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      final session = _client.auth.currentSession;
      return session != null;
    } catch (e) {
      debugPrint('[AuthRepository] isAuthenticated error -> $e');
      return false;
    }
  }

  /// Change password for authenticated user (when already logged in)
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      debugPrint('[AuthRepository] changePassword');

      // Verify current password by re-authenticating
      final email = _client.auth.currentUser?.email;
      if (email == null) {
        throw Exception('User email not found. Please log in again.');
      }

      try {
        await _client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
      } catch (e) {
        debugPrint('[AuthRepository] Current password verification failed: $e');
        throw Exception('Current password is incorrect');
      }

      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      final success = response.user != null;
      debugPrint('[AuthRepository] changePassword success -> $success');
      return success;
    } catch (e) {
      debugPrint('[AuthRepository] changePassword error -> $e');
      rethrow;
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      debugPrint('[AuthRepository] requestPasswordReset -> $email');
      await _client.auth.resetPasswordForEmail(email);
      debugPrint('[AuthRepository] requestPasswordReset success');
      return true;
    } catch (e) {
      debugPrint('[AuthRepository] requestPasswordReset error -> $e');
      return false; // Don't throw to prevent email enumeration
    }
  }

  /// Reset password with token
  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    try {
      debugPrint('[AuthRepository] resetPassword');
      // Supabase email magic link / reset link automatically logs the user
      // in if the URL hash is processed.
      // After session is established, we update the user's password.
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      final success = response.user != null;
      debugPrint('[AuthRepository] resetPassword success -> $success');
      return success;
    } catch (e) {
      debugPrint('[AuthRepository] resetPassword error -> $e');
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  /// Sign in with Google via google_sign_in + Supabase signInWithIdToken
  Future<String> signInWithGoogle() async {
    try {
      debugPrint('[AuthRepository] signInWithGoogle');
      const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId.isNotEmpty ? webClientId : null,
        scopes: ['email'],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('No ID token from Google');

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      final user = response.user;
      if (user == null) throw Exception('Supabase sign-in failed');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user.email ?? '');
      await prefs.setString('user_id', user.id);

      debugPrint('[AuthRepository] signInWithGoogle success -> ${user.id}');
      return user.id;
    } catch (e) {
      debugPrint('[AuthRepository] signInWithGoogle error -> $e');
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }
}
