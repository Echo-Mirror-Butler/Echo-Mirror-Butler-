import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

/// Service for managing the Serverpod client with persistent authentication
/// This ensures authentication keys are stored in SharedPreferences and persist across app restarts
class ServerpodClientService {
  static ServerpodClientService? _instance;
  static ServerpodClientService get instance {
    _instance ??= ServerpodClientService._();
    return _instance!;
  }

  ServerpodClientService._();

  Client? _client;
  bool _isInitialized = false;
  SharedPreferencesAuthKeyProvider? _keyProvider;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the Serverpod client instance
  /// This client is configured with persistent authentication storage
  Client get client {
    if (_client == null) {
      throw StateError(
        'Client not initialized. Call ensureInitialized() first.',
      );
    }
    return _client!;
  }

  /// Initialize the client with persistent authentication key manager
  /// This must be called before using the client
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();

      // Create auth key provider with SharedPreferences
      final keyProvider = SharedPreferencesAuthKeyProvider(prefs);
      _keyProvider = keyProvider;

      // Check if we have a saved key before creating the client
      final savedKey = await keyProvider.get();
      if (savedKey != null) {
        debugPrint(
          '[ServerpodClientService] ✅ Found existing authentication key (${savedKey.length} chars) - user should be logged in',
        );
      } else {
        debugPrint(
          '[ServerpodClientService] No existing authentication key - user needs to login',
        );
      }

      // Create client and attach auth key provider
      _client = Client(ApiConstants.serverUrl);
      _client!.authKeyProvider = keyProvider;

      // Verify the client can access the header value
      if (_client != null) {
        final headerValue = await _client!.authKeyProvider?.authHeaderValue;
        if (headerValue != null) {
          debugPrint(
            '[ServerpodClientService] ✅ Client has authentication header configured',
          );
        } else if (savedKey != null) {
          debugPrint(
            '[ServerpodClientService] ⚠️ WARNING: Key exists but client cannot access it!',
          );
        }
      }

      _isInitialized = true;
      debugPrint(
        '[ServerpodClientService] ✅ Client initialized with persistent authentication',
      );
    } catch (e, stackTrace) {
      debugPrint('[ServerpodClientService] ❌ Error initializing client: $e');
      debugPrint('[ServerpodClientService] Stack trace: $stackTrace');
      // Fallback to default client if initialization fails
      _client = Client(ApiConstants.serverUrl);
      _isInitialized = true;
    }
  }
}

/// Custom auth key provider using SharedPreferences for persistent storage
class SharedPreferencesAuthKeyProvider implements ClientAuthKeyProvider {
  final SharedPreferences _prefs;
  static const String _key = 'serverpod_auth_key';

  SharedPreferencesAuthKeyProvider(this._prefs);

  // Helper to read saved key
  Future<String?> get() async {
    final key = _prefs.getString(_key);
    if (key != null) {
      debugPrint(
        '[SharedPreferencesAuthKeyProvider] ✅ Retrieved authentication key from SharedPreferences (${key.length} chars)',
      );
    } else {
      debugPrint(
        '[SharedPreferencesAuthKeyProvider] No authentication key found in SharedPreferences',
      );
    }
    return key;
  }

  Future<void> put(String key) async {
    debugPrint(
      '[SharedPreferencesAuthKeyProvider] Saving authentication key (${key.length} chars)',
    );
    await _prefs.setString(_key, key);
    debugPrint(
      '[SharedPreferencesAuthKeyProvider] ✅ Authentication key saved to SharedPreferences',
    );

    // Verify it was saved
    final saved = _prefs.getString(_key);
    if (saved != null) {
      debugPrint(
        '[SharedPreferencesAuthKeyProvider] ✅ Verified: Key is persisted',
      );
    } else {
      debugPrint(
        '[SharedPreferencesAuthKeyProvider] ❌ ERROR: Key was not saved!',
      );
    }
  }

  Future<void> remove() async {
    await _prefs.remove(_key);
  }

  // Support older interface versions
  Future<void> set(String key) async => put(key);

  @override
  Future<String?> get authHeaderValue async {
    final token = await get();
    if (token == null) {
      debugPrint(
        '[SharedPreferencesAuthKeyProvider] authHeaderValue: No token available',
      );
      return null;
    }

    // Remove "Bearer " prefix if present (we store just the token)
    String cleanToken = token;
    if (cleanToken.startsWith('Bearer ')) {
      cleanToken = cleanToken.substring(7);
    }

    // Return "Bearer <token>" format for the authorization header
    final headerValue = 'Bearer $cleanToken';
    debugPrint(
      '[SharedPreferencesAuthKeyProvider] authHeaderValue: Returning "Bearer <token>"',
    );
    return headerValue;
  }
}

extension ServerpodClientServiceAuthOps on ServerpodClientService {
  Future<void> saveAuthToken(String token) async {
    if (_keyProvider != null) {
      await _keyProvider!.put(token);
    } else {
      await _client?.authenticationKeyManager?.put(token);
    }
  }

  Future<void> clearAuthToken() async {
    if (_keyProvider != null) {
      await _keyProvider!.remove();
    } else {
      await _client?.authenticationKeyManager?.remove();
    }
  }

  Future<bool> hasAuth() async {
    final header = await _client?.authKeyProvider?.authHeaderValue;
    if (header != null) return true;
    final legacy = await _client?.authenticationKeyManager?.get();
    return legacy != null;
  }
}
