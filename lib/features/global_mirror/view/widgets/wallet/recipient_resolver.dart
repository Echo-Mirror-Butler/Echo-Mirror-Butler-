import 'package:supabase_flutter/supabase_flutter.dart';

bool _isValidStellarKey(String key) {
  return key.length == 56 && key.startsWith('G');
}

/// Resolves a recipient typed as a user UUID, email, or Stellar public key
/// into a Supabase user id.
Future<String> resolveRecipientId(
  SupabaseClient supabase,
  String recipientInput,
) async {
  final trimmed = recipientInput.trim();
  if (trimmed.isEmpty) {
    throw Exception('Recipient address is required.');
  }

  final uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  if (uuidRegex.hasMatch(trimmed)) return trimmed;

  if (_isValidStellarKey(trimmed)) {
    final wallet = await supabase
        .from('user_wallets')
        .select('user_id')
        .eq('public_key', trimmed)
        .maybeSingle();
    if (wallet != null && wallet['user_id'] != null) {
      return wallet['user_id'] as String;
    }
    throw Exception('Could not resolve recipient from Stellar address.');
  }

  if (trimmed.contains('@')) {
    final profileTables = ['profiles', 'user_profiles'];
    for (final table in profileTables) {
      final profile = await supabase
          .from(table)
          .select('id')
          .eq('email', trimmed)
          .maybeSingle();
      if (profile != null && profile['id'] != null) {
        return profile['id'] as String;
      }
    }

    final lookup = await supabase.rpc(
      'lookup_user_by_email',
      params: {'email_input': trimmed},
    );
    if (lookup != null && lookup['user_id'] != null) {
      return lookup['user_id'] as String;
    }
    throw Exception('Could not resolve recipient from email.');
  }

  throw Exception(
    'Use a valid recipient UUID, email address, or Stellar address.',
  );
}
