import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror_flutter/echomirror_flutter.dart';

void main() {
  group('EchoMirrorFlutterBase', () {
    test('version returns the correct value', () {
      expect(EchoMirrorFlutterBase.version, '0.1.0');
    });

    test('greet returns the expected greeting', () {
      expect(
        EchoMirrorFlutterBase.greet('Alice'),
        'Hello, Alice! Welcome to EchoMirror.',
      );
    });
  });
}