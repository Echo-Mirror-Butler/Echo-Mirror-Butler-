import 'package:flutter/material.dart';

import '../../../../../core/constants/environment_config.dart';
import '../../../viewmodel/providers/wallet_provider.dart';

/// Primary balance card shown for funded wallets.
///
/// Renders the live XLM balance next to the ECHO balance pulled from
/// Supabase / Horizon so testers can tell at a glance whether the network
/// has indexed their rewards.
class FundedBalanceCard extends StatelessWidget {
  const FundedBalanceCard({
    super.key,
    required this.walletState,
    required this.onSend,
    required this.onCopy,
  });

  final WalletState walletState;
  final VoidCallback onSend;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xlmText = '${walletState.xlmBalance.toStringAsFixed(2)} XLM';
    final echoText = '${walletState.balance.toStringAsFixed(0)} ECHO';
    final isLiveLoading = walletState.isLiveBalancesLoading;

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
              Text(
                'Wallet Balance',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isLiveLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Primary number: live XLM (because users need XLM to do anything
          // on Stellar). Echo balance shares the headline as secondary.
          Text(
            '$xlmText · $echoText',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _describeNetwork(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (walletState.hasStreakBonus) ...[
            const SizedBox(height: 12),
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
          const SizedBox(height: 20),
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
              Expanded(
                child: OutlinedButton(
                  onPressed: onCopy,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Copy address'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _describeNetwork() {
    if (EnvironmentConfig.isTestnet) {
      return 'Testnet • live Horizon balance, refreshes every 30s';
    }
    return 'Mainnet • live Horizon balance';
  }
}

/// Replaces the funded balance card when the account exists in Supabase
/// but has not been activated on the Stellar network yet.
///
/// On testnet it surfaces the Friendbot CTA prominently. On mainnet it
/// explains that the user must fund the account themselves.
class UnfundedActivationCard extends StatelessWidget {
  const UnfundedActivationCard({
    super.key,
    required this.walletState,
    required this.onFund,
  });

  final WalletState walletState;
  final VoidCallback onFund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFunding = walletState.isFunding;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Activation Required',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            EnvironmentConfig.isTestnet
                ? "Your wallet isn't activated yet. Tap below to fund it with "
                      'testnet XLM.'
                : 'Your wallet is not yet active on the Stellar network. '
                      'Send at least 1 XLM to the public key below to '
                      'activate it.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              walletState.publicKey ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (EnvironmentConfig.isTestnet)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Funding errors are surfaced via the ref.listen snackbar,
                // so we just trigger the request from here.
                onPressed: isFunding ? null : onFund,
                icon: isFunding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('🚰', style: TextStyle(fontSize: 16)),
                label: Text(isFunding ? 'Funding…' : 'Fund with Friendbot'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            // Mainnet has no programmatic funding; the user must send XLM
            // themselves. Hide the CTA entirely per the spec.
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
