import 'package:echomirror/core/services/on_device_embedding_service.dart';
import 'package:echomirror/core/services/on_device_vector_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OnDeviceEmbeddingService embeddingService;
  late OnDeviceVectorIndex vectorIndex;

  setUp(() {
    embeddingService = OnDeviceEmbeddingService();
    vectorIndex = OnDeviceVectorIndex(embeddingService: embeddingService);
  });

  group('OnDeviceVectorIndex', () {
    test('upserts and retrieves vector entries correctly', () {
      final now = DateTime.utc(2026, 3, 20, 10, 0, 0);
      final embedding = embeddingService.embedText(
        'Morning meditation and tea',
      );
      final entry = VectorIndexEntry(
        logId: 'log-101',
        date: now,
        mood: 5,
        habits: ['meditate', 'hydrate'],
        embedding: embedding,
      );

      vectorIndex.upsert(entry);

      expect(vectorIndex.size, equals(1));
      final retrieved = vectorIndex.get('log-101');
      expect(retrieved, isNotNull);
      expect(retrieved!.logId, equals('log-101'));
      expect(retrieved.mood, equals(5));
      expect(retrieved.habits, contains('meditate'));
      expect(retrieved.embedding.length, equals(64));
    });

    test('findSimilar ranks entries by cosine similarity', () {
      final now = DateTime.utc(2026, 3, 20);
      final entry1 = VectorIndexEntry(
        logId: 'log-1',
        date: now,
        mood: 4,
        habits: ['exercise', 'run'],
        embedding: embeddingService.embedText(
          'Intense cardio run and workout at gym',
        ),
      );
      final entry2 = VectorIndexEntry(
        logId: 'log-2',
        date: now.add(const Duration(days: 1)),
        mood: 5,
        habits: ['exercise', 'stretch'],
        embedding: embeddingService.embedText(
          'Jogging in the park and fitness training',
        ),
      );
      final entry3 = VectorIndexEntry(
        logId: 'log-3',
        date: now.add(const Duration(days: 2)),
        mood: 2,
        habits: [],
        embedding: embeddingService.embedText(
          'Exhausted from late work meeting and deadline stress',
        ),
      );

      vectorIndex.upsertAll([entry1, entry2, entry3]);

      final query = embeddingService.embedText(
        'Cardio workout and running outside',
      );
      final matches = vectorIndex.findSimilar(query, topK: 2);

      expect(matches.length, equals(2));
      // Top matches should be fitness-related
      expect(matches.first.logId, isIn(['log-1', 'log-2']));
      expect(matches.first.similarity, greaterThan(matches.last.similarity));
    });

    test('findSimilar respects excludeLogId and minSimilarity', () {
      final now = DateTime.utc(2026, 3, 20);
      final entry1 = VectorIndexEntry(
        logId: 'log-1',
        date: now,
        embedding: embeddingService.embedText(
          'Mindful breathing exercise in morning',
        ),
      );
      final entry2 = VectorIndexEntry(
        logId: 'log-2',
        date: now,
        embedding: embeddingService.embedText(
          'Mindful breathing and peaceful meditation',
        ),
      );

      vectorIndex.upsertAll([entry1, entry2]);

      final query = embeddingService.embedText('Mindful breathing session');
      final matches = vectorIndex.findSimilar(
        query,
        excludeLogId: 'log-1',
        minSimilarity: 0.2,
      );

      expect(matches.length, equals(1));
      expect(matches.first.logId, equals('log-2'));
    });

    test('computeClusters groups semantically similar entries', () {
      final now = DateTime.utc(2026, 3, 20);
      // Group A: Fitness entries
      final f1 = VectorIndexEntry(
        logId: 'f-1',
        date: now,
        mood: 5,
        habits: ['exercise'],
        embedding: embeddingService.embedText('Morning run and gym workout'),
      );
      final f2 = VectorIndexEntry(
        logId: 'f-2',
        date: now.add(const Duration(days: 1)),
        mood: 4,
        habits: ['exercise', 'hydrate'],
        embedding: embeddingService.embedText(
          'Fitness workout at gym with weights',
        ),
      );

      // Group B: Stress entries
      final s1 = VectorIndexEntry(
        logId: 's-1',
        date: now.add(const Duration(days: 2)),
        mood: 2,
        habits: [],
        embedding: embeddingService.embedText(
          'Overwhelmed with heavy work deadline pressure',
        ),
      );
      final s2 = VectorIndexEntry(
        logId: 's-2',
        date: now.add(const Duration(days: 3)),
        mood: 1,
        habits: [],
        embedding: embeddingService.embedText(
          'Stressed and anxious about office projects',
        ),
      );

      vectorIndex.upsertAll([f1, f2, s1, s2]);

      final clusters = vectorIndex.computeClusters(similarityThreshold: 0.50);

      expect(clusters.isNotEmpty, isTrue);
      // Ensure cluster summaries contain valid metrics
      for (final cluster in clusters) {
        expect(cluster.entryCount, greaterThan(0));
        expect(cluster.averageMood, inInclusiveRange(1.0, 5.0));
      }
    });

    test('computeCentroid calculates average vector for entry IDs', () {
      final now = DateTime.utc(2026, 3, 20);
      final entry1 = VectorIndexEntry(
        logId: 'log-1',
        date: now,
        embedding: embeddingService.embedText('Great day'),
      );
      final entry2 = VectorIndexEntry(
        logId: 'log-2',
        date: now,
        embedding: embeddingService.embedText('Awesome day'),
      );

      vectorIndex.upsertAll([entry1, entry2]);

      final centroid = vectorIndex.computeCentroid(['log-1', 'log-2']);
      expect(centroid.length, equals(64));
      // Centroid of non-zero unit vectors should be normalized
      var sumSq = 0.0;
      for (final v in centroid) {
        sumSq += v * v;
      }
      expect(sumSq, closeTo(1.0, 1e-4));
    });

    test('exportJson and importJson roundtrips correctly', () {
      final now = DateTime.utc(2026, 3, 20, 15, 30, 0);
      final entry = VectorIndexEntry(
        logId: 'log-persist-1',
        date: now,
        mood: 4,
        habits: ['read', 'meditate'],
        embedding: embeddingService.embedText('Reading a book on mindfulness'),
      );

      vectorIndex.upsert(entry);

      final jsonStr = vectorIndex.exportJson();
      expect(jsonStr.isNotEmpty, isTrue);

      final newIndex = OnDeviceVectorIndex(embeddingService: embeddingService);
      newIndex.importJson(jsonStr);

      expect(newIndex.size, equals(1));
      final loaded = newIndex.get('log-persist-1');
      expect(loaded, isNotNull);
      expect(loaded!.mood, equals(4));
      expect(loaded.habits, equals(['read', 'meditate']));
      expect(loaded.embedding, equals(entry.embedding));
    });
  });
}
