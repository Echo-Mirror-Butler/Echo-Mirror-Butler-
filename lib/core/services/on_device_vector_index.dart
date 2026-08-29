import 'dart:convert';
import 'dart:math' as math;
import 'on_device_embedding_service.dart';

/// Single vector index record containing embedding and non-sensitive metadata.
class VectorIndexEntry {
  final String logId;
  final DateTime date;
  final int? mood;
  final List<String> habits;
  final List<double> embedding;
  int? clusterId;

  VectorIndexEntry({
    required this.logId,
    required this.date,
    this.mood,
    this.habits = const [],
    required this.embedding,
    this.clusterId,
  });

  Map<String, dynamic> toJson() => {
    'logId': logId,
    'date': date.toIso8601String(),
    'mood': mood,
    'habits': habits,
    'embedding': embedding,
    if (clusterId != null) 'clusterId': clusterId,
  };

  factory VectorIndexEntry.fromJson(Map<String, dynamic> json) {
    return VectorIndexEntry(
      logId: json['logId'] as String,
      date: DateTime.parse(json['date'] as String),
      mood: json['mood'] as int?,
      habits: List<String>.from(json['habits'] as List? ?? []),
      embedding: (json['embedding'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      clusterId: json['clusterId'] as int?,
    );
  }
}

/// Similarity search match result.
class VectorSimilarityMatch {
  final String logId;
  final DateTime date;
  final int? mood;
  final List<String> habits;
  final double similarity;

  VectorSimilarityMatch({
    required this.logId,
    required this.date,
    this.mood,
    this.habits = const [],
    required this.similarity,
  });

  Map<String, dynamic> toJson() => {
    'logId': logId,
    'date': date.toIso8601String(),
    'mood': mood,
    'habits': habits,
    'similarity': double.parse(similarity.toStringAsFixed(4)),
  };
}

/// Semantic cluster summary derived purely from embeddings on-device.
class VectorClusterSummary {
  final int clusterId;
  final int entryCount;
  final double averageMood;
  final List<String> topHabits;
  final List<String> entryIds;

  VectorClusterSummary({
    required this.clusterId,
    required this.entryCount,
    required this.averageMood,
    required this.topHabits,
    required this.entryIds,
  });

  Map<String, dynamic> toJson() => {
    'clusterId': clusterId,
    'entryCount': entryCount,
    'averageMood': double.parse(averageMood.toStringAsFixed(2)),
    'topHabits': topHabits,
    'entryIds': entryIds,
  };
}

/// On-device vector store and similarity index for personal reflection entries.
///
/// Maintains per-user historical embeddings locally, enabling pattern detection,
/// recurrence tracking, and semantic clustering without server-side plaintext access.
class OnDeviceVectorIndex {
  OnDeviceVectorIndex({OnDeviceEmbeddingService? embeddingService})
    : _embeddingService = embeddingService ?? OnDeviceEmbeddingService();

  final OnDeviceEmbeddingService _embeddingService;
  final Map<String, VectorIndexEntry> _entries = {};

  int get size => _entries.length;
  List<VectorIndexEntry> get allEntries => _entries.values.toList();

  /// Adds or updates an entry in the index.
  void upsert(VectorIndexEntry entry) {
    _entries[entry.logId] = entry;
  }

  /// Batch upsert of vector entries.
  void upsertAll(Iterable<VectorIndexEntry> entries) {
    for (final entry in entries) {
      _entries[entry.logId] = entry;
    }
  }

  /// Retrieves an entry by ID.
  VectorIndexEntry? get(String logId) => _entries[logId];

  /// Removes an entry by ID.
  bool remove(String logId) => _entries.remove(logId) != null;

  /// Clears the entire index.
  void clear() => _entries.clear();

  /// Computes top-K similar entries to a query embedding.
  List<VectorSimilarityMatch> findSimilar(
    List<double> queryEmbedding, {
    int topK = 5,
    double minSimilarity = 0.0,
    String? excludeLogId,
  }) {
    if (_entries.isEmpty || queryEmbedding.isEmpty) return [];

    final matches = <VectorSimilarityMatch>[];

    for (final entry in _entries.values) {
      if (excludeLogId != null && entry.logId == excludeLogId) continue;

      final sim = _embeddingService.cosineSimilarity(
        queryEmbedding,
        entry.embedding,
      );
      if (sim >= minSimilarity) {
        matches.add(
          VectorSimilarityMatch(
            logId: entry.logId,
            date: entry.date,
            mood: entry.mood,
            habits: entry.habits,
            similarity: sim,
          ),
        );
      }
    }

    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches.take(topK).toList();
  }

  /// Calculates semantic clusters of historical entries using hierarchical nearest-neighbor grouping.
  List<VectorClusterSummary> computeClusters({
    double similarityThreshold = 0.55,
  }) {
    if (_entries.isEmpty) return [];

    final unassigned = _entries.keys.toList();
    final clusters = <List<VectorIndexEntry>>[];

    while (unassigned.isNotEmpty) {
      final seedId = unassigned.removeAt(0);
      final seedEntry = _entries[seedId]!;
      final cluster = <VectorIndexEntry>[seedEntry];

      final toRemove = <String>[];
      for (final candidateId in unassigned) {
        final candidate = _entries[candidateId]!;
        final sim = _embeddingService.cosineSimilarity(
          seedEntry.embedding,
          candidate.embedding,
        );

        if (sim >= similarityThreshold) {
          cluster.add(candidate);
          toRemove.add(candidateId);
        }
      }

      for (final id in toRemove) {
        unassigned.remove(id);
      }

      clusters.add(cluster);
    }

    // Build summaries for each cluster
    final summaries = <VectorClusterSummary>[];
    for (var i = 0; i < clusters.length; i++) {
      final group = clusters[i];
      final moods = group.map((e) => e.mood).whereType<int>().toList();
      final avgMood = moods.isEmpty
          ? 3.0
          : moods.reduce((a, b) => a + b) / moods.length;

      final habitCounts = <String, int>{};
      for (final entry in group) {
        for (final habit in entry.habits) {
          habitCounts[habit] = (habitCounts[habit] ?? 0) + 1;
        }
      }

      final sortedHabits = habitCounts.keys.toList()
        ..sort((a, b) => (habitCounts[b] ?? 0).compareTo(habitCounts[a] ?? 0));

      for (final entry in group) {
        entry.clusterId = i + 1;
      }

      summaries.add(
        VectorClusterSummary(
          clusterId: i + 1,
          entryCount: group.length,
          averageMood: avgMood,
          topHabits: sortedHabits.take(3).toList(),
          entryIds: group.map((e) => e.logId).toList(),
        ),
      );
    }

    return summaries;
  }

  /// Computes the arithmetic centroid vector for a given list of entry IDs.
  List<double> computeCentroid(List<String> entryIds) {
    if (entryIds.isEmpty) {
      return List<double>.filled(
        OnDeviceEmbeddingService.embeddingDimension,
        0.0,
      );
    }

    final validVectors = entryIds
        .map((id) => _entries[id]?.embedding)
        .whereType<List<double>>()
        .toList();

    if (validVectors.isEmpty) {
      return List<double>.filled(
        OnDeviceEmbeddingService.embeddingDimension,
        0.0,
      );
    }

    final dim = validVectors.first.length;
    final centroid = List<double>.filled(dim, 0.0);

    for (final vec in validVectors) {
      for (var i = 0; i < dim; i++) {
        centroid[i] += vec[i];
      }
    }

    var sumSq = 0.0;
    for (var i = 0; i < dim; i++) {
      centroid[i] /= validVectors.length;
      sumSq += centroid[i] * centroid[i];
    }

    if (sumSq == 0.0) return centroid;
    final norm = math.sqrt(sumSq);
    return centroid.map((v) => v / norm).toList();
  }

  /// Serializes the entire index to JSON string for local disk storage.
  String exportJson() {
    final list = _entries.values.map((e) => e.toJson()).toList();
    return jsonEncode(list);
  }

  /// Restores vector index from JSON string.
  void importJson(String jsonStr) {
    _entries.clear();
    final decoded = jsonDecode(jsonStr) as List;
    for (final item in decoded) {
      final entry = VectorIndexEntry.fromJson(item as Map<String, dynamic>);
      _entries[entry.logId] = entry;
    }
  }
}
