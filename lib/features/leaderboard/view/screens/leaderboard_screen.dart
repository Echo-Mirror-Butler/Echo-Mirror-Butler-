import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodel/providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(leaderboardProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Leaderboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load leaderboard',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(leaderboardProvider.notifier).load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildBody(state, currentUserId),
    );
  }

  Widget _buildBody(LeaderboardState state, String? currentUserId) {
    final theme = Theme.of(context);
    final entries = state.entries;

    if (entries.isEmpty) {
      return const Center(
        child: Text('No entries this week. Start logging your mood!'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(leaderboardProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length +
            (state.currentUserEntry != null ? 2 : 0),
        itemBuilder: (context, index) {
          if (index == entries.length) {
            return const Divider(height: 32);
          }
          if (index == entries.length + 1) {
            final u = state.currentUserEntry!;
            return _buildTile(u, u.rank, true);
          }
          final entry = entries[index];
          final isMe = entry.id == currentUserId;
          return _buildTile(entry, entry.rank, isMe);
        },
      ),
    );
  }

  Widget _buildTile(
      LeaderboardEntryModel entry, int rank, bool isCurrentUser) {
    final theme = Theme.of(context);
    String medal = '';
    if (rank == 1) medal = '\u{1F947}';
    if (rank == 2) medal = '\u{1F948}';
    if (rank == 3) medal = '\u{1F949}';

    return Card(
      color: isCurrentUser
          ? theme.colorScheme.primaryContainer
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: medal.isNotEmpty
              ? Text(medal)
              : Text('#$rank'),
        ),
        title: Text(
          entry.displayText,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${entry.echoEarnedThisWeek} ECHO earned'),
        trailing: isCurrentUser
            ? const Chip(label: Text('You', style: TextStyle(fontSize: 12)))
            : null,
      ),
    );
  }
}
