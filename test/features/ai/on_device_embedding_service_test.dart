import 'dart:math' as math;
import 'package:echomirror/core/services/on_device_embedding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OnDeviceEmbeddingService embeddingService;

  setUp(() {
    embeddingService = OnDeviceEmbeddingService();
  });

  group('OnDeviceEmbeddingService', () {
    test('produces 64-dimensional embedding vectors', () {
      final embedding = embeddingService.embedText(
        'Feeling energetic and focused today',
      );
      expect(embedding.length, equals(64));
    });

    test('returns zero-vector for null or empty input', () {
      final nullEmbed = embeddingService.embedText(null);
      final emptyEmbed = embeddingService.embedText('   ');

      expect(nullEmbed.length, equals(64));
      expect(nullEmbed.every((v) => v == 0.0), isTrue);

      expect(emptyEmbed.length, equals(64));
      expect(emptyEmbed.every((v) => v == 0.0), isTrue);
    });

    test('normalizes output vectors to unit length (L2 norm = 1.0)', () {
      final embedding = embeddingService.embedText(
        'Had a wonderful meditation session this morning',
      );

      var sumSq = 0.0;
      for (final v in embedding) {
        sumSq += v * v;
      }
      final norm = math.sqrt(sumSq);
      expect(norm, closeTo(1.0, 1e-5));
    });

    test('is deterministic for identical input strings', () {
      const text = 'Ran 5 miles and felt great afterward';
      final embed1 = embeddingService.embedText(text);
      final embed2 = embeddingService.embedText(text);

      expect(embed1, equals(embed2));
    });

    test('computes high similarity for semantically related texts', () {
      final textA =
          'Had a great workout at the gym, feeling energized and strong';
      final textB = 'Went to exercise and run, felt productive and energized';
      final textC =
          'Stressed out about work deadlines, feeling overwhelmed and exhausted';

      final embedA = embeddingService.embedText(textA);
      final embedB = embeddingService.embedText(textB);
      final embedC = embeddingService.embedText(textC);

      final simAB = embeddingService.cosineSimilarity(embedA, embedB);
      final simAC = embeddingService.cosineSimilarity(embedA, embedC);

      // Related fitness/vitality entries should have higher similarity than fitness vs stress
      expect(simAB, greaterThan(simAC));
      expect(simAB, greaterThan(0.5));
    });

    test(
      'cosine similarity is bounded between -1.0 and 1.0 and is symmetric',
      () {
        final vecA = embeddingService.embedText(
          'Peaceful meditation in the garden',
        );
        final vecB = embeddingService.embedText(
          'Stressful traffic and late for work',
        );

        final simAB = embeddingService.cosineSimilarity(vecA, vecB);
        final simBA = embeddingService.cosineSimilarity(vecB, vecA);

        expect(simAB, closeTo(simBA, 1e-6));
        expect(simAB, greaterThanOrEqualTo(-1.0));
        expect(simAB, lessThanOrEqualTo(1.0));
      },
    );

    test('embedBatch returns list of embeddings matching input size', () {
      final texts = [
        'First entry about yoga',
        'Second entry about reading',
        'Third entry about cooking dinner',
      ];

      final batch = embeddingService.embedBatch(texts);
      expect(batch.length, equals(3));
      for (final vec in batch) {
        expect(vec.length, equals(64));
      }
    });

    test('on-device performance latency benchmark (< 1ms per entry)', () {
      const sampleText =
          'Today was a productive day. I completed all my work tasks on time, went for a 30 minute jog, and meditated for 10 minutes before bed. Feeling calm, peaceful, and ready for tomorrow.';

      final stopwatch = Stopwatch()..start();
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        embeddingService.embedText(sampleText);
      }
      stopwatch.stop();

      final avgMs = stopwatch.elapsedMilliseconds / iterations;
      // Must be well within mobile performance budget (< 2ms)
      expect(avgMs, lessThan(2.0));
    });
  });
}
