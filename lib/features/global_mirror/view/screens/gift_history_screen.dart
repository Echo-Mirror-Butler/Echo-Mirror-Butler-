import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';
import '../../data/models/gift_transaction_model.dart';
import '../../viewmodel/providers/gift_provider.dart';

/// Displays the full gift send/receive history for the current user.
class GiftHistoryScreen extends ConsumerStatefulWidget {
  const GiftHistoryScreen({super.key});

  @override
  ConsumerState<GiftHistoryScreen> createState() => _GiftHistoryScreenState();
}

class _GiftHistoryScreenState extends ConsumerState<GiftHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load history after the first frame so the provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(giftProvider.notifier).loadHistory();
    });
  }

  Future<void> _refresh() async {
    await ref.read(giftProvider.notifier).loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final giftState = ref.watch(giftProvider);
    // UserModel.id is a String; senderUserId is int — compare via toString().
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift History'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(theme, giftState, currentUserId),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    GiftState giftState,
    String? currentUserId,
  ) {
    // ── Loading ───────────────────────────────────────────────────────────────
    if (giftState.isLoading && giftState.history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── Error ─────────────────────────────────────────────────────────────────
    if (giftState.error != null && giftState.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                giftState.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Empty ─────────────────────────────────────────────────────────────────
    if (giftState.history.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: _EmptyHistoryPlaceholder(),
          ),
        ),
      );
    }

    // ── History list ──────────────────────────────────────────────────────────
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: giftState.history.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final tx = giftState.history[index];
          final senderStr = tx.senderUserId.toString();
          final isSent = currentUserId != null && senderStr == currentUserId;
          return _GiftTxCard(tx: tx, isSent: isSent);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHistoryPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ).createShader(bounds),
          child: const Icon(
            FontAwesomeIcons.gift,
            size: 72,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'No Gifts Yet',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gifts you send or receive\nwill appear here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual transaction card
// ─────────────────────────────────────────────────────────────────────────────

class _GiftTxCard extends StatelessWidget {
  const _GiftTxCard({required this.tx, required this.isSent});

  final GiftTransactionModel tx;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final directionColor =
        isSent ? theme.colorScheme.error : const Color(0xFF2E7D32);
    final directionIcon =
        isSent ? Icons.call_made_rounded : Icons.call_received_rounded;
    final isWhole = tx.echoAmount.truncateToDouble() == tx.echoAmount;
    final amountLabel =
        '${tx.echoAmount.toStringAsFixed(isWhole ? 0 : 2)} ECHO';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: direction icon + amount + status chip ───────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Direction badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: directionColor.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(directionIcon, color: directionColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Amount + direction label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSent ? 'Sent' : 'Received',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        amountLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: directionColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status chip
                _StatusChip(status: tx.status),
              ],
            ),

            // ── Message (if present) ─────────────────────────────────────────
            if (tx.message != null && tx.message!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tx.message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Bottom row: time + ledger link ───────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _relativeTime(tx.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (tx.stellarTxHash != null)
                  _LedgerLinkButton(hash: tx.stellarTxHash!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a human-readable relative time string.
  /// Examples: "just now", "5m ago", "2h ago", "3d ago", "12/02/2025".
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    // Older than a week — show a readable date.
    final mo = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$day/$mo/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.toLowerCase()) {
      'completed' => ('Completed', const Color(0xFF2E7D32)),
      'pending' => ('Pending', const Color(0xFFE65100)),
      'failed' => ('Failed', Colors.red),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "View on Ledger" button
// ─────────────────────────────────────────────────────────────────────────────

class _LedgerLinkButton extends StatelessWidget {
  const _LedgerLinkButton({required this.hash});

  final String hash;

  Future<void> _open() async {
    final uri = Uri.parse(
      'https://testnet.stellar.expert/explorer/testnet/tx/$hash',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.open_in_new_rounded,
            size: 13,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            'View on Ledger',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
