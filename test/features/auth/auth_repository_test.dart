import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/core/services/serverpod_client_service.dart';
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as auth_core;

// Import the generated mocks file (will be created by build_runner)
import 'auth_repository_test.mocks.dart';

// Generate mocks for the required dependencies
// Run: flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  ServerpodClientService,
  SharedPreferences,
  AuthenticationKeyManager,
  EndpointEmailIdp,
])
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
  late MockAuthenticationKeyManager mockAuthKeyManager;
  late MockEndpointEmailIdp mockEmailIdp;
  late AuthRepository authRepository;

  setUp(() {
    // Initialize mocks before each test
    mockEmailIdp = MockEndpointEmailIdp();
    mockAuthKeyManager = MockAuthenticationKeyManager();
    mockClient = _TestClient(
      emailIdp: mockEmailIdp,
      keyManager: mockAuthKeyManager,
    );

    // Set up SharedPreferences with mock initial values
    SharedPreferences.setMockInitialValues({});

    // Initialize the repository with the mock client
    authRepository = AuthRepository(client: mockClient);

    // Wire up key manager mocks
    when(mockAuthKeyManager.get()).thenAnswer((_) async => null);
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

        // Mock the emailIdp.login call
        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockAuthSuccess);

        when(mockAuthKeyManager.get()).thenAnswer((_) async => null);
        when(mockAuthKeyManager.put(any)).thenAnswer((_) async {});

        // Mock the second get() call to verify token was saved
        when(mockAuthKeyManager.get()).thenAnswer((_) async => testJwtToken);

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

        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockAuthSuccess);

        when(mockAuthKeyManager.get()).thenAnswer((_) async => null);
        when(mockAuthKeyManager.put(any)).thenAnswer((_) async {});
        when(mockAuthKeyManager.get()).thenAnswer((_) async => testJwtToken);

        // Act
        await authRepository.signIn(testEmail, testPassword);

        // Assert
        verify(mockAuthKeyManager.put(testJwtToken)).called(1);
      });

      test('signIn saves user email and ID to SharedPreferences', () async {
        // Arrange
        final mockAuthSuccess = createAuthSuccess(
          token: testJwtToken,
          userId: testUserId,
        );

        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockAuthSuccess);

        when(mockAuthKeyManager.get()).thenAnswer((_) async => null);
        when(mockAuthKeyManager.put(any)).thenAnswer((_) async {});
        when(mockAuthKeyManager.get()).thenAnswer((_) async => testJwtToken);

        // Act
        await authRepository.signIn(testEmail, testPassword);

        // Assert - Verify data was saved to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('user_email'), testEmail);
        expect(prefs.getString('user_id'), testUserId);
      });

      test('signIn calls backend login once with correct credentials', () async {
        // Arrange
        final mockAuthSuccess = createAuthSuccess(
          token: testJwtToken,
          userId: testUserId,
        );

        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockAuthSuccess);

        when(mockAuthKeyManager.get()).thenAnswer((_) async => null);
        when(mockAuthKeyManager.put(any)).thenAnswer((_) async {});
        when(mockAuthKeyManager.get()).thenAnswer((_) async => testJwtToken);

        // Act
        await authRepository.signIn(testEmail, testPassword);

        // Assert
        verify(mockEmailIdp.login(
          email: testEmail,
          password: testPassword,
        )).called(1);
      });
    });

    group('Failure scenarios', () {
      test('signIn throws on wrong password', () async {
        // Arrange - Configure mock to throw exception on login
        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(Exception('Invalid credentials'));

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

        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockAuthSuccessNoToken);

        when(mockAuthKeyManager.get()).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => authRepository.signIn(testEmail, testPassword),
          throwsA(
            predicate((e) =>
                e is Exception &&
                e.toString().contains('Login succeeded but no authentication token received')),
          ),
        );
      });

      test('signIn throws specific message when token save fails', () async {
        // Arrange - Configure mock to fail when saving token
        final mockAuthSuccess = createAuthSuccess(
          token: testJwtToken,
          userId: testUserId,
        );

        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockAuthSuccess);

        when(mockAuthKeyManager.get()).thenAnswer((_) async => null);
        when(mockAuthKeyManager.put(any)).thenAnswer((_) async {});
        // Second get() call returns null, indicating token wasn't saved
        when(mockAuthKeyManager.get()).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => authRepository.signIn(testEmail, testPassword),
          throwsA(
            predicate((e) =>
                e is Exception &&
                e.toString().contains('Failed to save authentication token')),
          ),
        );
      });

      test('signIn does not save SharedPreferences on failure', () async {
        // Arrange - Configure mock to throw exception on login
        when(mockEmailIdp.login(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(Exception('Invalid credentials'));

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
      when(mockEmailIdp.startRegistration(email: anyNamed('email')))
          .thenAnswer((_) async => UuidValue.fromString(testUserId));

      // Act
      final id = await authRepository.signUp(testEmail, testPassword, testName);

      // Assert
      expect(id, testUserId);
      verify(mockEmailIdp.startRegistration(email: testEmail)).called(1);
    });
  });

  group('Complete Sign Up Tests', () {
    // Tests will be implemented in subsequent tasks
  });

  group('Sign Out Tests', () {
    test('signOut clears stored credentials', () async {
      // Arrange: seed SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', testEmail);
      await prefs.setString('user_id', testUserId);

      // Stub remove on key manager
      when(mockAuthKeyManager.remove()).thenAnswer((_) async {});

      // Act
      await authRepository.signOut();

      // Assert: SharedPreferences cleared and key manager called
      expect(prefs.getString('user_email'), isNull);
      expect(prefs.getString('user_id'), isNull);
      verify(mockAuthKeyManager.remove()).called(1);
    });
  });

  group('Get Current User Tests', () {
    // Tests will be implemented in subsequent tasks
  });

  group('Is Authenticated Tests', () {
    // Tests will be implemented in subsequent tasks
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
      final ok =
          await authRepository.resetPassword(testEmail, testResetToken, testNewPassword);

      // Assert
      expect(ok, isTrue);
    });
  });

  group('Change Password Tests', () {
    // Optional: covered by repository; not required by acceptance
  });
}

// Fake Client with dynamic passwordReset getter support
class _TestClient extends Client {
  final EndpointEmailIdp _emailIdp;
  final AuthenticationKeyManager _authKeyManager;
  Object? passwordResetStub;

  _TestClient({
    required EndpointEmailIdp emailIdp,
    required AuthenticationKeyManager keyManager,
  })  : _emailIdp = emailIdp,
        _authKeyManager = keyManager,
        super(
          'http://localhost',
          authenticationKeyManager: keyManager,
        );

  @override
  EndpointEmailIdp get emailIdp => _emailIdp;

  @override
  AuthenticationKeyManager? get authenticationKeyManager => _authKeyManager;

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

// Minimal fake PasswordReset handler used via dynamic
class _FakePasswordReset {
  final bool success;
  _FakePasswordReset({required this.success});

  Future<bool> requestPasswordReset(String email) async => success;
  Future<bool> resetPassword(String email, String token, String newPassword) async =>
      success;
  Future<bool> changePassword(String currentPassword, String newPassword) async =>
      success;
}
