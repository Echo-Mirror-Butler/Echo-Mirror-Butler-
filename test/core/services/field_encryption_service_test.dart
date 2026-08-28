import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:echomirror/core/services/field_encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FieldEncryptionService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FieldEncryptionService.instance;
    service.clearCache();
  });

  group('FieldEncryptionService (Security & Round-trip Integrity)', () {
    test('encrypt produces authenticated ciphertext with enc:v1 prefix', () async {
      const plainText = 'Today was a tough day, but I feel hopeful about tomorrow.';
      const userId = 'user-test-123';

      final encrypted = await service.encrypt(plainText, userId: userId);

      expect(service.isEncrypted(encrypted), isTrue);
      expect(encrypted.startsWith(FieldEncryptionService.prefix), isTrue);
      expect(encrypted.contains(plainText), isFalse); // Absolute ciphertext privacy
    });

    test('decrypt accurately recovers exact plaintext across complex UTF-8 and multiline notes', () async {
      const plainText = 'Reflections on 2026 🚀:\n- Meditated for 15 mins 🧘\n- Had coffee ☕\n- "Quotes & Symbols" <safe>';
      const userId = 'user-test-123';

      final encrypted = await service.encrypt(plainText, userId: userId);
      final decrypted = await service.decrypt(encrypted, userId: userId);

      expect(decrypted, equals(plainText));
    });

    test('decrypt gracefully returns legacy unencrypted plaintext notes unchanged', () async {
      const legacyNote = 'Legacy note created before encryption was introduced.';

      final decrypted = await service.decrypt(legacyNote);

      expect(decrypted, equals(legacyNote));
      expect(service.isEncrypted(legacyNote), isFalse);
    });

    test('encrypt is idempotent and prevents double-encryption', () async {
      const plainText = 'Private journal entry';
      const userId = 'user-idempotent';

      final encryptedOnce = await service.encrypt(plainText, userId: userId);
      final encryptedTwice = await service.encrypt(encryptedOnce, userId: userId);

      expect(encryptedTwice, equals(encryptedOnce));

      final decrypted = await service.decrypt(encryptedTwice, userId: userId);
      expect(decrypted, equals(plainText));
    });

    test('custom recovery passphrase allows restoring encrypted data across devices', () async {
      const secretNote = 'Secret goal: Run a marathon in October.';
      const customPassphrase = 'correct horse battery staple 2026';
      const userId = 'user-recovery-999';

      final key1 = await service.getOrCreateKey(userId: userId, customPassphrase: customPassphrase);
      final encrypted = await service.encrypt(secretNote, keyOverride: key1);

      // Simulate new device with same passphrase
      service.clearCache();
      final key2 = await service.getOrCreateKey(userId: userId, customPassphrase: customPassphrase);
      final decrypted = await service.decrypt(encrypted, keyOverride: key2);

      expect(decrypted, equals(secretNote));
    });

    test('export and import recovery key preserves decryption ability', () async {
      const privateReflection = 'Deep personal reflection about anxiety and recovery.';
      const userId = 'user-export-test';

      final encrypted = await service.encrypt(privateReflection, userId: userId);
      final exportedKeyBase64 = await service.exportRecoveryKey(userId: userId);

      expect(exportedKeyBase64.isNotEmpty, isTrue);

      // Simulate new device session
      service.clearCache();
      await service.importRecoveryKey(exportedKeyBase64);

      final decrypted = await service.decrypt(encrypted, userId: userId);
      expect(decrypted, equals(privateReflection));
    });

    test('wrong key fails gracefully without throwing an unhandled crash', () async {
      const plainText = 'Top secret note';
      final randomKey1 = Uint8List.fromList(List.generate(32, (i) => i));
      final randomKey2 = Uint8List.fromList(List.generate(32, (i) => 255 - i));

      final encrypted = await service.encrypt(plainText, keyOverride: randomKey1);
      final decrypted = await service.decrypt(encrypted, keyOverride: randomKey2);

      expect(decrypted.contains('[Decryption Error'), isTrue);
    });
  });
}
