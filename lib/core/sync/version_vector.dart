import 'dart:math';

/// A Version Vector tracking logical clocks/versions across multiple devices/nodes.
///
/// Enables causal history tracking and concurrency detection.
class VersionVector {
  VersionVector([Map<String, int>? versions])
      : _versions = Map<String, int>.unmodifiable(versions ?? const {});

  final Map<String, int> _versions;

  Map<String, int> get versions => _versions;

  /// Returns the version number for [nodeId], or 0 if unseen.
  int getVersion(String nodeId) => _versions[nodeId] ?? 0;

  /// Returns a new [VersionVector] with [nodeId]'s clock incremented by [amount].
  VersionVector increment(String nodeId, [int amount = 1]) {
    final next = Map<String, int>.from(_versions);
    next[nodeId] = (next[nodeId] ?? 0) + amount;
    return VersionVector(next);
  }

  /// Sets [nodeId]'s version to [version].
  VersionVector setVersion(String nodeId, int version) {
    final next = Map<String, int>.from(_versions);
    next[nodeId] = version;
    return VersionVector(next);
  }

  /// Merges this version vector with [other], taking the pairwise maximum
  /// version for every known nodeId.
  VersionVector merge(VersionVector other) {
    final merged = Map<String, int>.from(_versions);
    for (final entry in other._versions.entries) {
      merged[entry.key] = max(merged[entry.key] ?? 0, entry.value);
    }
    return VersionVector(merged);
  }

  /// True if this vector is strictly newer than [other] (dominates it):
  /// every entry in this >= other, and at least one entry > other.
  bool dominates(VersionVector other) {
    bool strictlyGreater = false;
    final allKeys = {..._versions.keys, ...other._versions.keys};
    for (final key in allKeys) {
      final v1 = getVersion(key);
      final v2 = other.getVersion(key);
      if (v1 < v2) return false;
      if (v1 > v2) strictlyGreater = true;
    }
    return strictlyGreater;
  }

  /// True if this vector is identical to [other].
  bool isIdentical(VersionVector other) {
    final allKeys = {..._versions.keys, ...other._versions.keys};
    for (final key in allKeys) {
      if (getVersion(key) != other.getVersion(key)) return false;
    }
    return true;
  }

  /// True if neither vector dominates the other and they are not identical.
  bool isConcurrentWith(VersionVector other) {
    return !dominates(other) && !other.dominates(this) && !isIdentical(other);
  }

  Map<String, int> toMap() => Map<String, int>.from(_versions);

  factory VersionVector.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null || map.isEmpty) return VersionVector();
    final parsed = <String, int>{};
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final val = (entry.value as num?)?.toInt() ?? 0;
      parsed[key] = val;
    }
    return VersionVector(parsed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VersionVector && isIdentical(other);

  @override
  int get hashCode => Object.hashAll(_versions.entries);

  @override
  String toString() => _versions.toString();
}
