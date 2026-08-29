import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/core/sync/hlc.dart';

void main() {
  group('HybridLogicalClock (HLC)', () {
    test('monotonicity: clock strictly advances on successive ticks within same millisecond', () {
      final t0 = 1700000000000;
      final hlc1 = Hlc.now('device-A', physicalTimeMillis: t0);
      final hlc2 = Hlc.now('device-A', physicalTimeMillis: t0, latestKnown: hlc1);
      final hlc3 = Hlc.now('device-A', physicalTimeMillis: t0, latestKnown: hlc2);

      expect(hlc1.millis, t0);
      expect(hlc1.counter, 0);

      expect(hlc2.millis, t0);
      expect(hlc2.counter, 1);

      expect(hlc3.millis, t0);
      expect(hlc3.counter, 2);

      expect(hlc2.isAfter(hlc1), isTrue);
      expect(hlc3.isAfter(hlc2), isTrue);
      expect(hlc1.compareTo(hlc2), lessThan(0));
    });

    test('monotonicity: counter resets to 0 when physical clock advances', () {
      final t0 = 1700000000000;
      final t1 = 1700000005000; // 5 seconds later
      final hlc1 = Hlc.now('device-A', physicalTimeMillis: t0);
      final hlc2 = Hlc.now('device-A', physicalTimeMillis: t0, latestKnown: hlc1);
      expect(hlc2.counter, 1);

      final hlc3 = Hlc.now('device-A', physicalTimeMillis: t1, latestKnown: hlc2);
      expect(hlc3.millis, t1);
      expect(hlc3.counter, 0);
      expect(hlc3.isAfter(hlc2), isTrue);
    });

    test('causality: receive remote HLC with forward clock advances local clock', () {
      final localPhysical = 1700000000000;
      final remotePhysical = 1700000010000; // Remote physical clock is 10s ahead

      final localHlc = Hlc(millis: localPhysical, counter: 0, nodeId: 'device-A');
      final remoteHlc = Hlc(millis: remotePhysical, counter: 5, nodeId: 'device-B');

      final mergedHlc = Hlc.receive(
        localHlc,
        remoteHlc,
        'device-A',
        physicalTimeMillis: localPhysical,
      );

      expect(mergedHlc.millis, remotePhysical);
      expect(mergedHlc.counter, 6);
      expect(mergedHlc.nodeId, 'device-A');
      expect(mergedHlc.isAfter(localHlc), isTrue);
      expect(mergedHlc.isAfter(remoteHlc), isTrue);
    });

    test('serialization and parsing are lossless', () {
      final original = Hlc(millis: 1772345678901, counter: 42, nodeId: 'client-xyz-123');
      final serialized = original.toJsonString();
      final parsed = Hlc.parse(serialized);

      expect(parsed.millis, original.millis);
      expect(parsed.counter, original.counter);
      expect(parsed.nodeId, original.nodeId);
      expect(parsed, equals(original));
    });

    test('total ordering across different nodeIds with same timestamp and counter', () {
      final hlcA = Hlc(millis: 1700000000000, counter: 0, nodeId: 'device-A');
      final hlcB = Hlc(millis: 1700000000000, counter: 0, nodeId: 'device-B');

      expect(hlcA.compareTo(hlcB), lessThan(0));
      expect(hlcB.compareTo(hlcA), greaterThan(0));
    });
  });
}
