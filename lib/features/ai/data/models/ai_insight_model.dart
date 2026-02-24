/// Model representing AI-generated insights
class AiInsightModel {
  final String prediction;
  final List<String> suggestions;
  final String futureLetter;
  final DateTime generatedAt;
  final int? stressLevel; // 0-5, where 0=no stress, 5=high stress
  final String? calmingMessage; // Personalized calming message from future self
  final List<String>?
  musicRecommendations; // Music recommendations with vibe descriptions

  const AiInsightModel({
    required this.prediction,
    required this.suggestions,
    required this.futureLetter,
    required this.generatedAt,
    this.stressLevel,
    this.calmingMessage,
    this.musicRecommendations,
  });

  /// Create AiInsightModel from JSON
  factory AiInsightModel.fromJson(Map<String, dynamic> json) {
    return AiInsightModel(
      prediction: json['prediction'] as String? ?? '',
      suggestions:
          (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      futureLetter: json['futureLetter'] as String? ?? '',
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
      stressLevel: json['stressLevel'] as int?,
      calmingMessage: json['calmingMessage'] as String?,
      musicRecommendations: (json['musicRecommendations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  /// Convert AiInsightModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'prediction': prediction,
      'suggestions': suggestions,
      'futureLetter': futureLetter,
      'generatedAt': generatedAt.toIso8601String(),
      'stressLevel': stressLevel,
      'calmingMessage': calmingMessage,
      'musicRecommendations': musicRecommendations,
    };
  }

  /// Create a copy with updated fields
  AiInsightModel copyWith({
    String? prediction,
    List<String>? suggestions,
    String? futureLetter,
    DateTime? generatedAt,
    int? stressLevel,
    String? calmingMessage,
    List<String>? musicRecommendations,
  }) {
    return AiInsightModel(
      prediction: prediction ?? this.prediction,
      suggestions: suggestions ?? this.suggestions,
      futureLetter: futureLetter ?? this.futureLetter,
      generatedAt: generatedAt ?? this.generatedAt,
      stressLevel: stressLevel ?? this.stressLevel,
      calmingMessage: calmingMessage ?? this.calmingMessage,
      musicRecommendations: musicRecommendations ?? this.musicRecommendations,
    );
  }
}
