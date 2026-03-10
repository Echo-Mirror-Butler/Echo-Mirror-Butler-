import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as auth_core;
import 'package:shared_preferences/shared_preferences.dart';

class MockClient extends Mock implements Client {}

class MockEmailIdp extends Mock implements EndpointEmailIdp {}

class MockAuthSuccess extends Mock implements auth_core.AuthSuccess {}

class TestAuthKeyManager implements AuthenticationKeyManager {
  String? _key;
  @override
  Future<String?> get() async => _key;
  @override
  Future<void> put(String key) async {
    _key = key;
  }

  @override
  Future<void> remove() async {
    _key = null;
  }

  @override
  Future<String?> getHeaderValue() async {
    final k = await get();
    if (k == null) return null;
    return 'Bearer $k';
  }

  @override
  Future<String?> toHeaderValue(String? key) async {
    if (key != null) {
      var t = key;
      if (t.startsWith('Bearer ')) {
        t = t.substring(7);
      }
      await put(t);
      return t;
    }
    return await get();
  }

  @override
  Future<String?> get authHeaderValue async {
    final k = await get();
    if (k == null) return null;
    return 'Bearer $k';
  }
}

class TestPasswordResetApi {
  final bool requestResult;
  final bool resetResult;
  TestPasswordResetApi({this.requestResult = true, this.resetResult = true});
  Future<bool> requestPasswordReset(String email) async => requestResult;
  Future<bool> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async => resetResult;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthRepository', () {
    late MockClient client;
    late MockEmailIdp emailIdp;
    late TestAuthKeyManager keyManager;

    setUp(() {
      client = MockClient();
      emailIdp = MockEmailIdp();
      keyManager = TestAuthKeyManager();
      when(() => client.authenticationKeyManager).thenReturn(keyManager);
      when(() => client.emailIdp).thenReturn(emailIdp);
    });

    test('signIn returns user on valid credentials', () async {
      final authSuccess = MockAuthSuccess();
      final userUuid = UuidValue.fromString(
        '123e4567-e89b-12d3-a456-426614174000',
      );
      when(() => authSuccess.token).thenReturn('jwt_token_abc');
      when(() => authSuccess.authUserId).thenReturn(userUuid);
      when(
        () => emailIdp.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => authSuccess);

      final repo = AuthRepository(client: client);
      final userId = await repo.signIn('user@example.com', 'password123');

      expect(userId, userUuid.uuid);
      expect(await keyManager.get(), 'jwt_token_abc');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_email'), 'user@example.com');
      expect(prefs.getString('user_id'), userUuid.uuid);
    });

    test('signIn throws on wrong password', () async {
      when(
        () => emailIdp.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(Exception('invalid credentials'));
      final repo = AuthRepository(client: client);
      expect(
        () => repo.signIn('user@example.com', 'wrong'),
        throwsA(isA<Exception>()),
      );
    });

    test('signUp returns userId on valid input', () async {
      final reqId = UuidValue.fromString(
        '123e4567-e89b-12d3-a456-426614174111',
      );
      when(
        () => emailIdp.startRegistration(email: any(named: 'email')),
      ).thenAnswer((_) async => reqId);
      final repo = AuthRepository(client: client);
      final id = await repo.signUp('user@example.com', 'pass', 'User');
      expect(id, reqId.uuid);
    });

    test('requestPasswordReset returns true', () async {
      final resetApi = TestPasswordResetApi(requestResult: true);
      when(
        // ignore: deprecated_member_use
        () => client.noSuchMethod(Invocation.getter(#passwordReset)),
      ).thenReturn(resetApi);
      final repo = AuthRepository(client: client);
      final ok = await repo.requestPasswordReset('user@example.com');
      expect(ok, isTrue);
    });

    test('resetPassword returns true with valid token', () async {
      final resetApi = TestPasswordResetApi(resetResult: true);
      when(
        // ignore: deprecated_member_use
        () => client.noSuchMethod(Invocation.getter(#passwordReset)),
      ).thenReturn(resetApi);
      final repo = AuthRepository(client: client);
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
      await keyManager.put('jwt_token_xyz');

      final repo = AuthRepository(client: client);
      await repo.signOut();

      expect(await keyManager.get(), isNull);
      expect(prefs.getString('user_email'), isNull);
      expect(prefs.getString('user_id'), isNull);
    });
  });
}
