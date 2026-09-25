import 'package:flutter/material.dart';

/// Shown when the user has not created a Stellar wallet yet.
class WalletEmptyState extends StatelessWidget {
  const WalletEmptyState({super.key, required this.onCreateWallet});

  final VoidCallback onCreateWallet;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Wallet not set up yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Create your Stellar wallet to receive and send ECHO.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onCreateWallet,
            child: const Text('Create wallet'),
          ),
        ],
      ),
    );
  }
}
