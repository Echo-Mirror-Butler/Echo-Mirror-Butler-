import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as auth_core;

// This test avoids code generation by using lightweight fakes

void main() {
  // Test data constants
  const testEmail = 'test@example.com';
  const testPassword = 'ValidPass123!';
  const testName = 'Test User';
  const testUserId = '550e8400-e29b-41d4-a716-446655440000';
  const testJwtToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U';
  const testResetToken = 'reset-token-123';
  const testNewPassword = 'NewPass456!';

  // Mock instances
  late _TestClient mockClient;
  late _FakeAuthenticationKeyManager fakeAuthKeyManager;
  late _FakeEndpointEmailIdp fakeEmailIdp;
  late AuthRepository authRepository;

  setUp(() {
    // Initialize fakes before each test
    fakeEmailIdp = _FakeEndpointEmailIdp();
    fakeAuthKeyManager = _FakeAuthenticationKeyManager();
    mockClient = _TestClient(
      emailIdp: fakeEmailIdp,
      keyManager: fakeAuthKeyManager,
    );

    // Set up SharedPreferences with mock initial values
    SharedPreferences.setMockInitialValues({});

    // Initialize the repository with the mock client
    authRepository = AuthRepository(client: mockClient);

    // Initial state: no token
    fakeAuthKeyManager.storedToken = null;
  });

  tearDown(() {
    // Clean up resources after each test
    // Reset SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
  });

  // Helper method to create a real AuthSuccess response
  auth_core.AuthSuccess createAuthSuccess({
    required String token,
    required String userId,
  }) {
    return auth_core.AuthSuccess(
      token: token,
      authUserId: UuidValue.fromString(userId),
      authStrategy: 'email',
      scopeNames: const <String>{},
    );
  }

  // No need for UuidValue helper; using local _MockUuidValue

  group('Sign In Tests', () {
    group('Success scenarios', () {
      test('signIn returns user ID on valid credentials', () async {
        // Arrange - Configure mocks for successful sign in
        final mockAuthSuccess = createAuthSuccess(
          token: testJwtToken,
          userId: testUserId,
        );
        fakeEmailIdp.loginResult = mockAuthSuccess;

        // Act
        final result = await authRepository.signIn(testEmail, testPassword);

        // Assert
        expect(result, isA<String>());
        expect(result, testUserId);
      });

      test('signIn saves token via AuthenticationKeyManager.put()', () async {
        // Arrange
        final mockAuthSuccess = createAuthSuccess(
          token: testJwtToken,
          userId: testUserId,
        );
        fakeEmailIdp.loginResult = mockAuthSuccess;

        // Act
        await authRepository.signIn(testEmail, testPassword);

        // Assert
        expect(fakeAuthKeyManager.putCount, 1);
        expect(fakeAuthKeyManager.storedToken, testJwtToken);
      });

      test('signIn saves user email and ID to SharedPreferences', () async {
        // Arrange
        final mockAuthSuccess = createAuthSuccess(
          token: testJwtToken,
          userId: testUserId,
        );
        fakeEmailIdp.loginResult = mockAuthSuccess;

        // Act
        await authRepository.signIn(testEmail, testPassword);

        // Assert - Verify data was saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('user_email'), testEmail);
        expect(prefs.getString('user_id'), testUserId);
      });

      test(
        'signIn calls backend login once with correct credentials',
        () async {
          // Arrange
          final mockAuthSuccess = createAuthSuccess(
            token: testJwtToken,
            userId: testUserId,
          );
          fakeEmailIdp.loginResult = mockAuthSuccess;

          // Act
          await authRepository.signIn(testEmail, testPassword);

          // Assert
          expect(fakeEmailIdp.loginCallCount, 1);
          expect(fakeEmailIdp.lastLoginEmail, testEmail);
          expect(fakeEmailIdp.lastLoginPassword, testPassword);
        },
      );
    });

    group('Failure scenarios', () {
      test('signIn throws on wrong password', () async {
        // Arrange - Configure mock to throw exception on login
        fakeEmailIdp.loginError = Exception('Invalid credentials');

        // Act & Assert
        expect(
          () => authRepository.signIn(testEmail, testPassword),
          throwsA(isA<Exception>()),
        );
      });

      test('signIn throws specific message when token missing', () async {
        // Arrange - Configure mock to return response with empty token
        final mockAuthSuccessNoToken = createAuthSuccess(
          token: '',
          userId: testUserId,
        );
        fakeEmailIdp.loginResult = mockAuthSuccessNoToken;
        fakeAuthKeyManager.storedToken = null;

        // Act & Assert
        expect(
          () => authRepository.signIn(testEmail, testPassword),
          throwsA(
            predicate(
              (e) =>
                  e is Exception &&
                  e.toString().contains(
                    'Login succeeded but no authentication token received',
                  ),
            ),
          ),
        );
      });

      test('signIn throws specific message when token save fails', () async {
        // Arrange - Configure mock to fail when saving token
        final mockAuthSuccess = createAuthSuccess(
          token: testJwtToken,
          userId: testUserId,
        );
        fakeEmailIdp.loginResult = mockAuthSuccess;
        fakeAuthKeyManager.failSave = true;

        // Act & Assert
        expect(
          () => authRepository.signIn(testEmail, testPassword),
          throwsA(
            predicate(
              (e) =>
                  e is Exception &&
                  e.toString().contains('Failed to save authentication token'),
            ),
          ),
        );
      });

      test('signIn does not save SharedPreferences on failure', () async {
        // Arrange - Configure mock to throw exception on login
        fakeEmailIdp.loginError = Exception('Invalid credentials');

        // Act
        try {
          await authRepository.signIn(testEmail, testPassword);
        } catch (e) {
          // Expected to throw
        }

        // Assert - Verify no data was saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('user_email'), isNull);
        expect(prefs.getString('user_id'), isNull);
      });
    });
  });

  group('Sign Up Tests', () {
    test('signUp returns userId on valid input', () async {
      // Arrange
      fakeEmailIdp.startRegistrationResult = UuidValue.fromString(testUserId);

      // Act
      final id = await authRepository.signUp(testEmail, testPassword, testName);

      // Assert
      expect(id, testUserId);
      expect(fakeEmailIdp.startRegistrationCallCount, 1);
      expect(fakeEmailIdp.lastStartRegistrationEmail, testEmail);
    });
  });

  group('Complete Sign Up Tests', () {
    const testAccountRequestId = testUserId;
    const testVerificationCode = '123456';

    test('completeSignUp returns account request ID on success', () async {
      // Arrange
      fakeEmailIdp.verifyRegistrationCodeResult = 'registration-token-123';
      fakeEmailIdp.finishRegistrationSuccess = true;

      // Act
      final result = await authRepository.completeSignUp(
        accountRequestId: testAccountRequestId,
        verificationCode: testVerificationCode,
        password: testPassword,
      );

      // Assert
      expect(result, testAccountRequestId);
      expect(fakeEmailIdp.verifyRegistrationCodeCallCount, 1);
      expect(fakeEmailIdp.finishRegistrationCallCount, 1);
    });

    test('completeSignUp throws on invalid accountRequestId format', () async {
      // Arrange
      const invalidUuid = 'not-a-uuid';

      // Act & Assert
      expect(
        () => authRepository.completeSignUp(
          accountRequestId: invalidUuid,
          verificationCode: testVerificationCode,
          password: testPassword,
        ),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                (e.toString().contains('Invalid accountRequestId format') ||
                    e.toString().contains('Complete sign up failed')),
          ),
        ),
      );
    });

    test('completeSignUp throws on invalid verification code', () async {
      // Arrange
      fakeEmailIdp.verifyRegistrationCodeError = Exception(
        'Invalid verification code',
      );

      // Act & Assert
      expect(
        () => authRepository.completeSignUp(
          accountRequestId: testAccountRequestId,
          verificationCode: 'wrong-code',
          password: testPassword,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Sign Out Tests', () {
    test('signOut clears stored credentials', () async {
      // Arrange: seed SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', testEmail);
      await prefs.setString('user_id', testUserId);
      fakeAuthKeyManager.storedToken = testJwtToken;

      // Reset the remove count before the test
      fakeAuthKeyManager.removeCount = 0;

      // Act
      await authRepository.signOut();

      // Assert: SharedPreferences cleared and key manager called
      expect(prefs.getString('user_email'), isNull);
      expect(prefs.getString('user_id'), isNull);
      expect(fakeAuthKeyManager.removeCount, 1);
    });
  });

  group('Get Current User Tests', () {
    test('getCurrentUser returns user data when authenticated', () async {
      // Arrange: set up authentication
      fakeAuthKeyManager.storedToken = testJwtToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', testEmail);
      await prefs.setString('user_id', testUserId);

      // Act
      final user = await authRepository.getCurrentUser();

      // Assert
      expect(user, isNotNull);
      expect(user!['id'], testUserId);
      expect(user['email'], testEmail);
      expect(user.containsKey('name'), isTrue);
      expect(user.containsKey('createdAt'), isTrue);
    });

    test('getCurrentUser returns null without authentication key', () async {
      // Arrange: no authentication key
      fakeAuthKeyManager.storedToken = null;

      // Act
      final user = await authRepository.getCurrentUser();

      // Assert
      expect(user, isNull);
    });

    test('getCurrentUser returns null without saved user_id', () async {
      // Arrange: has auth key but no user_id in SharedPreferences
      fakeAuthKeyManager.storedToken = testJwtToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', testEmail);
      // Don't set user_id

      // Act
      final user = await authRepository.getCurrentUser();

      // Assert
      expect(user, isNull);
    });
  });

  group('Is Authenticated Tests', () {
    test('isAuthenticated returns true with valid key', () async {
      // Arrange
      fakeAuthKeyManager.storedToken = testJwtToken;

      // Act
      final result = await authRepository.isAuthenticated();

      // Assert
      expect(result, isTrue);
    });

    test('isAuthenticated returns false without key', () async {
      // Arrange
      fakeAuthKeyManager.storedToken = null;

      // Act
      final result = await authRepository.isAuthenticated();

      // Assert
      expect(result, isFalse);
    });
  });

  group('Request Password Reset Tests', () {
    test('requestPasswordReset returns true', () async {
      // Arrange: provide dynamic passwordReset handler via fake client
      mockClient.passwordResetStub = _FakePasswordReset(success: true);

      // Act
      final ok = await authRepository.requestPasswordReset(testEmail);

      // Assert
      expect(ok, isTrue);
    });
  });

  group('Reset Password Tests', () {
    test('resetPassword returns true with valid token', () async {
      // Arrange
      mockClient.passwordResetStub = _FakePasswordReset(success: true);

      // Act
      final ok = await authRepository.resetPassword(
        testEmail,
        testResetToken,
        testNewPassword,
      );

      // Assert
      expect(ok, isTrue);
    });
  });

  group('Change Password Tests', () {
    test('changePassword returns true on success', () async {
      // Arrange - Set up authenticated user state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', testEmail);
      fakeAuthKeyManager.storedToken = testJwtToken;

      // Mock successful login for current password verification
      final mockAuthSuccess = createAuthSuccess(
        token: testJwtToken,
        userId: testUserId,
      );
      fakeEmailIdp.loginResult = mockAuthSuccess;
      fakeEmailIdp.changePasswordSuccess = true;

      // Act
      final result = await authRepository.changePassword(
        testPassword,
        testNewPassword,
      );

      // Assert
      expect(result, isTrue);
    });

    test('changePassword throws on failure', () async {
      // Arrange - Set up authenticated user state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', testEmail);
      fakeAuthKeyManager.storedToken = testJwtToken;

      // Mock successful login for current password verification
      final mockAuthSuccess = createAuthSuccess(
        token: testJwtToken,
        userId: testUserId,
      );
      fakeEmailIdp.loginResult = mockAuthSuccess;
      fakeEmailIdp.changePasswordError = Exception('Password change failed');

      // Act & Assert
      expect(
        () => authRepository.changePassword(testPassword, testNewPassword),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('Password change is not yet available'),
          ),
        ),
      );
    });
  });
}

