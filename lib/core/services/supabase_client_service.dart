import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/api_constants.dart';

/// Service for initializing and accessing the shared Supabase client.
class SupabaseClientService {
  SupabaseClientService._();

  static SupabaseClientService? _instance;
  static SupabaseClientService get instance {
    _instance ??= SupabaseClientService._();
    return _instance!;
  }

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'Supabase is not initialized. Call ensureInitialized() first.',
      );
    }
    return Supabase.instance.client;
  }

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    if (ApiConstants.supabaseUrl.isEmpty ||
        ApiConstants.supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
      );
    }

    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      anonKey: ApiConstants.supabaseAnonKey,
      debug: kDebugMode,
    );

    _isInitialized = true;
    debugPrint('[SupabaseClientService] Supabase initialized');
  }

  /// Initializes Supabase with placeholder credentials for `flutter test`.
  ///
  /// Avoids [StateError] when code paths touch [client] without
  /// `--dart-define=SUPABASE_*`. No network calls occur until a repository
  /// issues a real request.
  @visibleForTesting
  static Future<void> ensureInitializedForTesting() async {
    final self = instance;
    if (self._isInitialized) return;

    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.test-placeholder-signature',
      debug: false,
    );
    self._isInitialized = true;
    debugPrint('[SupabaseClientService] Supabase initialized for tests');
  }
}
