import 'package:echomirror/features/dashboard/view/widgets/mood_streak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows streak value and motivational text for active streak', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodStreakCard(streak: 5))),
    );

    expect(find.text('\u{1F525} 5-day streak'), findsOneWidget);
    expect(find.text('Keep it up!'), findsOneWidget);
  });

  testWidgets('shows start prompt when streak is zero', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodStreakCard(streak: 0))),
    );

    expect(find.text('\u{1F525} 0-day streak'), findsOneWidget);
    expect(find.text('Start your streak today!'), findsOneWidget);
  });
}
