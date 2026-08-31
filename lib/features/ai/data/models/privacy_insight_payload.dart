/// Privacy-preserving payload model for insight generation.
///
/// Encapsulates numerical metrics, habit trends, embedding vectors, and semantic clusters
/// while strictly excluding all plaintext reflection content.
class PrivacyPreservingInsightPayload {
  final bool privacyMode;
  final int logCount;
  final Map<String, dynamic> moodTrend;
  final Map<String, int> habitFrequencies;
  final Map<String, double> habitMoodCorrelations;
  final Map<String, dynamic> temporalPatterns;
  final List<Map<String, dynamic>> sanitizedLogs;
  final List<Map<String, dynamic>> clusters;
  final List<Map<String, dynamic>> similarityHighlights;
  final Map<String, int>? previousFollowThroughRate;

  PrivacyPreservingInsightPayload({
    this.privacyMode = true,
    required this.logCount,
    required this.moodTrend,
    required this.habitFrequencies,
    required this.habitMoodCorrelations,
    required this.temporalPatterns,
    required this.sanitizedLogs,
    required this.clusters,
    required this.similarityHighlights,
    this.previousFollowThroughRate,
  });

  Map<String, dynamic> toJson() => {
    'privacyMode': privacyMode,
    'logCount': logCount,
    'moodTrend': moodTrend,
    'habitFrequencies': habitFrequencies,
    'habitMoodCorrelations': habitMoodCorrelations,
    'temporalPatterns': temporalPatterns,
    'sanitizedLogs': sanitizedLogs,
    'clusters': clusters,
    'similarityHighlights': similarityHighlights,
    if (previousFollowThroughRate != null)
      'previousFollowThroughRate': previousFollowThroughRate,
  };

  factory PrivacyPreservingInsightPayload.fromJson(Map<String, dynamic> json) {
    return PrivacyPreservingInsightPayload(
      privacyMode: json['privacyMode'] as bool? ?? true,
      logCount: json['logCount'] as int? ?? 0,
      moodTrend: Map<String, dynamic>.from(json['moodTrend'] as Map? ?? {}),
      habitFrequencies: Map<String, int>.from(
        json['habitFrequencies'] as Map? ?? {},
      ),
      habitMoodCorrelations: (json['habitMoodCorrelations'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
      temporalPatterns: Map<String, dynamic>.from(
        json['temporalPatterns'] as Map? ?? {},
      ),
      sanitizedLogs: List<Map<String, dynamic>>.from(
        (json['sanitizedLogs'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
      clusters: List<Map<String, dynamic>>.from(
        (json['clusters'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
      similarityHighlights: List<Map<String, dynamic>>.from(
        (json['similarityHighlights'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
      previousFollowThroughRate: json['previousFollowThroughRate'] != null
          ? Map<String, int>.from(json['previousFollowThroughRate'] as Map)
          : null,
    );
  }
}
