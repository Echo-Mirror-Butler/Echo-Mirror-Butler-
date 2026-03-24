import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for authentication operations backed by Supabase
class AuthRepository {
  final SupabaseClient? _injectedClient;
  AuthRepository({SupabaseClient? supabaseClient})
      : _injectedClient = supabaseClient {
    debugPrint('[AuthRepository] Initialized');
  }

  SupabaseClient get _supabase =>
      _injectedClient ?? Supabase.instance.client;
  GoTrueClient get _auth => _supabase.auth;

  /// Sign in with email and password
  Future<String> signIn(String email, String password) async {
    try {
      debugPrint('[AuthRepository] signIn -> $email');
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
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
  Future<String> signUp(String email, String password, String? name) async {
    try {
      debugPrint('[AuthRepository] signUp -> $email | name: $name');
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );
      final user = response.user;
      if (user == null) {
        throw Exception('Sign up failed: no user returned');
      }
      debugPrint('[AuthRepository] signUp success -> ${user.id}');
      return user.id;
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] signUp error -> $e');
      debugPrint('[AuthRepository] signUp stackTrace -> $stackTrace');
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Complete signup — Supabase handles verification automatically via email link
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
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_id');
      debugPrint('[AuthRepository] Cleared saved user info');
    } catch (e) {
      debugPrint('[AuthRepository] signOut error -> $e');
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return {
          'id': user.id,
          'email': user.email ?? '',
          'name': user.userMetadata?['name'],
          'createdAt': user.createdAt,
        };
      }
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('user_id');
      if (savedUserId == null) return null;
      return {
        'id': savedUserId,
        'email': prefs.getString('user_email') ?? '',
        'name': null,
        'createdAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('[AuthRepository] getCurrentUser error -> $e');
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      if (_auth.currentSession != null) return true;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id') != null;
    } catch (e) {
      debugPrint('[AuthRepository] isAuthenticated error -> $e');
      return false;
    }
  }

  /// Change password for authenticated user
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      debugPrint('[AuthRepository] changePassword');
      await _auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      debugPrint('[AuthRepository] changePassword error -> $e');
      rethrow;
    }
  }

  /// Request password reset email
  Future<bool> requestPasswordReset(String email) async {
    try {
      debugPrint('[AuthRepository] requestPasswordReset -> $email');
      await _auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      debugPrint('[AuthRepository] requestPasswordReset error -> $e');
      return false;
    }
  }

  /// Reset password using Supabase session token
  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    try {
      debugPrint('[AuthRepository] resetPassword -> $email');
      await _auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      debugPrint('[AuthRepository] resetPassword error -> $e');
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }
}
