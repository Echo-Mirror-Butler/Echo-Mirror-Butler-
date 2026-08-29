import 'dart:convert';
import 'dart:math' as math;
import '../../../../core/services/on_device_embedding_service.dart';
import '../../../../core/services/on_device_vector_index.dart';
import '../../../logging/data/models/log_entry_model.dart';
import '../models/privacy_insight_payload.dart';

/// Privacy-Preserving On-Device Insight Pipeline.
///
/// Orchestrates on-device embedding generation, vector indexing, similarity search,
/// and privacy-safe feature extraction before generating AI insights.
///
/// Zero decryptable plaintext note content ever leaves the client device.
class PrivacyInsightPipeline {
  PrivacyInsightPipeline({
    OnDeviceEmbeddingService? embeddingService,
    OnDeviceVectorIndex? vectorIndex,
  }) : _embeddingService = embeddingService ?? OnDeviceEmbeddingService(),
       _vectorIndex = vectorIndex ?? OnDeviceVectorIndex();

  final OnDeviceEmbeddingService _embeddingService;
  final OnDeviceVectorIndex _vectorIndex;

  OnDeviceEmbeddingService get embeddingService => _embeddingService;
  OnDeviceVectorIndex get vectorIndex => _vectorIndex;

  /// Processes logs on-device: embeds reflection notes locally and indexes them into vector store.
  void processAndIndexLogs(List<LogEntryModel> logs) {
    for (final log in logs) {
      final embedding = _embeddingService.embedText(log.notes);
      final entry = VectorIndexEntry(
        logId: log.id,
        date: log.date,
        mood: log.mood,
        habits: log.habits,
        embedding: embedding,
      );
      _vectorIndex.upsert(entry);
    }
  }

  /// Builds a sanitized, privacy-preserving insight payload from user logs.
  PrivacyPreservingInsightPayload buildPrivacyPayload(
    List<LogEntryModel> logs, {
    Map<String, int>? previousFollowThroughRate,
  }) {
    if (logs.isEmpty) {
      throw ArgumentError('Logs list cannot be empty');
    }

    // Ensure all logs are embedded and indexed locally
    processAndIndexLogs(logs);

    // Compute on-device clusters
    final clusters = _vectorIndex.computeClusters(similarityThreshold: 0.50);

    // Extract numerical trends
    final moodTrend = _calculateMoodTrends(logs);
    final habitFreqs = _calculateHabitFrequencies(logs);
    final habitMoodCorrs = _calculateHabitMoodCorrelations(logs);
    final temporal = _calculateTemporalPatterns(logs);
    final similarityHighlights = _extractSimilarityHighlights(logs);

    // Build sanitized log representations (NO plaintext notes included)
    final sanitizedLogs = logs.map((log) {
      final vectorEntry = _vectorIndex.get(log.id);
      return {
        'id': log.id,
        'date': log.date.toIso8601String(),
        'mood': log.mood,
        'habits': log.habits,
        'hasNotes': log.notes != null && log.notes!.trim().isNotEmpty,
        'noteEmbedding':
            vectorEntry?.embedding ?? _embeddingService.embedText(log.notes),
        'clusterId': vectorEntry?.clusterId,
      };
    }).toList();

    final payload = PrivacyPreservingInsightPayload(
      privacyMode: true,
      logCount: logs.length,
      moodTrend: moodTrend,
      habitFrequencies: habitFreqs,
      habitMoodCorrelations: habitMoodCorrs,
      temporalPatterns: temporal,
      sanitizedLogs: sanitizedLogs,
      clusters: clusters.map((c) => c.toJson()).toList(),
      similarityHighlights: similarityHighlights,
      previousFollowThroughRate: previousFollowThroughRate,
    );

    return payload;
  }

  /// Calculates statistical mood metrics and trend slope.
  Map<String, dynamic> _calculateMoodTrends(List<LogEntryModel> logs) {
    final moodLogs = logs.where((l) => l.mood != null).toList();
    if (moodLogs.isEmpty) {
      return {
        'average': 3.0,
        'min': 3,
        'max': 3,
        'slope': 0.0,
        'volatility': 0.0,
        'direction': 'stable',
      };
    }

    // Sort chronologically for slope computation
    final sorted = List<LogEntryModel>.from(moodLogs)
      ..sort((a, b) => a.date.compareTo(b.date));

    final moods = sorted.map((l) => l.mood!).toList();
    final avg = moods.reduce((a, b) => a + b) / moods.length;
    final minMood = moods.reduce(math.min);
    final maxMood = moods.reduce(math.max);

    // Variance / Volatility
    var variance = 0.0;
    for (final m in moods) {
      variance += (m - avg) * (m - avg);
    }
    final stdDev = math.sqrt(variance / moods.length);

    // Linear regression slope
    var slope = 0.0;
    final n = moods.length;
    if (n >= 2) {
      var sumX = 0.0;
      var sumY = 0.0;
      var sumXY = 0.0;
      var sumXX = 0.0;

      for (var i = 0; i < n; i++) {
        final x = i.toDouble();
        final y = moods[i].toDouble();
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumXX += x * x;
      }

      final denom = (n * sumXX - sumX * sumX);
      if (denom != 0.0) {
        slope = (n * sumXY - sumX * sumY) / denom;
      }
    }

    String direction = 'stable';
    if (slope > 0.15) {
      direction = 'improving';
    } else if (slope < -0.15) {
      direction = 'declining';
    }

    return {
      'average': double.parse(avg.toStringAsFixed(2)),
      'min': minMood,
      'max': maxMood,
      'slope': double.parse(slope.toStringAsFixed(3)),
      'volatility': double.parse(stdDev.toStringAsFixed(2)),
      'direction': direction,
    };
  }