// Fake Client with dynamic passwordReset getter support
class _TestClient extends Client {
  final EndpointEmailIdp _emailIdp;
  final AuthenticationKeyManager _authKeyManager;
  Object? passwordResetStub;
  ClientAuthKeyProvider? _authKeyProvider;

  _TestClient({
    required EndpointEmailIdp emailIdp,
    required AuthenticationKeyManager keyManager,
  }) : _emailIdp = emailIdp,
       _authKeyManager = keyManager,
       super('http://localhost') {
    // Create a fake auth key provider that wraps the key manager
    _authKeyProvider = _FakeAuthKeyProvider(keyManager);
  }

  @override
  EndpointEmailIdp get emailIdp => _emailIdp;

  @override
  AuthenticationKeyManager? get authenticationKeyManager => _authKeyManager;

  @override
  ClientAuthKeyProvider? get authKeyProvider => _authKeyProvider;

  @override
  set authKeyProvider(ClientAuthKeyProvider? provider) {
    _authKeyProvider = provider;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter &&
        invocation.memberName == const Symbol('passwordReset')) {
      return passwordResetStub;
    }
    return super.noSuchMethod(invocation);
  }
}

// No additional mock classes needed when using real AuthSuccess

// Fake AuthKeyProvider that wraps AuthenticationKeyManager
class _FakeAuthKeyProvider implements ClientAuthKeyProvider {
  final AuthenticationKeyManager _keyManager;

