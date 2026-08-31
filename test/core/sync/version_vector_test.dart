import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/core/sync/version_vector.dart';

void main() {
  group('VersionVector', () {
    test('initial state and increment', () {
      var vv = VersionVector();
      expect(vv.getVersion('A'), 0);

      vv = vv.increment('A');
      expect(vv.getVersion('A'), 1);
      expect(vv.getVersion('B'), 0);

      vv = vv.increment('A').increment('B', 2);
      expect(vv.getVersion('A'), 2);
      expect(vv.getVersion('B'), 2);
    });

    test('merge takes pairwise maximum', () {
      final vv1 = VersionVector({'A': 2, 'B': 5, 'C': 1});
      final vv2 = VersionVector({'A': 4, 'B': 3, 'D': 7});

      final merged = vv1.merge(vv2);
      expect(merged.getVersion('A'), 4);
      expect(merged.getVersion('B'), 5);
      expect(merged.getVersion('C'), 1);
      expect(merged.getVersion('D'), 7);
    });

    test('dominates, identical, and concurrency detection', () {
      final base = VersionVector({'A': 1, 'B': 1});
      final identical = VersionVector({'A': 1, 'B': 1});
      final futureA = VersionVector({'A': 2, 'B': 1});
      final futureB = VersionVector({'A': 1, 'B': 2});

      expect(base.isIdentical(identical), isTrue);
      expect(futureA.dominates(base), isTrue);
      expect(base.dominates(futureA), isFalse);

      // Concurrent divergence: A advanced on one branch, B advanced on the other
      expect(futureA.isConcurrentWith(futureB), isTrue);
      expect(futureB.isConcurrentWith(futureA), isTrue);
      expect(futureA.dominates(futureB), isFalse);
      expect(futureB.dominates(futureA), isFalse);
    });

    test('map serialization and deserialization', () {
      final original = VersionVector({'node1': 10, 'node2': 25});
      final map = original.toMap();
      final restored = VersionVector.fromMap(map);

      expect(restored.isIdentical(original), isTrue);
    });
  });
}
