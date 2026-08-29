import 'dart:math';

/// A Hybrid Logical Clock (HLC) that combines physical wall-clock time with
/// a logical counter and a client/node identifier.
///
/// HLC provides monotonic, causal timestamps across distributed devices
/// and servers, enabling principled conflict resolution without clock drift issues.
class Hlc implements Comparable<Hlc> {
  const Hlc({
    required this.millis,
    required this.counter,
    required this.nodeId,
  });

  /// Physical timestamp in milliseconds since Unix epoch (UTC).
  final int millis;

  /// Logical counter for events occurring within the same millisecond.
  final int counter;

  /// Unique client or device identifier.
  final String nodeId;

  /// Generates a new HLC for a local event on [nodeId].
  ///
  /// Advances physical time if current wall clock is ahead of [latestKnown],
  /// or increments the logical counter if wall clock is behind or equal.
  static Hlc now(String nodeId, {int? physicalTimeMillis, Hlc? latestKnown}) {
    final physical =
        physicalTimeMillis ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    if (latestKnown == null || physical > latestKnown.millis) {
      return Hlc(millis: physical, counter: 0, nodeId: nodeId);
    }

    return Hlc(
      millis: latestKnown.millis,
      counter: latestKnown.counter + 1,
      nodeId: nodeId,
    );
  }

  /// Updates local clock state upon receiving a remote HLC timestamp.
  ///
  /// Guarantees that the resulting clock will be strictly greater than both
  /// [local] and [remote].
  static Hlc receive(
    Hlc local,
    Hlc remote,
    String nodeId, {
    int? physicalTimeMillis,
  }) {
    final physical =
        physicalTimeMillis ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final maxMillis = max(physical, max(local.millis, remote.millis));

    int nextCounter;
    if (maxMillis == local.millis && maxMillis == remote.millis) {
      nextCounter = max(local.counter, remote.counter) + 1;
    } else if (maxMillis == local.millis) {
      nextCounter = local.counter + 1;
    } else if (maxMillis == remote.millis) {
      nextCounter = remote.counter + 1;
    } else {
      nextCounter = 0;
    }

    return Hlc(
      millis: maxMillis,
      counter: nextCounter,
      nodeId: nodeId,
    );
  }

  /// Formats this HLC as an ISO-8601 + counter + nodeId string, e.g.:
  /// `2026-08-29T05:20:00.000Z_0001_deviceA`
  String toJsonString() {
    final iso = DateTime.fromMillisecondsSinceEpoch(
      millis,
      isUtc: true,
    ).toIso8601String();
    final paddedCounter = counter.toString().padLeft(4, '0');
    return '${iso}_${paddedCounter}_$nodeId';
  }

  /// Parses an HLC string formatted by [toJsonString].
  static Hlc parse(String str) {
    if (str.contains('_')) {
      final first_ = str.indexOf('_');
      final second_ = str.indexOf('_', first_ + 1);
      if (first_ != -1 && second_ != -1) {
        final isoStr = str.substring(0, first_);
        final counterStr = str.substring(first_ + 1, second_);
        final nodeId = str.substring(second_ + 1);

        final counter = int.tryParse(counterStr);
        final date = DateTime.tryParse(isoStr);
        if (counter != null && date != null) {
          return Hlc(
            millis: date.millisecondsSinceEpoch,
            counter: counter,
            nodeId: nodeId,
          );
        }
      }
    }

    // Fallback: parse hyphenated format "${ISO}Z-${counter}-${nodeId}"
    final zDashIndex = str.indexOf('Z-');
    if (zDashIndex != -1) {
      final isoStr = str.substring(0, zDashIndex + 1);
      final rest = str.substring(zDashIndex + 2);
      final nextDash = rest.indexOf('-');
      if (nextDash != -1) {
        final counterStr = rest.substring(0, nextDash);
        final nodeId = rest.substring(nextDash + 1);
        final counter = int.tryParse(counterStr);
        final date = DateTime.tryParse(isoStr);
        if (counter != null && date != null) {
          return Hlc(
            millis: date.millisecondsSinceEpoch,
            counter: counter,
            nodeId: nodeId,
          );
        }
      }
    }

    throw FormatException('Invalid HLC string format: $str');
  }

  static Hlc? tryParse(String? str) {
    if (str == null || str.isEmpty) return null;
    try {
      return parse(str);
    } catch (_) {
      return null;
    }
  }

  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

  @override
  int compareTo(Hlc other) {
    if (millis != other.millis) {
      return millis.compareTo(other.millis);
    }
    if (counter != other.counter) {
      return counter.compareTo(other.counter);
    }
    return nodeId.compareTo(other.nodeId);
  }

  bool isAfter(Hlc other) => compareTo(other) > 0;
  bool isBefore(Hlc other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hlc &&
          runtimeType == other.runtimeType &&
          millis == other.millis &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(millis, counter, nodeId);

  @override
  String toString() => toJsonString();
}
