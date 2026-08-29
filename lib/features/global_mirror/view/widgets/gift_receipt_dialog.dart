import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/environment_config.dart';
import '../../../../core/themes/app_theme.dart';
import '../../data/models/gift_transaction_model.dart';

class GiftReceiptDialog extends StatelessWidget {
  const GiftReceiptDialog({
    super.key,
    required this.transaction,
    required this.recipientName,
  });

  final GiftTransactionModel transaction;
  final String recipientName;

  String _getBlockExplorerUrl() {
    if (transaction.stellarTxHash == null || transaction.stellarTxHash!.isEmpty) {
      return '';
    }
    final txHash = transaction.stellarTxHash!;
    if (EnvironmentConfig.isTestnet) {
      return 'https://stellar.expert/explorer/testnet/tx/$txHash';
    } else {
      return 'https://stellar.expert/explorer/public/tx/$txHash';
    }
  }

  Future<void> _openBlockExplorer(BuildContext context) async {
    final url = _getBlockExplorerUrl();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction hash not available')),
      );
      return;
    }
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open block explorer')),
      );
    }
  }

  void _copyTxHash(BuildContext context) {
    if (transaction.stellarTxHash == null || transaction.stellarTxHash!.isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: transaction.stellarTxHash!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Transaction hash copied'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _getBlockExplorerUrl();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Gift Sent Successfully!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReceiptRow(
                      theme,
                      'Recipient',
                      recipientName,
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      theme,
                      'Amount',
                      '${transaction.echoAmount.toStringAsFixed(1)} ECHO',
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      theme,
                      'Date',
                      _formatDate(transaction.createdAt),
                    ),
                    if (transaction.stellarTxHash != null &&
                        transaction.stellarTxHash!.isNotEmpty) ...[
                      const Divider(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Hash',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  transaction.stellarTxHash!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () => _copyTxHash(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (url.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openBlockExplorer(context),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View on Block Explorer'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour =
        local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}
