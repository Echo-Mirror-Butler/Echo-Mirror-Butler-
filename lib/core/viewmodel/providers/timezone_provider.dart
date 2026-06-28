import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/auth/viewmodel/providers/auth_provider.dart';
import '../../utils/date_formatter.dart';

final timezoneProvider = FutureProvider<String>((ref) async {
  final authState = ref.watch(authProvider);
  final userId = authState.user?.id;
  if (userId == null) return 'UTC';
  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('timezone')
        .eq('id', userId)
        .maybeSingle();
    if (response != null && response is Map && response['timezone'] != null) {
      return response['timezone'] as String;
    }
    return 'UTC';
  } catch (_) {
    return 'UTC';
  }
});

final timezoneStringProvider = Provider<String>((ref) {
  final tzAsync = ref.watch(timezoneProvider);
  return tzAsync.valueOrNull ?? 'UTC';
});
