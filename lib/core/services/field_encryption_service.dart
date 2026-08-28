import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service providing client-side Field-Level Encryption (FLE) for private
/// user data (e.g. mood reflection notes, future letters) before sending to Supabase.
///
/// Format: `enc:v1:<base64_iv>:<base64_ciphertext>`
class FieldEncryptionService {
  FieldEncryptionService._();

  static final FieldEncryptionService instance = FieldEncryptionService._();

  static const String prefix = 'enc:v1:';
  static const String _prefKey = 'echo_mirror_fle_master_key';

  Uint8List? _cachedKey;

  /// Initializes or retrieves the device master encryption key for the given user.
  Future<Uint8List> getOrCreateKey({String? userId, String? customPassphrase}) async {
    if (customPassphrase != null && customPassphrase.isNotEmpty) {
      return _deriveKeyFromPassphrase(customPassphrase, salt: userId ?? 'echo_mirror_default_salt');
    }

    if (_cachedKey != null) {
      return _cachedKey!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKeyBase64 = prefs.getString(_prefKey);

      if (storedKeyBase64 != null && storedKeyBase64.isNotEmpty) {
        _cachedKey = base64Decode(storedKeyBase64);
        return _cachedKey!;
      }

      // Generate a new 256-bit (32-byte) cryptographically secure key
      final random = Random.secure();
      final keyBytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        keyBytes[i] = random.nextInt(256);
      }

      await prefs.setString(_prefKey, base64Encode(keyBytes));
      _cachedKey = keyBytes;
      return keyBytes;
    } catch (_) {
      // Fallback when running in pure Dart unit test environments without initialized Flutter bindings
      final fallbackSalt = userId ?? 'echo_mirror_fallback_salt';
      _cachedKey = _deriveKeyFromPassphrase('echo_mirror_secure_device_fallback', salt: fallbackSalt);
      return _cachedKey!;
    }
  }

  /// Sets an explicit master key (e.g. during testing or key recovery).
  void setKey(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('Key must be exactly 32 bytes (256 bits)');
    }
    _cachedKey = key;
  }

  /// Clears in-memory cached key.
  void clearCache() {
    _cachedKey = null;
  }

  /// Derives a 256-bit key from a passphrase and salt using SHA-256 HMAC iterations.
  Uint8List _deriveKeyFromPassphrase(String passphrase, {required String salt}) {
    List<int> current = utf8.encode('$passphrase:$salt');
    final hmac = Hmac(sha256, utf8.encode(salt));

    // Simple PBKDF2-like iterative hashing
    for (int i = 0; i < 1000; i++) {
      current = hmac.convert(current).bytes;
    }

    return Uint8List.fromList(current.sublist(0, 32));
  }

  /// Checks if a string is encrypted with the `enc:v1:` prefix.
  bool isEncrypted(String? text) {
    if (text == null || text.isEmpty) return false;
    return text.startsWith(prefix);
  }

  /// Encrypts plaintext using AES-256-CBC with PKCS7 padding and a random 16-byte IV.
  Future<String> encrypt(String plainText, {Uint8List? keyOverride, String? userId}) async {
    if (plainText.isEmpty) return plainText;
    if (isEncrypted(plainText)) return plainText; // Idempotent: avoid double-encryption

    final keyBytes = keyOverride ?? await getOrCreateKey(userId: userId);
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return '$prefix${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts ciphertext. If the text is not encrypted (e.g. legacy plain text), returns as-is.
  Future<String> decrypt(String cipherText, {Uint8List? keyOverride, String? userId}) async {
    if (cipherText.isEmpty) return cipherText;
    if (!isEncrypted(cipherText)) {
      // Legacy plaintext note: return as-is for backward compatibility
      return cipherText;
    }

    try {
      final payload = cipherText.substring(prefix.length);
      final parts = payload.split(':');
      if (parts.length != 2) {
        throw const FormatException('Invalid encrypted payload format');
      }

      final iv = enc.IV.fromBase64(parts[0]);
      final encryptedData = enc.Encrypted.fromBase64(parts[1]);

      final keyBytes = keyOverride ?? await getOrCreateKey(userId: userId);
      final key = enc.Key(keyBytes);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      debugPrint('[FieldEncryptionService] Decryption failed: $e');
      return '[Decryption Error: Key mismatch or corrupted note]';
    }
  }

  /// Synchronously decrypts if the key is already cached in memory.
  String decryptSync(String cipherText, {Uint8List? keyOverride}) {
    if (cipherText.isEmpty || !isEncrypted(cipherText)) return cipherText;

    final keyBytes = keyOverride ?? _cachedKey;
    if (keyBytes == null) {
      return cipherText; // Return unparsed if key is not yet loaded synchronously
    }

    try {
      final payload = cipherText.substring(prefix.length);
      final parts = payload.split(':');
      if (parts.length != 2) return cipherText;

      final iv = enc.IV.fromBase64(parts[0]);
      final encryptedData = enc.Encrypted.fromBase64(parts[1]);
      final key = enc.Key(keyBytes);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      debugPrint('[FieldEncryptionService] Synchronous decryption failed: $e');
      return cipherText;
    }
  }

  /// Exports the current key as a Base64 string for backup/recovery.
  Future<String> exportRecoveryKey({String? userId}) async {
    final keyBytes = await getOrCreateKey(userId: userId);
    return base64Encode(keyBytes);
  }

  /// Imports and stores a Base64 recovery key.
  Future<void> importRecoveryKey(String base64Key) async {
    final keyBytes = base64Decode(base64Key.trim());
    if (keyBytes.length != 32) {
      throw ArgumentError('Invalid recovery key length. Must decode to 32 bytes.');
    }

    setKey(keyBytes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, base64Encode(keyBytes));
    } catch (_) {
      // Handled in-memory if persistent storage is unavailable in testing
    }
  }
}
