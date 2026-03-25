import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthResponse extends Mock implements AuthResponse {}

class MockUserResponse extends Mock implements UserResponse {}

class MockUser extends Mock implements User {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
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

    test('requestPasswordReset returns true', () async {
      when(
        () => mockAuth.resetPasswordForEmail(any()),
      ).thenAnswer((_) async {});

      final repo = AuthRepository(supabaseClient: mockSupabase);
      final ok = await repo.requestPasswordReset('user@example.com');
      expect(ok, isTrue);
    });

    test('resetPassword returns true with valid token', () async {
      final mockResponse = MockUserResponse();
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
  });
}
