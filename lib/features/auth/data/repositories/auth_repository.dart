import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';

/// Repository for authentication operations
/// This handles all Serverpod backend calls for auth
class AuthRepository {
  AuthRepository() {
    // Initialize Serverpod client
    _client = Client(ApiConstants.serverUrl);
    debugPrint(
      '[AuthRepository] Initialized client -> ${ApiConstants.serverUrl}',
    );
  }

  late final Client _client;

  /// Sign in with email and password
  /// Returns user ID on success, throws exception on failure
  Future<String> signIn(String email, String password) async {
    try {
      debugPrint('[AuthRepository] signIn -> $email');
      await _client.emailIdp.login(
        email: email,
        password: password,
      );
      // AuthSuccess contains authentication information
      // The key is stored automatically by the client
      // Return a user identifier - you may need to create a custom endpoint
      // to get the actual user ID from the server
      debugPrint('[AuthRepository] signIn success -> $email');
      return 'user_${email.hashCode}';
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
        debugPrint('[AuthRepository] Successfully parsed accountRequestId to UuidValue');
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
      debugPrint('[AuthRepository] verifyRegistrationCode successful, got registrationToken');
      
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
      // Clear the authentication key
      debugPrint('[AuthRepository] signOut');
      await _client.authenticationKeyManager?.remove();
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
      if (key == null) return null;
      
      // For now, return basic user info
      // You'll need to create a custom endpoint in Serverpod to get full user details
      return {
        'id': 'user_${key.hashCode}',
        'email': '', // Get from custom endpoint
        'name': '', // Get from custom endpoint
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
      final result = await client.passwordReset.requestPasswordReset(email) as bool;
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
      final result = await client.passwordReset.resetPassword(
        email,
        token,
        newPassword,
      ) as bool;
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
      final result = await client.passwordReset.changePassword(
        currentPassword,
        newPassword,
      ) as bool;
      debugPrint('[AuthRepository] changePassword success -> $result');
      return result;
    } catch (e) {
      debugPrint('[AuthRepository] changePassword error -> $e');
      throw Exception('Password change failed: ${e.toString()}');
    }
  }
}

