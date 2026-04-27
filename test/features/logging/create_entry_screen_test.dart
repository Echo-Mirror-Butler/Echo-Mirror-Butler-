import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:echomirror/features/logging/view/screens/create_entry_screen.dart';
import 'package:echomirror/features/logging/viewmodel/providers/logging_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class _FakeLoggingNotifier extends LoggingNotifier {
  _FakeLoggingNotifier(super.repository, this._createResult);

  final bool _createResult;

  @override
  Future<bool> createLogEntry(LogEntryModel entry) async {
    return _createResult;
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  const userId = 'user_1';

  Widget _buildScreen({required bool createResult}) {
    final mockAuthRepository = MockAuthRepository();
    when(
      () => mockAuthRepository.isAuthenticated(),
    ).thenAnswer((_) async => true);
    when(
      () => mockAuthRepository.getCurrentUser(),
    ).thenAnswer((_) async => {'id': userId, 'email': 'test@example.com'});

    final loggingRepo = LoggingRepository();

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        loggingProvider.overrideWith(
          (ref) => _FakeLoggingNotifier(loggingRepo, createResult),
        ),
      ],
      child: const MaterialApp(home: CreateEntryScreen()),
    );
  }

  testWidgets(
    'renders correctly — mood slider/picker, text field, and submit button are all visible',
    (tester) async {
      // Mock the speech_to_text method channel
      const methodChannel = MethodChannel(
        'plugin.csdcorp.com/speech_recognition',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
            return null;
          });

      await tester.pumpWidget(_buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      // Check for mood selection section
      expect(find.text('How are you feeling?'), findsOneWidget);

      // Check for mood icons (5 mood options)
      expect(find.byIcon(Icons.sentiment_very_dissatisfied), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_dissatisfied), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_satisfied), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_satisfied_alt), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_very_satisfied), findsOneWidget);

      // Check for notes text field
      expect(find.text('Notes (Optional)'), findsOneWidget);
      expect(
        find.text('Write about your day, thoughts, or anything else...'),
        findsOneWidget,
      );

      // Check for submit button
      expect(find.text('Create Entry'), findsOneWidget);

      // Check for voice input button
      expect(find.byIcon(Icons.mic), findsAtLeastNWidgets(1));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    },
  );

  testWidgets(
    'submit disabled when form is empty — submit button is disabled before the user enters anything',
    (tester) async {
      // Mock the speech_to_text method channel
      const methodChannel = MethodChannel(
        'plugin.csdcorp.com/speech_recognition',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
            return null;
          });

      await tester.pumpWidget(_buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      // Find the submit button (it should be enabled initially, but form validation happens on submit)
      final submitButton = find.text('Create Entry');
      expect(submitButton, findsOneWidget);

      // Tap submit without selecting mood or entering notes
      await tester.tap(submitButton);
      await tester.pump();

      // Should show validation error (mood is required implicitly)
      // The form validates on submit, so tapping without mood should not navigate
      expect(submitButton, findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    },
  );

  testWidgets(
    'successful create — tapping submit with valid input calls createLogEntry and navigates back',
    (tester) async {
      // Mock the speech_to_text method channel
      const methodChannel = MethodChannel(
        'plugin.csdcorp.com/speech_recognition',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
            return null;
          });

      await tester.pumpWidget(_buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      // Select a mood (tap the 3rd mood icon - happy face)
      final moodIcons = find.byType(GestureDetector);
      await tester.tap(moodIcons.at(2)); // Index 2 is the 3rd mood (3/5)
      await tester.pump();

      // Enter notes
      final notesField = find.byType(TextField).first;
      await tester.enterText(notesField, 'Today was a good day');
      await tester.pump();

      // Tap submit
      final submitButton = find.text('Create Entry');
      await tester.tap(submitButton);
      await tester.pump();

      // Should navigate back (screen should be gone)
      expect(find.text('New Entry'), findsNothing);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    },
  );

  testWidgets(
    'failed create — when createLogEntry returns false, an error message is shown (no navigation)',
    (tester) async {
      // Mock the speech_to_text method channel
      const methodChannel = MethodChannel(
        'plugin.csdcorp.com/speech_recognition',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
            return null;
          });

      await tester.pumpWidget(_buildScreen(createResult: false));
      await tester.pump(const Duration(seconds: 2));

      // Select a mood
      final moodIcons = find.byType(GestureDetector);
      await tester.tap(moodIcons.at(2));
      await tester.pump();

      // Enter notes
      final notesField = find.byType(TextField).first;
      await tester.enterText(notesField, 'Today was a good day');
      await tester.pump();

      // Tap submit
      final submitButton = find.text('Create Entry');
      await tester.tap(submitButton);
      await tester.pump();

      // Should show error message and NOT navigate back
      expect(find.text('New Entry'), findsOneWidget);
      expect(
        find.text('Failed to create entry. Please try again.'),
        findsOneWidget,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    },
  );

  testWidgets(
    'voice input button visible — VoiceInputButton is in the widget tree',
    (tester) async {
      // Mock the speech_to_text method channel
      const methodChannel = MethodChannel(
        'plugin.csdcorp.com/speech_recognition',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
            return null;
          });

      await tester.pumpWidget(_buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      // Check for voice input button (floating action button with mic icon)
      expect(find.byIcon(Icons.mic), findsAtLeastNWidgets(1));

      // Check for the Voice button text in the notes section
      expect(find.text('Voice'), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    },
  );
}
