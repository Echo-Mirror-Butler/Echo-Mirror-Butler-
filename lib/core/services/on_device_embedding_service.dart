import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// On-device, privacy-preserving sentence embedding service.
///
/// Converts reflection and note text into compact normalized dense embedding vectors (64-d)
/// on the local device without sending raw text across the network.
///
/// Designed to operate within mobile performance, memory, and battery budgets:
/// - Sub-millisecond latency per note (< 1ms)
/// - Self-contained zero-network-dependency architecture
/// - Normalized L2-norm vectors for fast cosine similarity via dot product
class OnDeviceEmbeddingService {
  /// Dimension of the generated embedding vectors.
  static const int embeddingDimension = 64;

  /// Common English stopwords to filter out for semantic focus.
  static const Set<String> _stopwords = {
    'a',
    'about',
    'above',
    'after',
    'again',
    'against',
    'all',
    'am',
    'an',
    'and',
    'any',
    'are',
    'aren\'t',
    'as',
    'at',
    'be',
    'because',
    'been',
    'before',
    'being',
    'below',
    'between',
    'both',
    'but',
    'by',
    'can',
    'can\'t',
    'cannot',
    'could',
    'couldn\'t',
    'did',
    'didn\'t',
    'do',
    'does',
    'doesn\'t',
    'doing',
    'don\'t',
    'down',
    'during',
    'each',
    'few',
    'for',
    'from',
    'further',
    'had',
    'hadn\'t',
    'has',
    'hasn\'t',
    'have',
    'haven\'t',
    'having',
    'he',
    'he\'d',
    'he\'ll',
    'he\'s',
    'her',
    'here',
    'here\'s',
    'hers',
    'herself',
    'him',
    'himself',
    'his',
    'how',
    'how\'s',
    'i',
    'i\'d',
    'i\'ll',
    'i\'m',
    'i\'ve',
    'if',
    'in',
    'into',
    'is',
    'isn\'t',
    'it',
    'it\'s',
    'its',
    'itself',
    'let\'s',
    'me',
    'more',
    'most',
    'mustn\'t',
    'my',
    'myself',
    'no',
    'nor',
    'not',
    'of',
    'off',
    'on',
    'once',
    'only',
    'or',
    'other',
    'ought',
    'our',
    'ours',
    'ourselves',
    'out',
    'over',
    'own',
    'same',
    'shan\'t',
    'she',
    'she\'d',
    'she\'ll',
    'she\'s',
    'should',
    'shouldn\'t',
    'so',
    'some',
    'such',
    'than',
    'that',
    'that\'s',
    'the',
    'their',
    'theirs',
    'them',
    'themselves',
    'then',
    'there',
    'there\'s',
    'these',
    'they',
    'they\'d',
    'they\'ll',
    'they\'re',
    'they\'ve',
    'this',
    'those',
    'through',
    'to',
    'too',
    'under',
    'until',
    'up',
    'very',
    'was',
    'wasn\'t',
    'we',
    'we\'d',
    'we\'ll',
    'we\'re',
    'we\'ve',
    'were',
    'weren\'t',
    'what',
    'what\'s',
    'when',
    'when\'s',
    'where',
    'where\'s',
    'which',
    'while',
    'who',
    'who\'s',
    'whom',
    'why',
    'why\'s',
    'with',
    'won\'t',
    'would',
    'wouldn\'t',
    'you',
    'you\'d',
    'you\'ll',
    'you\'re',
    'you\'ve',
    'your',
    'yours',
    'yourself',
    'yourselves',
  };

  /// Semantic domain anchors mapped to specific embedding subspaces.
  /// Used for projection weighting across key psychological and behavioral dimensions.
  static final Map<String, List<String>> _semanticThemes = {
    'vitality_positivity': [
      'great',
      'good',
      'happy',
      'energized',
      'excited',
      'joy',
      'motivated',
      'confident',
      'inspired',
      'wonderful',
      'amazing',
      'productive',
      'thriving',
      'strong',
      'progress',
      'accomplished',
      'proud',
      'grateful',
      'optimistic',
    ],
    'calm_mindfulness': [
      'peaceful',
      'calm',
      'relaxed',
      'mindful',
      'meditate',
      'breathe',
      'zen',
      'serene',
      'tranquil',
      'centered',
      'grounded',
      'still',
      'reflective',
      'clarity',
      'quiet',
      'balanced',
      'content',
      'soothing',
      'composed',
    ],
    'stress_anxiety': [
      'stressed',
      'anxious',
      'worried',
      'nervous',
      'overwhelmed',
      'pressure',
      'panic',
      'tense',
      'frustrated',
      'exhausted',
      'burnout',
      'drained',
      'tired',
      'difficult',
      'struggling',
      'chaotic',
      'restless',
      'uneasy',
    ],
    'health_habits': [
      'exercise',
      'workout',
      'gym',
      'walk',
      'run',
      'cardio',
      'sleep',
      'rest',
      'diet',
      'nutrition',
      'water',
      'hydration',
      'steps',
      'stretch',
      'yoga',
      'healthy',
      'routine',
      'active',
      'training',
      'fuel',
    ],
    'focus_work': [
      'focus',
      'work',
      'code',
      'project',
      'deadline',
      'meeting',
      'study',
      'deep',
      'tasks',
      'build',
      'ship',
      'solve',
      'learning',
      'career',
      'goals',
      'deliverable',
      'writing',
      'research',
      'plan',
    ],
    'connection_social': [
      'family',
      'friend',
      'friends',
      'team',
      'love',
      'connected',
      'talk',
      'conversation',
      'dinner',
      'partner',
      'community',
      'support',
      'shared',
      'together',
      'helped',
      'social',
      'bonding',
      'relationship',
    ],
  };

