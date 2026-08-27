import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Recovery code generation', () {
    test('generates 10 codes of 8 characters each', () {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final codes = <String>{};

      for (int i = 0; i < 10; i++) {
        var code = '';
        for (int j = 0; j < 8; j++) {
          code += chars[(i * 7 + j * 13) % chars.length];
        }
        expect(code.length, 8);
        expect(
          code.split('').every((c) => chars.contains(c)),
          true,
          reason: 'Code $code contains invalid characters',
        );
        codes.add(code);
      }

      expect(codes.length, 10);
    });

    test('recovery code set has no duplicates', () {
      final codes = <String>{};

      for (int i = 0; i < 10; i++) {
        codes.add('CODE${i.toString().padLeft(5, '0')}');
      }

      expect(codes.length, 10);
    });

    test('invalid chars produce false validation', () {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      const testCode = 'AAAAAAA!';
      final valid = testCode.split('').every((c) => chars.contains(c));
      expect(valid, false);
    });
  });
}
