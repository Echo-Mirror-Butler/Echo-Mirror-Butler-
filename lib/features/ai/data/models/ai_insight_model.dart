/// Model representing AI-generated insights
class AiInsightModel {
  final String prediction;
  final List<String> suggestions;
  final String futureLetter;
  final DateTime generatedAt;
  final int? stressLevel; // 0-5, where 0=no stress, 5=high stress

  const AiInsightModel({
    required this.prediction,
    required this.suggestions,
    required this.futureLetter,
    required this.generatedAt,
    this.stressLevel,
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
    };
  }

  /// Create a copy with updated fields
  AiInsightModel copyWith({
    String? prediction,
    List<String>? suggestions,
    String? futureLetter,
    DateTime? generatedAt,
    int? stressLevel,
  }) {
    return AiInsightModel(
      prediction: prediction ?? this.prediction,
      suggestions: suggestions ?? this.suggestions,
      futureLetter: futureLetter ?? this.futureLetter,
      generatedAt: generatedAt ?? this.generatedAt,
      stressLevel: stressLevel ?? this.stressLevel,
    );
  }
}
