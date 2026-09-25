import 'package:flutter/material.dart';

import '../../../viewmodel/providers/wallet_provider.dart';

/// Formats [lastUpdated] relative to now, e.g. `just now`, `42s ago`.
String formatWalletLastUpdated(DateTime lastUpdated, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(lastUpdated);
  if (diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

/// Gradient card with the ECHO and XLM balances (plus USD conversion), the
/// streak bonus pill, and either the send/copy actions or a Stellar error
/// with a Friendbot CTA.
class EchoBalanceCard extends StatelessWidget {
  const EchoBalanceCard({
    super.key,
    required this.walletState,
    required this.onSend,
    required this.onCopy,
    required this.onFund,
  });

  final WalletState walletState;
  final VoidCallback onSend;
  final VoidCallback onCopy;
  final VoidCallback onFund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ECHO Balance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (walletState.lastUpdated != null)
                Text(
                  formatWalletLastUpdated(walletState.lastUpdated!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BalanceColumn(
                  label: 'ECHO',
                  value: '${walletState.echoBalance.toStringAsFixed(1)} ECHO',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BalanceColumn(
                  label: 'XLM',
                  value: '${walletState.xlmBalance.toStringAsFixed(2)} XLM',
                  usdValue: walletState.xlmValueInUsd,
                ),
              ),
            ],
          ),
          if (walletState.hasStreakBonus) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Streak bonus active',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (walletState.stellarError != null)
            _StellarErrorSection(
              walletState: walletState,
              onFund: onFund,
              onCopy: onCopy,
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Send ECHO'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _CopyAddressButton(onPressed: onCopy)),
              ],
            ),
        ],
      ),
    );
  }
}

class _BalanceColumn extends StatelessWidget {
  const _BalanceColumn({required this.label, required this.value, this.usdValue});

  final String label;
  final String value;
  final double? usdValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (usdValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '≈ \$${usdValue!.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _CopyAddressButton extends StatelessWidget {
  const _CopyAddressButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Copy address'),
    );
  }
}

class _StellarErrorSection extends StatelessWidget {
  const _StellarErrorSection({
    required this.walletState,
    required this.onFund,
    required this.onCopy,
  });

  final WalletState walletState;
  final VoidCallback onFund;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final isUnfunded =
        walletState.xlmBalance == 0 && walletState.echoBalance == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnfunded ? Colors.amber.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isUnfunded
                ? 'Activate your wallet — send any XLM to fund it'
                : (walletState.stellarError ??
                      'Could not reach Stellar network'),
            style: TextStyle(
              fontSize: 13,
              color: isUnfunded ? Colors.brown : Colors.red.shade800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: walletState.isFunding ? null : onFund,
          icon: walletState.isFunding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_money, size: 18),
          label: Text(
            walletState.isFunding ? 'Funding...' : 'Fund with Friendbot',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: isUnfunded
                ? Colors.amber.shade700
                : Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _CopyAddressButton(onPressed: onCopy),
      ],
    );
  }
}
