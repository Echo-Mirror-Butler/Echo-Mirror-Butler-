/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:echomirror_server_server/src/generated/protocol.dart' as _i2;

abstract class AiInsight
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  AiInsight._({
    required this.prediction,
    required this.suggestions,
    required this.futureLetter,
    required this.generatedAt,
    this.stressLevel,
    this.calmingMessage,
    this.musicRecommendations,
  });

  factory AiInsight({
    required String prediction,
    required List<String> suggestions,
    required String futureLetter,
    required DateTime generatedAt,
    int? stressLevel,
    String? calmingMessage,
    List<String>? musicRecommendations,
  }) = _AiInsightImpl;

  factory AiInsight.fromJson(Map<String, dynamic> jsonSerialization) {
    return AiInsight(
      prediction: jsonSerialization['prediction'] as String,
      suggestions: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['suggestions'],
      ),
      futureLetter: jsonSerialization['futureLetter'] as String,
      generatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['generatedAt'],
      ),
      stressLevel: jsonSerialization['stressLevel'] as int?,
      calmingMessage: jsonSerialization['calmingMessage'] as String?,
      musicRecommendations: jsonSerialization['musicRecommendations'] == null
          ? null
          : _i2.Protocol().deserialize<List<String>>(
              jsonSerialization['musicRecommendations'],
            ),
    );
  }

  /// The prediction text about future outcomes
  String prediction;

  /// List of actionable habit suggestions
  List<String> suggestions;

  /// A motivational letter from "future me"
  String futureLetter;

  /// When this insight was generated
  DateTime generatedAt;

  /// Stress level detected (0-5, where 0=no stress, 5=high stress)
  /// Based on patterns like excessive working without rest/sleep
  int? stressLevel;

  /// Personalized calming message from future self for stress detection
  String? calmingMessage;

  /// Music recommendations with vibe descriptions
  List<String>? musicRecommendations;

  /// Returns a shallow copy of this [AiInsight]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AiInsight copyWith({
    String? prediction,
    List<String>? suggestions,
    String? futureLetter,
    DateTime? generatedAt,
    int? stressLevel,
    String? calmingMessage,
    List<String>? musicRecommendations,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AiInsight',
      'prediction': prediction,
      'suggestions': suggestions.toJson(),
      'futureLetter': futureLetter,
      'generatedAt': generatedAt.toJson(),
      if (stressLevel != null) 'stressLevel': stressLevel,
      if (calmingMessage != null) 'calmingMessage': calmingMessage,
      if (musicRecommendations != null)
        'musicRecommendations': musicRecommendations?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AiInsight',
      'prediction': prediction,
      'suggestions': suggestions.toJson(),
      'futureLetter': futureLetter,
      'generatedAt': generatedAt.toJson(),
      if (stressLevel != null) 'stressLevel': stressLevel,
      if (calmingMessage != null) 'calmingMessage': calmingMessage,
      if (musicRecommendations != null)
        'musicRecommendations': musicRecommendations?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AiInsightImpl extends AiInsight {
  _AiInsightImpl({
    required String prediction,
    required List<String> suggestions,
    required String futureLetter,
    required DateTime generatedAt,
    int? stressLevel,
    String? calmingMessage,
    List<String>? musicRecommendations,
  }) : super._(
         prediction: prediction,
         suggestions: suggestions,
         futureLetter: futureLetter,
         generatedAt: generatedAt,
         stressLevel: stressLevel,
         calmingMessage: calmingMessage,
         musicRecommendations: musicRecommendations,
       );

  /// Returns a shallow copy of this [AiInsight]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AiInsight copyWith({
    String? prediction,
    List<String>? suggestions,
    String? futureLetter,
    DateTime? generatedAt,
    Object? stressLevel = _Undefined,
    Object? calmingMessage = _Undefined,
    Object? musicRecommendations = _Undefined,
  }) {
    return AiInsight(
      prediction: prediction ?? this.prediction,
      suggestions: suggestions ?? this.suggestions.map((e0) => e0).toList(),
      futureLetter: futureLetter ?? this.futureLetter,
      generatedAt: generatedAt ?? this.generatedAt,
      stressLevel: stressLevel is int? ? stressLevel : this.stressLevel,
      calmingMessage: calmingMessage is String?
          ? calmingMessage
          : this.calmingMessage,
      musicRecommendations: musicRecommendations is List<String>?
          ? musicRecommendations
          : this.musicRecommendations?.map((e0) => e0).toList(),
    );
  }
}