  _FakeAuthKeyProvider(this._keyManager);

  @override
  Future<String?> get authHeaderValue async {
    final token = await _keyManager.get();
    if (token == null || token.isEmpty) return null;
    return 'Bearer $token';
  }
}

// Minimal fake PasswordReset handler used via dynamic
class _FakePasswordReset {
  final bool success;
  final bool shouldThrow;
  _FakePasswordReset({required this.success, this.shouldThrow = false});

  Future<bool> requestPasswordReset(String email) async {
    if (shouldThrow) throw Exception('Password reset request failed');
    return success;
  }

  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    if (shouldThrow) throw Exception('Password reset failed');
    return success;
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (shouldThrow) throw Exception('Password change failed');
    return success;
  }
}

// Lightweight fake AuthenticationKeyManager
class _FakeAuthenticationKeyManager implements AuthenticationKeyManager {
  String? storedToken;
  int putCount = 0;
  bool failSave = false;
  int removeCount = 0;

  @override
  Future<String?> get() async {
    return storedToken;
  }

  @override
  Future<void> put(String token) async {
    putCount += 1;
    if (failSave) {
      storedToken = null;
      return;
    }
    storedToken = token;
  }

  @override
  Future<void> remove() async {
    storedToken = null;
    removeCount += 1;
  }

