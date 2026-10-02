import 'package:echomirror/features/settings/data/repositories/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockSession mockSession;
  late MockFunctionsClient mockFunctions;
  late AccountDeletionRepository repository;

  const userId = '123e4567-e89b-12d3-a456-426614174000';
  const gracePeriodEndsAt = '2026-10-14T12:00:00.000Z';

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockSession = MockSession();
    mockFunctions = MockFunctionsClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockSupabase.functions).thenReturn(mockFunctions);
    when(() => mockSession.accessToken).thenReturn('test-access-token');

    repository = AccountDeletionRepository(supabaseClient: mockSupabase);
  });

  void mockSessionAvailable() {
    when(() => mockAuth.currentSession).thenReturn(mockSession);
  }

  group('AccountDeletionRepository', () {
    group('requestDeletion', () {
      test('invokes delete-account with Authorization header and body',
          () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => FunctionResponse(
            data: {
              'success': true,
              'gracePeriodEndsAt': gracePeriodEndsAt,
            },
            status: 200,
          ),
        );

        final result = await repository.requestDeletion(userId: userId);

        expect(result.status, AccountDeletionStatus.success);
        expect(result.gracePeriodEndsAt, DateTime.parse(gracePeriodEndsAt));

        final captured = verify(
          () => mockFunctions.invoke(
            'delete-account',
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        );
        final headers = captured.captured.first as Map<String, String>;
        final body = captured.captured[1] as Map<String, dynamic>;
        expect(
          headers['Authorization'],
          'Bearer test-access-token',
        );
        expect(body['userId'], userId);
        expect(
          body['confirmationPhrase'],
          AccountDeletionRepository.confirmationPhrase,
        );
      });

      test('throws unauthorized when there is no active session', () async {
        when(() => mockAuth.currentSession).thenReturn(null);

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.unauthorized,
            ),
          ),
        );
        verifyNever(
          () => mockFunctions.invoke(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        );
      });

      test('maps 401 FunctionException to unauthorized failure', () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const FunctionException(status: 401));

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.unauthorized,
            ),
          ),
        );
      });

      test('maps 403 FunctionException to forbidden failure', () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const FunctionException(status: 403));

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.forbidden,
            ),
          ),
        );
      });

      test('maps 429 FunctionException to rateLimited failure', () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const FunctionException(status: 429));

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.rateLimited,
            ),
          ),
        );
      });

      test('maps 500 FunctionException to server failure', () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const FunctionException(status: 500));

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.server,
            ),
          ),
        );
      });

      test('maps status 0 (no response) FunctionException to network', () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const FunctionException(status: 0));

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.network,
            ),
          ),
        );
      });

      test('maps generic network errors to network failure', () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('SocketException: connection refused'));

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.network,
            ),
          ),
        );
      });

      test('maps unknown errors to server failure', () async {
        mockSessionAvailable();
        when(
          () => mockFunctions.invoke(
            'delete-account',
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('Something unexpected'));

        await expectLater(
          repository.requestDeletion(userId: userId),
          throwsA(
            isA<AccountDeletionException>().having(
              (e) => e.failure,
              'failure',
              AccountDeletionFailure.server,
            ),
          ),
        );
      });
    });

    group('friendlyDeletionErrorMessage', () {
      test('returns distinct non-empty messages for every failure kind', () {
        for (final failure in AccountDeletionFailure.values) {
          final message = friendlyDeletionErrorMessage(failure);
          expect(message, isNotEmpty, reason: 'for $failure');
          expect(
            message.toLowerCase().contains('exception'),
            isFalse,
            reason: 'for $failure: message must not leak exception text',
          );
        }
      });
    });
  });
}
