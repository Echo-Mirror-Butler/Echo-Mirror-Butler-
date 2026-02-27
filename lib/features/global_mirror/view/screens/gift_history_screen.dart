import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/themes/app_theme.dart';
import '../../data/models/gift_transaction_model.dart';
import '../../viewmodel/providers/gift_provider.dart';
import '../../../auth/viewmodel/providers/auth_provider.dart';

/// Screen displaying the user's gift transaction history.
class GiftHistoryScreen extends ConsumerStatefulWidget {
  const GiftHistoryScreen({super.key});

  @override
  ConsumerState<GiftHistoryScreen> createState() => _GiftHistoryScreenState();
}

class _GiftHistoryScreenState extends ConsumerState<GiftHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(giftProvider.notifier).loadHistory();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(giftProvider.notifier).loadHistory();
  }

  Future<void> _openStellarLink(String txHash) async {
    // Stellar Expert testnet URL format
    final url = Uri.parse(
      'https://testnet.stellar.expert/transaction/$txHash',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '${weeks}w ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return FontAwesomeIcons.checkCircle;
      case 'pending':
        return FontAwesomeIcons.hourglass;
      case 'failed':
        return FontAwesomeIcons.xmarkCircle;
      default:
        return FontAwesomeIcons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final giftState = ref.watch(giftProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift History'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primaryColor,
        child: _buildHistoryContent(
          theme,
          giftState,
          currentUserId,
        ),
      ),
    );
  }

  Widget _buildHistoryContent(
    ThemeData theme,
    GiftState giftState,
    int? currentUserId,
  ) {
    // Show empty state if no history
    if (giftState.history.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.gift,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No gift history yet',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start gifting ECHO tokens to your friends!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Build list of transactions
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: giftState.history.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final tx = giftState.history[index];
        final isSent = tx.senderUserId == currentUserId;

        return _buildTransactionTile(
          theme,
          tx,
          isSent,
        );
      },
    );
  }

  Widget _buildTransactionTile(
    ThemeData theme,
    GiftTransactionModel tx,
    bool isSent,
  ) {
    final statusColor = _getStatusColor(tx.status);
    final statusIcon = _getStatusIcon(tx.status);
    final timeAgo = _getTimeAgo(tx.createdAt);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: direction, amount, and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Direction and amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSent
                                ? FontAwesomeIcons.arrowUp
                                : FontAwesomeIcons.arrowDown,
                            size: 18,
                            color: isSent ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSent ? 'Sent' : 'Received',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${isSent ? '−' : '+'}${tx.echoAmount.toStringAsFixed(1)} ECHO',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: isSent ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Chip(
                  avatar: Icon(
                    statusIcon,
                    size: 16,
                    color: statusColor,
                  ),
                  label: Text(
                    tx.status.substring(0, 1).toUpperCase() +
                        tx.status.substring(1),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: statusColor.withOpacity(0.1),
                  side: BorderSide(color: statusColor, width: 1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Message (if available)
            if (tx.message != null && tx.message!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tx.message!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            // Timestamp and Stellar link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (tx.stellarTxHash != null)
                  GestureDetector(
                    onTap: () => _openStellarLink(tx.stellarTxHash!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FontAwesomeIcons.link,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View on Stellar',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