  @override
  Future<String?> getHeaderValue() async {
    return toHeaderValue(storedToken);
  }

  @override
  Future<String?> toHeaderValue(String? token) async {
    if (token == null || token.isEmpty) return null;
    return 'Bearer $token';
  }

  @override
  Future<String?> get authHeaderValue async => toHeaderValue(storedToken);
}

// Lightweight fake EndpointEmailIdp
class _FakeEndpointEmailIdp implements EndpointEmailIdp {
  auth_core.AuthSuccess? loginResult;
  Object? loginError;
  UuidValue? startRegistrationResult;
  String? verifyRegistrationCodeResult;
  Object? verifyRegistrationCodeError;
  bool finishRegistrationSuccess = false;
  bool changePasswordSuccess = false;
  Object? changePasswordError;
  int loginCallCount = 0;
  String? lastLoginEmail;
  String? lastLoginPassword;
  int startRegistrationCallCount = 0;
  String? lastStartRegistrationEmail;
  int verifyRegistrationCodeCallCount = 0;
  int finishRegistrationCallCount = 0;

  @override
  Future<auth_core.AuthSuccess> login({
    required String email,
    required String password,
  }) async {
    loginCallCount += 1;
    lastLoginEmail = email;
    lastLoginPassword = password;
    if (loginError != null) {
      throw loginError!;
    }
    return loginResult!;
  }

  @override
  Future<UuidValue> startRegistration({required String email}) async {
    startRegistrationCallCount += 1;
    lastStartRegistrationEmail = email;
    return startRegistrationResult!;
  }

  @override
  Future<String> verifyRegistrationCode({
    required UuidValue accountRequestId,
    required String verificationCode,
  }) async {
    verifyRegistrationCodeCallCount += 1;
    if (verifyRegistrationCodeError != null) {
      throw verifyRegistrationCodeError!;
    }
    return verifyRegistrationCodeResult ?? 'registration-token';
  }

  @override
  Future<auth_core.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) async {
    finishRegistrationCallCount += 1;
    if (!finishRegistrationSuccess) {
      throw Exception('Registration failed');
    }
    return loginResult ??
        auth_core.AuthSuccess(
          token: 'token',
          authUserId: UuidValue.fromString(
            '00000000-0000-0000-0000-000000000000',
          ),
          authStrategy: 'email',
          scopeNames: const <String>{},
        );
  }

  // Add changePassword method for the fake
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (changePasswordError != null) {
      throw changePasswordError!;
    }
    return changePasswordSuccess;
  }

  @override
  Future<bool> hasAccount() async => true;

  @override
  Future<UuidValue> startPasswordReset({required String email}) async =>
      UuidValue.fromString('00000000-0000-0000-0000-000000000001');

  @override
  Future<String> verifyPasswordResetCode({
    required UuidValue passwordResetRequestId,
    required String verificationCode,
  }) async => 'finishPasswordResetToken';

  @override
  Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) async {}

  @override
  String get name => 'emailIdp';

  @override
  EndpointCaller get caller => throw UnimplementedError();

  @override
  void resetStream() {}

  @override
  Future<void> sendStreamMessage(SerializableModel message) async {}

  @override
  ServerpodClientShared get client => throw UnimplementedError();

  @override
  set client(ServerpodClientShared value) {}

  @override
  Stream<SerializableModel> get stream => Stream<SerializableModel>.empty();
}
