import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/serverpod_client_service.dart';

/// Repository for authentication operations
/// This handles all Serverpod backend calls for auth
class AuthRepository {
  AuthRepository() {
    debugPrint(
      '[AuthRepository] Initialized - client will be accessed when needed',
    );
  }

  /// Get the client instance (lazy initialization)
  Client get _client {
    // Ensure client is initialized before use
    if (!ServerpodClientService.instance.isInitialized) {
      throw StateError(
        'ServerpodClientService not initialized. Call ensureInitialized() in main() first.',
      );
    }
    return ServerpodClientService.instance.client;
  }

  /// Sign in with email and password
  /// Returns user ID on success, throws exception on failure
  Future<String> signIn(String email, String password) async {
    try {
      debugPrint('[AuthRepository] signIn -> $email');

      // Check if we have a key before login
      final keyBefore = await _client.authenticationKeyManager?.get();
      debugPrint(
        '[AuthRepository] Key before login: ${keyBefore != null ? "exists" : "null"}',
      );

      // Login and get the response
      final authResult = await _client.emailIdp.login(
        email: email,
        password: password,
      );

      // Extract the JWT token and user info from the AuthSuccess response
      final dynamic result = authResult;
      final String? token = result.token as String?;

      // authUserId might be UuidValue or String, handle both
      String? authUserId;
      try {
        final authUserIdValue = result.authUserId;
        if (authUserIdValue != null) {
          // Try to access .uuid property (for UuidValue) or use toString()
          try {
            // If it has a .uuid property, use it (UuidValue)
            final dynamic uuidValue = authUserIdValue;
            authUserId = uuidValue.uuid as String?;
          } catch (_) {
            // If .uuid doesn't work, try toString()
            authUserId = authUserIdValue.toString();
          }
        }
      } catch (e) {
        debugPrint('[AuthRepository] Error extracting authUserId: $e');
        authUserId = null;
      }

      debugPrint(
        '[AuthRepository] Login response - token: ${token != null ? "${token.length} chars" : "null"}, authUserId: $authUserId',
      );

      if (token == null || token.isEmpty) {
        debugPrint('[AuthRepository] ⚠️ No token found in login response');
        throw Exception('Login succeeded but no authentication token received');
      }

      // Save the JWT token to SharedPreferences for persistence
      debugPrint(
        '[AuthRepository] Saving JWT authentication token (${token.length} chars)...',
      );
      await _client.authenticationKeyManager?.put(token);

      // Save user info (email and authUserId) to SharedPreferences for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      if (authUserId != null && authUserId.isNotEmpty) {
        await prefs.setString('user_id', authUserId);
        debugPrint('[AuthRepository] Saved user ID from server: $authUserId');
      } else {
        // Fallback to email hash if authUserId not available
        final fallbackUserId = 'user_${email.hashCode}';
        await prefs.setString('user_id', fallbackUserId);
        debugPrint('[AuthRepository] Using fallback user ID: $fallbackUserId');
      }

      // Verify the token was saved
      final savedToken = await _client.authenticationKeyManager?.get();
      if (savedToken == null || savedToken != token) {
        debugPrint('[AuthRepository] ❌ ERROR: Token was not saved correctly!');
        throw Exception('Failed to save authentication token');
      }

      debugPrint('[AuthRepository] ✅ Authentication token and user info saved');

      // Return the user ID (prefer server's authUserId, fallback to email hash)
      final userId = authUserId ?? 'user_${email.hashCode}';
      debugPrint('[AuthRepository] signIn success -> $email, userId: $userId');
      return userId;
    } catch (e) {
      debugPrint('[AuthRepository] signIn error -> $e');
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign up with email and password
  /// Note: Serverpod requires email verification, so this is a two-step process
  /// Returns account request ID for verification
  Future<String> signUp(String email, String password, String? name) async {
    try {
      debugPrint('[AuthRepository] signUp -> $email | name: $name');
      // Step 1: Start registration (sends verification email)
      final accountRequestId = await _client.emailIdp.startRegistration(
        email: email,
      );

      // In a real app, you'd need to:
      // 1. Show a screen for the user to enter the verification code from email
      // 2. Call verifyRegistrationCode with the code
      // 3. Call finishRegistration with the token and password

      // Convert UuidValue to string - use the uuid property for proper formatting
      final accountRequestIdString = accountRequestId.uuid;
      debugPrint(
        '[AuthRepository] signUp started. accountRequestId=$accountRequestIdString (original type: ${accountRequestId.runtimeType})',
      );
      return accountRequestIdString;
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] signUp error -> $e');
      debugPrint('[AuthRepository] signUp stackTrace -> $stackTrace');
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Verify registration code and complete signup
  Future<String> completeSignUp({
    required String accountRequestId,
    required String verificationCode,
    required String password,
  }) async {
    try {
      debugPrint(
        '[AuthRepository] completeSignUp -> accountRequestId=$accountRequestId, verificationCode=$verificationCode',
      );

      // Convert string back to UuidValue
      UuidValue uuidValue;
      try {
        uuidValue = UuidValue.fromString(accountRequestId);
        debugPrint(
          '[AuthRepository] Successfully parsed accountRequestId to UuidValue',
        );
      } catch (e) {
        debugPrint('[AuthRepository] Failed to parse accountRequestId: $e');
        throw Exception('Invalid accountRequestId format: $accountRequestId');
      }

      // Step 2: Verify the code
      debugPrint('[AuthRepository] Calling verifyRegistrationCode...');
      final registrationToken = await _client.emailIdp.verifyRegistrationCode(
        accountRequestId: uuidValue,
        verificationCode: verificationCode,
      );
      debugPrint(
        '[AuthRepository] verifyRegistrationCode successful, got registrationToken',
      );

      // Step 3: Finish registration
      debugPrint('[AuthRepository] Calling finishRegistration...');
      await _client.emailIdp.finishRegistration(
        registrationToken: registrationToken,
        password: password,
      );

      // Registration complete - key is stored automatically
      debugPrint('[AuthRepository] completeSignUp success.');
      return accountRequestId;
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] completeSignUp error -> $e');
      debugPrint('[AuthRepository] completeSignUp stackTrace -> $stackTrace');
      throw Exception('Complete sign up failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      // Serverpod handles sign out through session management
      // Clear the authentication key and user info
      debugPrint('[AuthRepository] signOut');
      await _client.authenticationKeyManager?.remove();

      // Clear saved user info
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_id');
      debugPrint('[AuthRepository] Cleared saved user info');
    } catch (e) {
      debugPrint('[AuthRepository] signOut error -> $e');
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Get current user
  /// Returns user data if authenticated, null otherwise
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // Check if we have an authentication key
      final key = await _client.authenticationKeyManager?.get();
      if (key == null) {
        debugPrint('[AuthRepository] getCurrentUser: No authentication key');
        return null;
      }

      // Retrieve saved user info from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('user_email');
      final savedUserId = prefs.getString('user_id');

      if (savedUserId == null) {
        debugPrint('[AuthRepository] getCurrentUser: No saved user ID found');
        return null;
      }

      debugPrint(
        '[AuthRepository] getCurrentUser: Found saved user - id: $savedUserId, email: ${savedEmail ?? "not saved"}',
      );

      return {
        'id': savedUserId,
        'email': savedEmail ?? '',
        'name': null, // Get from custom endpoint if needed
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
      final key = await _client.authenticationKeyManager?.get();
      return key != null;
    } catch (e) {
      debugPrint('[AuthRepository] isAuthenticated error -> $e');
      return false;
    }
  }

  /// Request password reset
  /// Sends a reset token to the user's email
  Future<bool> requestPasswordReset(String email) async {
    try {
      debugPrint('[AuthRepository] requestPasswordReset -> $email');
      // Call the password reset endpoint
      // Note: This will be available after running 'serverpod generate'
      final dynamic client = _client;
      final result =
          await client.passwordReset.requestPasswordReset(email) as bool;
      debugPrint('[AuthRepository] requestPasswordReset success -> $result');
      return result;
    } catch (e) {
      debugPrint('[AuthRepository] requestPasswordReset error -> $e');
      // Return false on error, but don't throw to prevent email enumeration
      return false;
    }
  }

  /// Reset password with token
  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    try {
      debugPrint('[AuthRepository] resetPassword -> $email');
      // Call the password reset endpoint
      final dynamic client = _client;
      final result =
          await client.passwordReset.resetPassword(email, token, newPassword)
              as bool;
      debugPrint('[AuthRepository] resetPassword success -> $result');
      return result;
    } catch (e) {
      debugPrint('[AuthRepository] resetPassword error -> $e');
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  /// Change password for authenticated user
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      debugPrint('[AuthRepository] changePassword');
      // Call the password reset endpoint
      final dynamic client = _client;
      final result =
          await client.passwordReset.changePassword(
                currentPassword,
                newPassword,
              )
              as bool;
      debugPrint('[AuthRepository] changePassword success -> $result');
      return result;
    } catch (e) {
      debugPrint('[AuthRepository] changePassword error -> $e');
      throw Exception('Password change failed: ${e.toString()}');
    }
  }
}
