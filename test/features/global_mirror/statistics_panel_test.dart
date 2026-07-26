import 'package:flutter_test/flutter_test.dart';
import 'package:echomirror/features/global_mirror/view/widgets/statistics_panel.dart';
import 'package:echomirror/features/global_mirror/data/models/mood_pin_model.dart';
import 'package:flutter/material.dart';

void main() {
  group('StatisticsPanel region classification', () {
    testWidgets('northern canada should NOT resolve to Northern Europe', (
      tester,
    ) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: 62,
          gridLon: -110,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Northern Europe'), findsNothing);
      expect(find.text('Northern America / Greenland'), findsOneWidget);
    });

    testWidgets('russia should NOT resolve to Northern Europe', (tester) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: 62,
          gridLon: 95,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Northern Europe'), findsNothing);
      expect(find.text('Northern Asia'), findsOneWidget);
    });

    testWidgets('london resolves to Europe', (tester) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: 51.5,
          gridLon: -0.1,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Europe'), findsOneWidget);
    });

    testWidgets('tokyo resolves to East Asia', (tester) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: 35.7,
          gridLon: 139.7,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('East Asia'), findsOneWidget);
    });

    testWidgets('sydney resolves to Australia / Oceania', (tester) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: -33.9,
          gridLon: 151.2,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Australia / Oceania'), findsOneWidget);
    });

    testWidgets('sao paulo resolves to Southern Tropical South America', (
      tester,
    ) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: -20,
          gridLon: -46.6,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Southern Tropical South America'), findsOneWidget);
    });

    testWidgets('southern africa resolves correctly', (tester) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: -26,
          gridLon: 28,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Southern Africa'), findsOneWidget);
    });

    testWidgets('new york resolves to Eastern North America', (tester) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: 40.7,
          gridLon: -74,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Eastern North America'), findsOneWidget);
    });

    testWidgets('cape town resolves to Southern Africa', (tester) async {
      final pins = [
        MoodPinModel(
          id: '1',
          sentiment: 'happy',
          gridLat: -34,
          gridLon: 18,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: pins, isMobile: true),
          ),
        ),
      );

      expect(find.text('Southern Africa'), findsOneWidget);
    });

    testWidgets('empty pins shows no activity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsPanel(pins: const [], isMobile: true),
          ),
        ),
      );

      expect(find.text('No activity'), findsOneWidget);
    });
  });
}