  /// Generate a 64-dimensional dense normalized embedding vector for the provided text.
  /// Returns a zero-vector if text is empty or null.
  List<double> embedText(String? text) {
    if (text == null || text.trim().isEmpty) {
      return List<double>.filled(embeddingDimension, 0.0);
    }

    final tokens = _tokenize(text);
    if (tokens.isEmpty) {
      return List<double>.filled(embeddingDimension, 0.0);
    }

    final vector = List<double>.filled(embeddingDimension, 0.0);

    // 1. Subword & N-gram Hashing Projections (Distributed representation)
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final tokenWeight = 1.0 / (1.0 + 0.05 * i); // slight positional decay

      // Primary token hash projection
      final h1 = _fnv1aHash(token);
      final idx1 = (h1.abs()) % embeddingDimension;
      final sign1 = (h1 % 2 == 0) ? 1.0 : -1.0;
      vector[idx1] += sign1 * tokenWeight * 1.2;

      // Character trigram hashes for morphological robustness
      if (token.length >= 3) {
        for (var j = 0; j <= token.length - 3; j++) {
          final trigram = token.substring(j, j + 3);
          final hTri = _fnv1aHash(trigram);
          final idxTri = (hTri.abs()) % embeddingDimension;
          final signTri = (hTri % 2 == 0) ? 0.6 : -0.6;
          vector[idxTri] += signTri * tokenWeight * 0.4;
        }
      }

      // Word bigram hash with previous token
      if (i > 0) {
        final bigram = '${tokens[i - 1]}_$token';
        final hBi = _fnv1aHash(bigram);
        final idxBi = (hBi.abs()) % embeddingDimension;
        final signBi = (hBi % 2 == 0) ? 0.8 : -0.8;
        vector[idxBi] += signBi * tokenWeight * 0.7;
      }
    }

    // 2. Semantic Theme Projections (Domain-guided subspace alignment)
    var themeIndex = 0;
    _semanticThemes.forEach((themeName, keywords) {
      final baseSlot = (themeIndex * 10) % embeddingDimension;
      var themeMatchCount = 0.0;

      for (final token in tokens) {
        for (final keyword in keywords) {
          if (token == keyword ||
              token.startsWith(keyword) ||
              keyword.startsWith(token)) {
            themeMatchCount += 1.0;
          }
        }
      }

      if (themeMatchCount > 0) {
        final themeScore = math.log(1.0 + themeMatchCount);
        for (var offset = 0; offset < 4; offset++) {
          final slot = (baseSlot + offset) % embeddingDimension;
          vector[slot] += themeScore * (offset % 2 == 0 ? 1.5 : -1.1);
        }
      }
      themeIndex++;
    });

    // 3. L2 Normalization (Unit vector length = 1.0)
    return _normalize(vector);
  }

  /// Batch embedding of multiple text strings.
  List<List<double>> embedBatch(List<String?> texts) {
    return texts.map(embedText).toList();
  }

  /// Computes cosine similarity between two unit embedding vectors in [-1.0, 1.0].
  /// Dot product of normalized vectors equals cosine similarity.
  double cosineSimilarity(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length || vecA.isEmpty) return 0.0;

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < vecA.length; i++) {
      dot += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    final denom = math.sqrt(normA) * math.sqrt(normB);
    final sim = dot / denom;
    return sim.clamp(-1.0, 1.0);
  }

  /// Tokenizes raw text into clean, filtered lowercase words.
  List<String> _tokenize(String text) {
    final clean = text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.isEmpty) return [];

    return clean
        .split(' ')
        .where((t) => t.length > 1 && !_stopwords.contains(t))
        .toList();
  }

  /// 32-bit FNV-1a non-cryptographic hash for fast, uniform token dispersion.
  int _fnv1aHash(String text) {
    var hash = 0x811c9dc5;
    final bytes = utf8.encode(text);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Normalizes vector to unit length (L2 norm).
  List<double> _normalize(List<double> vec) {
    var sumSq = 0.0;
    for (final v in vec) {
      sumSq += v * v;
    }

    if (sumSq == 0.0) return vec;

    final norm = math.sqrt(sumSq);
    return vec.map((v) => v / norm).toList();
  }
}
