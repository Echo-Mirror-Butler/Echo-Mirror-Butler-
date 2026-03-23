/// API-related constants.
class ApiConstants {
  ApiConstants._();

  /// Legacy Serverpod URL kept for temporary migration compatibility.
  static const String serverUrl = String.fromEnvironment(
    'SERVERPOD_URL',
    defaultValue: 'http://localhost:8080/',
  );

  /// Supabase project URL.
  /// Prefer setting this via --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase anon key.
  /// Prefer setting this via --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
