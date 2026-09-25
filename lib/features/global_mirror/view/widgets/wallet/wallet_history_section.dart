import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';
import '../../../data/models/on_chain_transaction_model.dart';
import '../../../viewmodel/providers/wallet_provider.dart';

/// Human-readable label for a reward reason code such as `daily_mood_log`.
String formatRewardReason(String reason) {
  const labels = {
    'daily_mood_log': 'Daily log',
    'daily_log': 'Daily log',
    '7_day_streak_bonus': '7-day streak bonus',
    'seven_day_streak': '7-day streak bonus',
    'streak_bonus': 'Streak bonus',
    'gift_received': 'Gift received',
    'welcome_bonus': 'Welcome bonus',
  };

  if (labels.containsKey(reason)) return labels[reason]!;

  return reason
      .split(RegExp(r'[_-]'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatDate(DateTime date) =>
    date.toLocal().toIso8601String().split('T').first;

/// "Transaction History" heading plus the list of ECHO rewards.
class RewardHistorySection extends StatelessWidget {
  const RewardHistorySection({super.key, required this.history});

  final List<WalletReward> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transaction History', style: theme.textTheme.titleSmall),
        const SizedBox(height: 14),
        if (history.isEmpty)
          const _EmptyHistory(message: 'No transaction history yet.')
        else
          Column(
            children: history.map((reward) {
              final amountText =
                  '${reward.amount >= 0 ? '+' : '-'}'
                  '${reward.amount.toStringAsFixed(reward.amount.truncateToDouble() == reward.amount ? 0 : 2)} ECHO';
              return _HistoryTile(
                title: formatRewardReason(reward.reason),
                date: reward.createdAt,
                amountText: amountText,
                isPositive: reward.amount >= 0,
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// "On-Chain Activity" heading plus Horizon payment history.
class OnChainActivitySection extends StatelessWidget {
  const OnChainActivitySection({
    super.key,
    required this.transactions,
    required this.publicKey,
    required this.isLoading,
  });

  final List<OnChainTransactionModel> transactions;
  final String? publicKey;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('On-Chain Activity', style: theme.textTheme.titleSmall),
        const SizedBox(height: 14),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else if (transactions.isEmpty)
          const _EmptyHistory(message: 'No on-chain activity yet.')
        else
          Column(
            children: transactions.map((tx) {
              final isIncoming = tx.isIncoming(publicKey ?? '');
              return _HistoryTile(
                title: tx.typeLabel,
                date: tx.timestamp,
                amountText: '${isIncoming ? '+' : '-'}${tx.amount} ${tx.asset}',
                isPositive: isIncoming,
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.title,
    required this.date,
    required this.amountText,
    required this.isPositive,
  });

  final String title;
  final DateTime date;
  final String amountText;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(_formatDate(date)),
          trailing: Text(
            amountText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isPositive
                  ? AppTheme.successColor
                  : theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
