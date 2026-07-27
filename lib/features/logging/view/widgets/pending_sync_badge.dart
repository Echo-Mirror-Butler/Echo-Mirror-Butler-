import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/mood_sync_service.dart';

/// App bar badge showing how many mood logs are queued locally, waiting to
/// be synced. Hidden entirely when the queue is empty.
class PendingSyncBadge extends ConsumerWidget {
  const PendingSyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingMoodLogCountProvider).value ?? 0;
    if (pendingCount <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message:
            '$pendingCount ${pendingCount == 1 ? 'entry' : 'entries'} '
            'waiting to sync',
        child: Badge.count(
          count: pendingCount,
          child: const Icon(Icons.cloud_upload_outlined),
        ),
      ),
    );
  }
}
