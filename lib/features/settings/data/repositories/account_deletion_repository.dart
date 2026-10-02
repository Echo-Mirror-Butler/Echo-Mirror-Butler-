import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Why an in-app account deletion request failed.
enum AccountDeletionFailure {
  unauthorized,
  forbidden,
  rateLimited,
  server,
  network,
}

/// Typed failure for the in-app account deletion flow.
///
/// Carries a [AccountDeletionFailure] kind so the UI can show a friendly,
/// non-raw message without leaking exception text.
class AccountDeletionException implements Exception {
  const AccountDeletionException(this.failure);

  final AccountDeletionFailure failure;

  @override
  String toString() => 'AccountDeletionException(${failure.name})';
}

/// Successful response from the `delete-account` edge function.
class AccountDeletionResult {
  const AccountDeletionResult({required this.status, this.gracePeriodEndsAt});

  final AccountDeletionStatus status;

  /// When the 14-day grace period ends and hard deletion is scheduled.
  final DateTime? gracePeriodEndsAt;
}

/// Status of a deletion request (kept separate so the UI can branch without
/// inspecting exceptions).
enum AccountDeletionStatus { success }

/// Repository for the in-app account deletion flow (Issue #759).
///
/// Calls the `delete-account` Supabase Edge Function with the current
/// session's Authorization header (required since Issue #742) and maps raw
/// transport errors into typed [AccountDeletionFailure]s.
class AccountDeletionRepository {
  AccountDeletionRepository({SupabaseClient? supabaseClient})
    : _injectedClient = supabaseClient;

  final SupabaseClient? _injectedClient;

  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  /// The exact phrase the user must type to confirm deletion.
  ///
  /// Must stay in sync with `CONFIRMATION_PHRASE` in
  /// `supabase/functions/delete-account/index.ts`.
  static const String confirmationPhrase = 'DELETE MY ACCOUNT';

  /// Requests soft deletion of the signed-in user's account.
  ///
  /// Returns an [AccountDeletionResult] on success, or throws an
  /// [AccountDeletionException] with a mapped failure kind.
  Future<AccountDeletionResult> requestDeletion({
    required String userId,
  }) async {
    final session = _client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null || token.isEmpty) {
      throw const AccountDeletionException(AccountDeletionFailure.unauthorized);
    }

    try {
      final response = await _client.functions.invoke(
        'delete-account',
        headers: {'Authorization': 'Bearer $token'},
        body: {'userId': userId, 'confirmationPhrase': confirmationPhrase},
      );

      return AccountDeletionResult(
        status: AccountDeletionStatus.success,
        gracePeriodEndsAt: _parseGracePeriodEndsAt(response.data),
      );
    } on FunctionException catch (e) {
      debugPrint('[AccountDeletionRepository] delete-account failed: $e');
      throw AccountDeletionException(_mapStatus(e.status));
    } catch (e) {
      debugPrint('[AccountDeletionRepository] delete-account failed: $e');
      throw AccountDeletionException(_mapGenericError(e));
    }
  }

  /// Maps an edge-function failure to a user-facing failure kind.
  ///
  /// Uses the base [FunctionException.status] (rather than subtype checks)
  /// so this compiles against any functions_client 2.x version.
  /// Network/transport failures surface with status 0 (no response).
  AccountDeletionFailure _mapStatus(int status) {
    return switch (status) {
      0 => AccountDeletionFailure.network,
      401 => AccountDeletionFailure.unauthorized,
      403 => AccountDeletionFailure.forbidden,
      429 => AccountDeletionFailure.rateLimited,
      _ => AccountDeletionFailure.server,
    };
  }

  /// Maps unexpected errors (e.g. socket failures thrown by the HTTP stack)
  /// to a user-facing failure kind.
  AccountDeletionFailure _mapGenericError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('connection') ||
        raw.contains('network') ||
        raw.contains('timeout')) {
      return AccountDeletionFailure.network;
    }
    return AccountDeletionFailure.server;
  }

  DateTime? _parseGracePeriodEndsAt(dynamic data) {
    if (data is Map && data['gracePeriodEndsAt'] is String) {
      return DateTime.tryParse(data['gracePeriodEndsAt'] as String);
    }
    return null;
  }
}

/// Friendly, non-raw error message for a deletion failure.
///
/// Never includes exception details — safe to render in the UI.
String friendlyDeletionErrorMessage(AccountDeletionFailure failure) {
  switch (failure) {
    case AccountDeletionFailure.unauthorized:
      return 'Your session has expired. Please sign in again and try '
          'deleting your account once more.';
    case AccountDeletionFailure.forbidden:
      return 'You can only delete the account you are currently signed '
          'in to.';
    case AccountDeletionFailure.rateLimited:
      return 'Too many attempts. Please wait a few minutes before trying '
          'again.';
    case AccountDeletionFailure.network:
      return 'Could not reach EchoMirror. Check your internet connection '
          'and try again.';
    case AccountDeletionFailure.server:
      return 'We could not process your deletion request right now. '
          'Please try again later.';
  }
}

/// Provider for the account deletion repository.
final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  return AccountDeletionRepository();
});
