import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthResponse extends Mock implements AuthResponse {}

class MockUserResponse extends Mock implements UserResponse {}

class MockUser extends Mock implements User {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockGoogleAccount;
  late MockGoogleSignInAuthentication mockGoogleAuth;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(OAuthProvider.google);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockGoogleSignIn = MockGoogleSignIn();
    mockGoogleAccount = MockGoogleSignInAccount();
    mockGoogleAuth = MockGoogleSignInAuthentication();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockUser.id).thenReturn('123e4567-e89b-12d3-a456-426614174000');
  });

  group('AuthRepository', () {
    test('signIn returns user on valid credentials', () async {
      final mockResponse = MockAuthResponse();
      when(() => mockResponse.user).thenReturn(mockUser);
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => mockResponse);

      final repo = AuthRepository(supabaseClient: mockSupabase);
      final userId = await repo.signIn('user@example.com', 'password123');

      expect(userId, '123e4567-e89b-12d3-a456-426614174000');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_email'), 'user@example.com');
      expect(
        prefs.getString('user_id'),
        '123e4567-e89b-12d3-a456-426614174000',
      );
    });

    test('signIn throws on wrong password', () async {
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(Exception('invalid credentials'));

      final repo = AuthRepository(supabaseClient: mockSupabase);
      expect(
        () => repo.signIn('user@example.com', 'wrong'),
        throwsA(isA<Exception>()),
      );
    });

    test('signIn throws when Supabase returns no user', () async {
      final mockResponse = MockAuthResponse();
      when(() => mockResponse.user).thenReturn(null);
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => mockResponse);

      final repo = AuthRepository(supabaseClient: mockSupabase);

      expect(
        () => repo.signIn('user@example.com', 'password123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('no user returned'),
          ),
        ),
      );
    });

    test('signUp returns userId on valid input', () async {
      final mockResponse = MockAuthResponse();
      when(() => mockResponse.user).thenReturn(mockUser);
      when(
        () => mockAuth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => mockResponse);

      final repo = AuthRepository(supabaseClient: mockSupabase);
      final id = await repo.signUp('user@example.com', 'pass', 'User');
      expect(id, '123e4567-e89b-12d3-a456-426614174000');
    });

    test('signUp throws on duplicate email', () async {
      when(
        () => mockAuth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenThrow(AuthException('User already registered'));

      final repo = AuthRepository(supabaseClient: mockSupabase);

      expect(
        () => repo.signUp('user@example.com', 'pass', 'User'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Sign up failed'),
          ),
        ),
      );
    });

    test('signUp throws when Supabase returns no user', () async {
      final mockResponse = MockAuthResponse();
      when(() => mockResponse.user).thenReturn(null);
      when(
        () => mockAuth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => mockResponse);

      final repo = AuthRepository(supabaseClient: mockSupabase);

      expect(
        () => repo.signUp('user@example.com', 'pass', 'User'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('no user returned'),
          ),
        ),
      );
    });

    test('requestPasswordReset returns true', () async {
      when(
        () => mockAuth.resetPasswordForEmail(any()),
      ).thenAnswer((_) async {});

      final repo = AuthRepository(supabaseClient: mockSupabase);
      final ok = await repo.requestPasswordReset('user@example.com');
      expect(ok, isTrue);
    });

    test('requestPasswordReset returns false on Supabase error', () async {
      when(
        () => mockAuth.resetPasswordForEmail(any()),
      ).thenThrow(AuthException('Rate limit exceeded'));

      final repo = AuthRepository(supabaseClient: mockSupabase);
      final ok = await repo.requestPasswordReset('user@example.com');

      expect(ok, isFalse);
    });

    test('resetPassword returns true with valid token', () async {
      final mockResponse = MockUserResponse();
      when(() => mockResponse.user).thenReturn(mockUser);
      when(
        () => mockAuth.updateUser(any()),
      ).thenAnswer((_) async => mockResponse);

      final repo = AuthRepository(supabaseClient: mockSupabase);
      final ok = await repo.resetPassword(
        'user@example.com',
        'valid',
        'newpass',
      );
      expect(ok, isTrue);
    });

    test(
      'resetPassword returns false when update user returns no user',
      () async {
        final mockResponse = MockUserResponse();
        when(() => mockResponse.user).thenReturn(null);
        when(
          () => mockAuth.updateUser(any()),
        ).thenAnswer((_) async => mockResponse);

        final repo = AuthRepository(supabaseClient: mockSupabase);
        final ok = await repo.resetPassword(
          'user@example.com',
          'valid',
          'newpass',
        );

        expect(ok, isFalse);
      },
    );

    test('resetPassword throws when update user fails', () async {
      when(
        () => mockAuth.updateUser(any()),
      ).thenThrow(AuthException('Reset link expired'));

      final repo = AuthRepository(supabaseClient: mockSupabase);

      expect(
        () => repo.resetPassword('user@example.com', 'expired', 'newpass'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Password reset failed'),
          ),
        ),
      );
    });

    test('signOut clears stored credentials', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', 'user@example.com');
      await prefs.setString('user_id', 'abc123');

      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final repo = AuthRepository(supabaseClient: mockSupabase);
      await repo.signOut();

      expect(prefs.getString('user_email'), isNull);
      expect(prefs.getString('user_id'), isNull);
    });

    test('signOut calls Supabase signOut', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final repo = AuthRepository(supabaseClient: mockSupabase);
      await repo.signOut();

      verify(() => mockAuth.signOut()).called(1);
    });

    test(
      'changePassword returns true when re-auth and update succeed',
      () async {
        final mockAuthResponse = MockAuthResponse();
        final mockUserResponse = MockUserResponse();

        when(() => mockUser.email).thenReturn('user@example.com');
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockAuthResponse.user).thenReturn(mockUser);
        when(() => mockUserResponse.user).thenReturn(mockUser);
        when(
          () => mockAuth.signInWithPassword(
            email: 'user@example.com',
            password: 'current-password',
          ),
        ).thenAnswer((_) async => mockAuthResponse);
        when(
          () => mockAuth.updateUser(any()),
        ).thenAnswer((_) async => mockUserResponse);

        final repo = AuthRepository(supabaseClient: mockSupabase);
        final ok = await repo.changePassword(
          'current-password',
          'new-password',
        );

        expect(ok, isTrue);
        verify(
          () => mockAuth.signInWithPassword(
            email: 'user@example.com',
            password: 'current-password',
          ),
        ).called(1);
        verify(() => mockAuth.updateUser(any())).called(1);
      },
    );

    test('changePassword throws when current user email is missing', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final repo = AuthRepository(supabaseClient: mockSupabase);

      expect(
        () => repo.changePassword('current-password', 'new-password'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('User email not found'),
          ),
        ),
      );
    });

    test('changePassword throws when current password is incorrect', () async {
      when(() => mockUser.email).thenReturn('user@example.com');
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(
        () => mockAuth.signInWithPassword(
          email: 'user@example.com',
          password: 'wrong-password',
        ),
      ).thenThrow(AuthException('Invalid login credentials'));

      final repo = AuthRepository(supabaseClient: mockSupabase);

      expect(
        () => repo.changePassword('wrong-password', 'new-password'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Current password is incorrect'),
          ),
        ),
      );
    });

    test(
      'changePassword returns false when update user returns no user',
      () async {
        final mockAuthResponse = MockAuthResponse();
        final mockUserResponse = MockUserResponse();

        when(() => mockUser.email).thenReturn('user@example.com');
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockAuthResponse.user).thenReturn(mockUser);
        when(() => mockUserResponse.user).thenReturn(null);
        when(
          () => mockAuth.signInWithPassword(
            email: 'user@example.com',
            password: 'current-password',
          ),
        ).thenAnswer((_) async => mockAuthResponse);
        when(
          () => mockAuth.updateUser(any()),
        ).thenAnswer((_) async => mockUserResponse);

        final repo = AuthRepository(supabaseClient: mockSupabase);
        final ok = await repo.changePassword(
          'current-password',
          'new-password',
        );

        expect(ok, isFalse);
      },
    );
  });

  group('signInWithGoogle', () {
    test('returns user id on successful Google sign-in', () async {
      when(
        () => mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => mockGoogleAccount);
      when(
        () => mockGoogleAccount.authentication,
      ).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.idToken).thenReturn('google-id-token');
      when(() => mockGoogleAuth.accessToken).thenReturn('google-access-token');

      final mockResponse = MockAuthResponse();
      when(() => mockResponse.user).thenReturn(mockUser);
      when(() => mockUser.email).thenReturn('google@example.com');
      when(
        () => mockAuth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer((_) async => mockResponse);

      final repo = AuthRepository(
        supabaseClient: mockSupabase,
        googleSignIn: mockGoogleSignIn,
      );
      final userId = await repo.signInWithGoogle();

      expect(userId, '123e4567-e89b-12d3-a456-426614174000');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_email'), 'google@example.com');
      expect(
        prefs.getString('user_id'),
        '123e4567-e89b-12d3-a456-426614174000',
      );
    });

    test('throws when Google sign-in is cancelled (returns null)', () async {
      when(
        () => mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => null);

      final repo = AuthRepository(
        supabaseClient: mockSupabase,
        googleSignIn: mockGoogleSignIn,
      );

      expect(
        () => repo.signInWithGoogle(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Google sign-in failed'),
          ),
        ),
      );
    });

    test('throws when Google returns no id token', () async {
      when(
        () => mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => mockGoogleAccount);
      when(
        () => mockGoogleAccount.authentication,
      ).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.idToken).thenReturn(null);
      when(() => mockGoogleAuth.accessToken).thenReturn(null);

      final repo = AuthRepository(
        supabaseClient: mockSupabase,
        googleSignIn: mockGoogleSignIn,
      );

      expect(
        () => repo.signInWithGoogle(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Google sign-in failed'),
          ),
        ),
      );
    });

    test('throws when Supabase signInWithIdToken returns no user', () async {
      when(
        () => mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => mockGoogleAccount);
      when(
        () => mockGoogleAccount.authentication,
      ).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.idToken).thenReturn('google-id-token');
      when(() => mockGoogleAuth.accessToken).thenReturn('google-access-token');

      final mockResponse = MockAuthResponse();
      when(() => mockResponse.user).thenReturn(null);
      when(
        () => mockAuth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer((_) async => mockResponse);

      final repo = AuthRepository(
        supabaseClient: mockSupabase,
        googleSignIn: mockGoogleSignIn,
      );

      expect(
        () => repo.signInWithGoogle(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Google sign-in failed'),
          ),
        ),
      );
    });

    test('throws when Supabase signInWithIdToken raises an error', () async {
      when(
        () => mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => mockGoogleAccount);
      when(
        () => mockGoogleAccount.authentication,
      ).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.idToken).thenReturn('google-id-token');
      when(() => mockGoogleAuth.accessToken).thenReturn('google-access-token');
      when(
        () => mockAuth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenThrow(AuthException('OAuth token rejected'));

      final repo = AuthRepository(
        supabaseClient: mockSupabase,
        googleSignIn: mockGoogleSignIn,
      );

      expect(
        () => repo.signInWithGoogle(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Google sign-in failed'),
          ),
        ),
      );
    });
  });
}
