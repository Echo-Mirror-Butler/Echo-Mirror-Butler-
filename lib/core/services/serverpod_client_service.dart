import 'package:echomirror_server_client/echomirror_server_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serverpod_client/serverpod_client.dart';
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
      
      // Create custom authentication key manager with SharedPreferences
      final keyManager = SharedPreferencesAuthKeyManager(prefs);
      
      // Check if we have a saved key before creating the client
      final savedKey = await keyManager.get();
      if (savedKey != null) {
        debugPrint('[ServerpodClientService] ✅ Found existing authentication key (${savedKey.length} chars) - user should be logged in');
      } else {
        debugPrint('[ServerpodClientService] No existing authentication key - user needs to login');
      }
      
      // Create client with persistent authentication key manager
      // The key manager will automatically provide the saved key to the client
      _client = Client(
        ApiConstants.serverUrl,
        authenticationKeyManager: keyManager,
      );
      
      // Verify the client can access the key
      if (_client != null) {
        final clientKey = await _client!.authenticationKeyManager?.get();
        if (clientKey != null) {
          debugPrint('[ServerpodClientService] ✅ Client can access saved authentication key');
        } else if (savedKey != null) {
          debugPrint('[ServerpodClientService] ⚠️ WARNING: Key exists but client cannot access it!');
        }
      }
      
      _isInitialized = true;
      debugPrint('[ServerpodClientService] ✅ Client initialized with persistent authentication');
    } catch (e, stackTrace) {
      debugPrint('[ServerpodClientService] ❌ Error initializing client: $e');
      debugPrint('[ServerpodClientService] Stack trace: $stackTrace');
      // Fallback to default client if initialization fails
      _client = Client(ApiConstants.serverUrl);
      _isInitialized = true;
    }
  }
}

/// Custom authentication key manager using SharedPreferences for persistent storage
class SharedPreferencesAuthKeyManager implements AuthenticationKeyManager {
  final SharedPreferences _prefs;
  static const String _key = 'serverpod_auth_key';

  SharedPreferencesAuthKeyManager(this._prefs);

  @override
  Future<String?> get() async {
    final key = _prefs.getString(_key);
    if (key != null) {
      debugPrint('[SharedPreferencesAuthKeyManager] ✅ Retrieved authentication key from SharedPreferences (${key.length} chars)');
    } else {
      debugPrint('[SharedPreferencesAuthKeyManager] No authentication key found in SharedPreferences');
    }
    return key;
  }

  @override
  Future<void> put(String key) async {
    debugPrint('[SharedPreferencesAuthKeyManager] Saving authentication key (${key.length} chars)');
    await _prefs.setString(_key, key);
    debugPrint('[SharedPreferencesAuthKeyManager] ✅ Authentication key saved to SharedPreferences');
    
    // Verify it was saved
    final saved = await _prefs.getString(_key);
    if (saved != null) {
      debugPrint('[SharedPreferencesAuthKeyManager] ✅ Verified: Key is persisted');
    } else {
      debugPrint('[SharedPreferencesAuthKeyManager] ❌ ERROR: Key was not saved!');
    }
  }

  @override
  Future<void> remove() async {
    await _prefs.remove(_key);
  }

  @override
  Future<String?> getHeaderValue() async {
    final token = await get();
    if (token == null) {
      debugPrint('[SharedPreferencesAuthKeyManager] getHeaderValue: No token available');
      return null;
    }
    
    // Remove "Bearer " prefix if present (we store just the token)
    String cleanToken = token;
    if (cleanToken.startsWith('Bearer ')) {
      cleanToken = cleanToken.substring(7);
    }
    
    // Return "Bearer <token>" format for the authorization header
    final headerValue = 'Bearer $cleanToken';
    debugPrint('[SharedPreferencesAuthKeyManager] getHeaderValue: Returning "Bearer <token>" (${headerValue.length} chars)');
    return headerValue;
  }

  @override
  Future<String?> toHeaderValue(String? key) async {
    if (key != null) {
      // Save the key (remove Bearer prefix if present)
      String tokenToSave = key;
      if (tokenToSave.startsWith('Bearer ')) {
        tokenToSave = tokenToSave.substring(7);
      }
      await put(tokenToSave);
      
      // Return just the token (Serverpod will format the header)
      return tokenToSave;
    }
    // Return the saved token
    return await get();
  }

  @override
  Future<String?> get authHeaderValue async {
    final token = await get();
    if (token == null) {
      debugPrint('[SharedPreferencesAuthKeyManager] authHeaderValue: No token available');
      return null;
    }
    
    // Remove "Bearer " prefix if present (we store just the token)
    String cleanToken = token;
    if (cleanToken.startsWith('Bearer ')) {
      cleanToken = cleanToken.substring(7);
    }
    
    // Return "Bearer <token>" format for the authorization header
    final headerValue = 'Bearer $cleanToken';
    debugPrint('[SharedPreferencesAuthKeyManager] authHeaderValue: Returning "Bearer <token>" (${headerValue.length} chars)');
    return headerValue;
  }
}

