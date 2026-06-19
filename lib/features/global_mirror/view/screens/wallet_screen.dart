import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/wallet_provider.dart';

const _presetAmounts = [5, 10, 25, 50];

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  void _copyToClipboard(BuildContext context, String publicKey) {
    Clipboard.setData(ClipboardData(text: publicKey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Public key copied to clipboard'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isValidStellarKey(String key) {
    return key.length == 56 && key.startsWith('G');
  }

  Future<String> _resolveRecipientId(
    SupabaseClient supabase,
    String recipientInput,
  ) async {
    final trimmed = recipientInput.trim();
    if (trimmed.isEmpty) {
      throw Exception('Recipient address is required.');
    }

    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    if (uuidRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    if (_isValidStellarKey(trimmed)) {
      final wallet = await supabase
          .from('user_wallets')
          .select('user_id')
          .eq('public_key', trimmed)
          .maybeSingle();
      if (wallet != null && wallet['user_id'] != null) {
        return wallet['user_id'] as String;
      }
      throw Exception('Could not resolve recipient from Stellar address.');
    }

    if (trimmed.contains('@')) {
      final profileTables = ['profiles', 'user_profiles'];
      for (final table in profileTables) {
        final profile = await supabase
            .from(table)
            .select('id')
            .eq('email', trimmed)
            .maybeSingle();
        if (profile != null && profile['id'] != null) {
          return profile['id'] as String;
        }
      }

      final lookup = await supabase.rpc('lookup_user_by_email', params: {
        'email_input': trimmed,
      });

      if (lookup != null && lookup['user_id'] != null) {
        return lookup['user_id'] as String;
      }
      throw Exception('Could not resolve recipient from email.');
    }

    throw Exception('Use a valid recipient UUID, email address, or Stellar address.');
  }

  String _formatRewardReason(String reason) {
    const labels = {
      'daily_mood_log': 'Daily log',
      'daily_log': 'Daily log',
      '7_day_streak_bonus': '7-day streak bonus',
      'seven_day_streak': '7-day streak bonus',
      'streak_bonus': 'Streak bonus',
      'gift_received': 'Gift received',
      'welcome_bonus': 'Welcome bonus',
    };

    if (labels.containsKey(reason)) {
      return labels[reason]!;
    }

    return reason
        .split(RegExp(r'[_-]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  void _showSendEchoSheet(BuildContext context, WidgetRef ref) {
    final supabase = Supabase.instance.client;
    final recipientController = TextEditingController();
    final customAmountController = TextEditingController(text: _presetAmounts[1].toString());
    var selectedAmount = _presetAmounts[1];
    var isSending = false;
    String? errorMessage;

    Future<void> sendEcho() async {
      if (recipientController.text.trim().isEmpty) {
        throw Exception('Recipient is required.');
      }

      final amount = int.tryParse(customAmountController.text.trim()) ?? selectedAmount;
      if (amount <= 0) {
        throw Exception('Enter a valid ECHO amount.');
      }

      final recipientId = await _resolveRecipientId(supabase, recipientController.text);
      final response = await supabase.functions.invoke(
        'send-echo',
        body: {'recipient_id': recipientId, 'amount': amount},
      );

      // In Supabase v2, invoke() throws FunctionException on errors, no .error property.

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      await ref.read(walletProvider.notifier).loadWallet();
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ECHO sent successfully.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Send ECHO',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a recipient and the amount of ECHO to send.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: recipientController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Recipient',
                        hintText: 'User ID, email, or Stellar address',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _presetAmounts.map((amount) {
                        return ChoiceChip(
                          label: Text('$amount ECHO'),
                          selected: selectedAmount == amount,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() {
                              selectedAmount = amount;
                              customAmountController.text = amount.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: customAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        suffixText: 'ECHO',
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        if (parsed != null) {
                          setState(() => selectedAmount = parsed);
                        }
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              setState(() {
                                isSending = true;
                                errorMessage = null;
                              });
                              try {
                                await sendEcho();
                              } catch (e) {
                                setState(() {
                                  errorMessage = e.toString().replaceFirst('Exception: ', '');
                                });
                              }
                              setState(() {
                                isSending = false;
                              });
                            },
                      child: isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send ECHO'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isSending ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildShimmerCard(theme, height: 140),
        const SizedBox(height: 20),
        _buildShimmerCard(theme, height: 80),
        const SizedBox(height: 20),
        _buildShimmerCard(theme, height: 200),
      ],
    );
  }

  Widget _buildShimmerCard(ThemeData theme, {required double height}) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surface,
      highlightColor: theme.colorScheme.surfaceVariant,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final walletState = ref.watch(walletProvider);
    final walletNotifier = ref.read(walletProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        actions: [
          if (walletState.exists)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: walletNotifier.loadWallet,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: walletState.isLoading
            ? _buildLoading(theme)
            : walletState.error != null
                ? _ErrorState(
                    message: walletState.error!,
                    onRetry: walletNotifier.loadWallet,
                  )
                : !walletState.exists
                    ? _buildEmptyState(context, walletNotifier)
                    : _buildWalletContent(context, ref, theme, walletState, walletNotifier),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WalletNotifier walletNotifier) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 72, color: AppTheme.primaryColor),
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
            onPressed: walletNotifier.createWallet,
            child: const Text('Create wallet'),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    WalletState walletState,
    WalletNotifier walletNotifier,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ECHO Balance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${walletState.balance.toStringAsFixed(0)} ECHO',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _showSendEchoSheet(context, ref),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Send ECHO'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _copyToClipboard(context, walletState.publicKey!),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Copy address'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
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
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    walletState.publicKey ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Transaction History', style: theme.textTheme.titleSmall),
          const SizedBox(height: 14),
          if (walletState.history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'No transaction history yet.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            Column(
              children: walletState.history.map((reward) {
                final amountText = '${reward.amount >= 0 ? '+' : '-'}${reward.amount.toStringAsFixed(reward.amount.truncateToDouble() == reward.amount ? 0 : 2)} ECHO';
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_formatRewardReason(reward.reason)),
                      subtitle: Text(reward.createdAt.toLocal().toIso8601String().split('T').first),
                      trailing: Text(
                        amountText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: reward.amount >= 0 ? AppTheme.successColor : theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Text(
            'Latest transactions are pulled from your Supabase echo_rewards table.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _QrBottomSheet extends StatelessWidget {
  const _QrBottomSheet({required this.publicKey});

  final String publicKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Scan to Send ECHO',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan this QR code to get your Stellar public key',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: publicKey,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppTheme.primaryColor,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${publicKey.substring(0, 8)}...${publicKey.substring(publicKey.length - 8)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
