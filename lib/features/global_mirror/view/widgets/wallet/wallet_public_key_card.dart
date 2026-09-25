import 'package:flutter/material.dart';

/// Card displaying the wallet's Stellar public key with copy and QR actions.
class WalletPublicKeyCard extends StatelessWidget {
  const WalletPublicKeyCard({
    super.key,
    required this.publicKey,
    required this.onCopy,
    required this.onShowQr,
  });

  final String? publicKey;
  final VoidCallback onCopy;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 22),
              const SizedBox(width: 12),
              Text('Stellar Public Key', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              publicKey ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Key'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onShowQr,
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text('Show QR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
