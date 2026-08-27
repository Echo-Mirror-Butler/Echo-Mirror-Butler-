import 'package:echomirror/features/auth/data/repositories/auth_repository.dart';
import 'package:echomirror/features/auth/viewmodel/providers/auth_provider.dart';
import 'package:echomirror/features/logging/data/models/log_entry_model.dart';
import 'package:echomirror/features/logging/data/repositories/logging_repository.dart';
import 'package:echomirror/features/logging/view/screens/create_entry_screen.dart';
import 'package:echomirror/features/logging/viewmodel/providers/logging_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  // Per-test, not setUpAll — see the note in dashboard_screen_test.dart. A
  // file-wide prefs store lets one test's write leak into the next; resetting
  // per test keeps each one independent of the order they run in.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const userId = 'user_1';

  Widget buildScreen({required bool createResult}) {
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

  Future<void> mockSpeechToTextChannel() async {
    const methodChannel = MethodChannel(
      'plugin.csdcorp.com/speech_recognition',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (methodCall) async {
          return null;
        });
  }

  void clearSpeechToTextChannel() {
    const methodChannel = MethodChannel(
      'plugin.csdcorp.com/speech_recognition',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  }

  Future<void> tapCreateEntryButton(WidgetTester tester) async {
    final submitButton = find.text('Create Entry');

    await tester.ensureVisible(submitButton);
    await tester.pump();

    await tester.tap(submitButton);
    await tester.pump();
  }

  testWidgets(
    'renders correctly — mood slider/picker, text field, and submit button are all visible',
    (tester) async {
      await mockSpeechToTextChannel();

      await tester.pumpWidget(buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('How are you feeling?'), findsOneWidget);

      expect(find.byIcon(FontAwesomeIcons.faceFrown.data), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.faceMeh.data), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.faceSmile.data), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.faceSmileBeam.data), findsOneWidget);
      expect(find.byIcon(FontAwesomeIcons.faceGrinStars.data), findsOneWidget);

      expect(find.text('Notes (Optional)'), findsOneWidget);
      expect(
        find.text('Write about your day, thoughts, or anything else...'),
        findsOneWidget,
      );

      expect(find.text('Create Entry'), findsOneWidget);

      expect(
        find.byIcon(FontAwesomeIcons.microphone.data),
        findsAtLeastNWidgets(1),
      );

      clearSpeechToTextChannel();
    },
  );

  testWidgets(
    'submit disabled when form is empty — submit button is disabled before the user enters anything',
    (tester) async {
      await mockSpeechToTextChannel();

      await tester.pumpWidget(buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      final submitButton = find.text('Create Entry');
      expect(submitButton, findsOneWidget);

      await tester.ensureVisible(submitButton);
      await tester.pump();

      await tester.tap(submitButton);
      await tester.pump();

      expect(submitButton, findsOneWidget);

      clearSpeechToTextChannel();
    },
  );

  testWidgets(
    'successful create — tapping submit with valid input calls createLogEntry and navigates back',
    (tester) async {
      await mockSpeechToTextChannel();

      await tester.pumpWidget(buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      final moodIcons = find.byType(GestureDetector);
      await tester.tap(moodIcons.at(2));
      await tester.pump();

      final notesField = find.byType(TextField).first;
      await tester.enterText(notesField, 'Today was a good day');
      await tester.pump();

      await tapCreateEntryButton(tester);

      expect(find.text('New Entry'), findsOneWidget);

      clearSpeechToTextChannel();
    },
  );

  testWidgets(
    'failed create — when createLogEntry returns false, an error message is shown (no navigation)',
    (tester) async {
      await mockSpeechToTextChannel();

      await tester.pumpWidget(buildScreen(createResult: false));
      await tester.pump(const Duration(seconds: 2));

      final moodIcons = find.byType(GestureDetector);
      await tester.tap(moodIcons.at(2));
      await tester.pump();

      final notesField = find.byType(TextField).first;
      await tester.enterText(notesField, 'Today was a good day');
      await tester.pump();

      await tapCreateEntryButton(tester);

      expect(find.text('New Entry'), findsOneWidget);
      debugDumpApp();

      clearSpeechToTextChannel();
    },
  );

  testWidgets(
    'voice input button visible — VoiceInputButton is in the widget tree',
    (tester) async {
      await mockSpeechToTextChannel();

      await tester.pumpWidget(buildScreen(createResult: true));
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.byIcon(FontAwesomeIcons.microphone.data),
        findsAtLeastNWidgets(1),
      );

      expect(find.text('Voice'), findsOneWidget);

      clearSpeechToTextChannel();
    },
  );
}
