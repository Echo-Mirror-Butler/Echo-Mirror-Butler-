import 'dart:typed_data';
import 'package:echomirror/core/services/field_level_encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FieldLevelEncryptionService (Issue #700)', () {
    late FieldLevelEncryptionService service;

    setUp(() {
      service = FieldLevelEncryptionService();
    });

    test('encrypts plaintext into prefixed ciphertext format', () {
      const plaintext = 'Very sensitive reflection on anxiety and hope.';
      final encrypted = service.encryptField(plaintext);

      expect(encrypted, startsWith(kFLEPrefix));
      expect(encrypted, isNot(contains(plaintext)));
      expect(service.isEncrypted(encrypted), isTrue);
    });

    test('decrypts encrypted string back to original plaintext', () {
      const original = 'Today was peaceful. Meditated for 20 minutes.';
      final encrypted = service.encryptField(original);
      final decrypted = service.decryptField(encrypted);

      expect(decrypted, equals(original));
    });

    test('transparently preserves legacy unencrypted notes without crashing', () {
      const legacyNote = 'Old plaintext note from previous app version';
      expect(service.isEncrypted(legacyNote), isFalse);

      final result = service.decryptField(legacyNote);
      expect(result, equals(legacyNote));
    });

    test('handles empty or null notes gracefully', () {
      expect(service.encryptField(''), equals(''));
      expect(service.encryptField(null), equals(''));
      expect(service.decryptField(''), equals(''));
      expect(service.decryptField(null), equals(''));
    });

    test('detects tampered ciphertext and protects against corruption', () {
      final encrypted = service.encryptField('Secret note');
      final parts = encrypted.split(':');
      // Tamper ciphertext part
      final tampered = '${parts[0]}:${parts[1]}:${parts[2]}tampered:${parts[3]}';

      final result = service.decryptField(tampered);
      expect(result, contains('unable to decrypt'));
    });

    test('custom derived key provides distinct isolation', () {
      final keyA = FieldLevelEncryptionService.deriveKey('passphraseA', 'salt1');
      final keyB = FieldLevelEncryptionService.deriveKey('passphraseB', 'salt1');

      final serviceA = FieldLevelEncryptionService(encryptionKey: keyA);
      final serviceB = FieldLevelEncryptionService(encryptionKey: keyB);

      const secret = 'Only for user A';
      final encryptedByA = serviceA.encryptField(secret);

      expect(serviceA.decryptField(encryptedByA), equals(secret));
      expect(serviceB.decryptField(encryptedByA), contains('unable to decrypt'));
    });

    test('generates valid 12-word recovery phrase', () {
      final phrase = FieldLevelEncryptionService.generateRecoveryPhrase();
      final words = phrase.split(' ');
      expect(words.length, equals(12));
      for (final w in words) {
        expect(w.isNotEmpty, isTrue);
      }
    });
  });
}
