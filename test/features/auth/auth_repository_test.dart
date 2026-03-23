import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository', () {
    test('can instantiate', () {
      final repo = AuthRepository();
      expect(repo, isNotNull);
    });
  });
}
