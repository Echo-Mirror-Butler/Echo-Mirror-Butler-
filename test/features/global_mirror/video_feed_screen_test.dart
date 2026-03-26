import 'package:echomirror/features/global_mirror/data/repositories/abstract_global_mirror_repository.dart';
import 'package:echomirror/features/global_mirror/view/screens/video_feed_screen.dart';
import 'package:echomirror/features/global_mirror/viewmodel/providers/global_mirror_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_global_mirror_repository.dart';

class _FakeGlobalMirrorNotifier extends GlobalMirrorNotifier {
  _FakeGlobalMirrorNotifier(this._initialState)
    : super(FakeGlobalMirrorRepository()) {
    state = _initialState;
  }

  final GlobalMirrorState _initialState;

  @override
  Future<void> loadVideoFeed({bool refresh = false}) async {}

  @override
  Future<void> loadMoreVideos() async {}
}

void main() {
  Widget buildScreen(GlobalMirrorState state) {
    return ProviderScope(
      overrides: [
        globalMirrorProvider.overrideWith(
          (ref) => _FakeGlobalMirrorNotifier(state),
        ),
      ],
      child: const MaterialApp(home: VideoFeedScreen()),
    );
  }

  testWidgets('shows shimmer placeholders while video feed is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        GlobalMirrorState(isLoadingVideoFeed: true, videoFeed: const []),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('video-feed-loading-state')), findsOneWidget);
    expect(find.byKey(const Key('video-feed-shimmer-indicator')), findsWidgets);
    expect(find.text('No Videos Yet'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('shows error state instead of shimmer when feed load fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        GlobalMirrorState(
          isLoadingVideoFeed: false,
          error: 'Network request failed',
          videoFeed: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-feed-error-state')), findsOneWidget);
    expect(find.text('Could not load videos'), findsOneWidget);
    expect(find.text('Network request failed'), findsOneWidget);
    expect(find.byKey(const Key('video-feed-loading-state')), findsNothing);
  });

  testWidgets('shows empty state when loading is finished and feed is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(GlobalMirrorState(videoFeed: const [])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-feed-empty-state')), findsOneWidget);
    expect(find.text('No Videos Yet'), findsOneWidget);
    expect(find.byKey(const Key('video-feed-loading-state')), findsNothing);
  });
}