  /// Calculates frequencies for all tracked habits.
  Map<String, int> _calculateHabitFrequencies(List<LogEntryModel> logs) {
    final counts = <String, int>{};
    for (final log in logs) {
      for (final habit in log.habits) {
        counts[habit] = (counts[habit] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Calculates average mood when each habit is performed.
  Map<String, double> _calculateHabitMoodCorrelations(
    List<LogEntryModel> logs,
  ) {
    final habitMoods = <String, List<int>>{};
    for (final log in logs) {
      if (log.mood != null) {
        for (final habit in log.habits) {
          habitMoods.putIfAbsent(habit, () => []).add(log.mood!);
        }
      }
    }

    final correlations = <String, double>{};
    habitMoods.forEach((habit, moods) {
      final avg = moods.reduce((a, b) => a + b) / moods.length;
      correlations[habit] = double.parse(avg.toStringAsFixed(2));
    });

    return correlations;
  }

  /// Extracts temporal patterns across days and time of day.
  Map<String, dynamic> _calculateTemporalPatterns(List<LogEntryModel> logs) {
    final weekdayMoods = <int, List<int>>{};
    for (final log in logs) {
      if (log.mood != null) {
        weekdayMoods.putIfAbsent(log.date.weekday, () => []).add(log.mood!);
      }
    }

    final weekdayAverages = <String, double>{};
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    weekdayMoods.forEach((dayNum, moods) {
      final avg = moods.reduce((a, b) => a + b) / moods.length;
      weekdayAverages[days[dayNum - 1]] = double.parse(avg.toStringAsFixed(2));
    });

    // Time-of-day distribution
    final timeSlots = <String, int>{
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0,
    };
    for (final log in logs) {
      final hour = log.date.hour;
      if (hour >= 5 && hour < 12) {
        timeSlots['Morning'] = timeSlots['Morning']! + 1;
      } else if (hour >= 12 && hour < 17) {
        timeSlots['Afternoon'] = timeSlots['Afternoon']! + 1;
      } else if (hour >= 17 && hour < 22) {
        timeSlots['Evening'] = timeSlots['Evening']! + 1;
      } else {
        timeSlots['Night'] = timeSlots['Night']! + 1;
      }
    }

    var bestTime = 'Morning';
    var worstTime = 'Night';
    var maxCount = -1;
    var minCount = 999999;

    timeSlots.forEach((slot, count) {
      if (count > maxCount) {
        maxCount = count;
        bestTime = slot;
      }
      if (count < minCount) {
        minCount = count;
        worstTime = slot;
      }
    });

    return {
      'bestTimeOfDay': bestTime,
      'worstTimeOfDay': worstTime,
      'weekdayAverages': weekdayAverages,
    };
  }

  /// Finds top semantic similarity links across entries locally on-device.
  List<Map<String, dynamic>> _extractSimilarityHighlights(
    List<LogEntryModel> logs,
  ) {
    final highlights = <Map<String, dynamic>>[];
    final entriesWithNotes = logs
        .where((l) => l.notes != null && l.notes!.trim().isNotEmpty)
        .toList();

    for (var i = 0; i < entriesWithNotes.length; i++) {
      final source = entriesWithNotes[i];
      final sourceVector = _vectorIndex.get(source.id)?.embedding;
      if (sourceVector == null) continue;

      final matches = _vectorIndex.findSimilar(
        sourceVector,
        topK: 2,
        minSimilarity: 0.60,
        excludeLogId: source.id,
      );

      for (final match in matches) {
        highlights.add({
          'sourceLogId': source.id,
          'sourceDate': source.date.toIso8601String().split('T')[0],
          'similarLogId': match.logId,
          'similarDate': match.date.toIso8601String().split('T')[0],
          'similarity': match.similarity,
          'moodDelta': (source.mood != null && match.mood != null)
              ? source.mood! - match.mood!
              : 0,
        });
      }
    }

    highlights.sort(
      (a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double),
    );
    return highlights.take(5).toList();
  }

  /// Verifies that no plaintext note tokens or sensitive reflection substrings appear in the payload.
  bool verifyZeroPlaintextLeakage(
    Map<String, dynamic> payload,
    List<LogEntryModel> originalLogs,
  ) {
    final jsonString = jsonEncode(payload).toLowerCase();

    for (final log in originalLogs) {
      final note = log.notes?.trim();
      if (note != null && note.length >= 6) {
        // Test distinct multi-word or long phrase fragments (ignoring trivial words)
        final words = note
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 4)
            .toList();
        for (var i = 0; i < words.length - 1; i++) {
          final phrase = '${words[i]} ${words[i + 1]}';
          if (jsonString.contains(phrase)) {
            return false; // Plaintext leak detected!
          }
        }
      }
    }

    return true;
  }
}
