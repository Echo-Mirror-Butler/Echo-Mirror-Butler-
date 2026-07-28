import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/environment_config.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../viewmodel/providers/wallet_provider.dart';

const _testnetDismissKey = 'testnet_banner_dismissed';

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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showQrModal(BuildContext context, String publicKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrBottomSheet(publicKey: publicKey),
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

    if (uuidRegex.hasMatch(trimmed)) return trimmed;

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

      final lookup = await supabase.rpc('lookup_user_by_email', {
        'email_input': trimmed,
      });
      if (lookup != null && lookup['user_id'] != null) {
        return lookup['user_id'] as String;
      }
      throw Exception('Could not resolve recipient from email.');
    }

    throw Exception(
      'Use a valid recipient UUID, email address, or Stellar address.',
    );
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

    if (labels.containsKey(reason)) return labels[reason]!;

    return reason
        .split(RegExp(r'[_-]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  void _showSendEchoSheet(BuildContext context, WidgetRef ref) {
    final supabase = Supabase.instance.client;
    final recipientController = TextEditingController();
    final customAmountController =
        TextEditingController(text: _presetAmounts[1].toString());
    var selectedAmount = _presetAmounts[1];
    var isSending = false;
    String? errorMessage;
    String? recipientError;
    String? recipientSuccess;
    bool isResolvingRecipient = false;
    bool hasValidRecipient = false;
    String? amountError;
    Timer? _debounce;

    Future<void> sendEcho() async {
      if (recipientController.text.trim().isEmpty) {
        throw Exception('Recipient is required.');
      }
      final amount = double.tryParse(customAmountController.text.trim()) ?? selectedAmount.toDouble();
      if (amount <= 0) throw Exception('Enter a valid ECHO amount.');

      final recipientId =
          await _resolveRecipientId(supabase, recipientController.text);
      final response = await supabase.functions.invoke(
        'send-echo',
        body: {'recipient_id': recipientId, 'amount': amount},
      );
      if (response.error != null) throw response.error!;
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      await ref.read(walletProvider.notifier).loadWallet();
      if (context.mounted) {
        Navigator.pop(context);
        ToastService.success(context, 'ECHO sent successfully.');
      }
    }

    void validateRecipient(String value) {
      _debounce?.cancel();
      if (value.trim().isEmpty) {
        setState(() {
          isResolvingRecipient = false;
          recipientError = null;
          recipientSuccess = null;
          hasValidRecipient = false;
        });
        return;
      }
      setState(() {
        isResolvingRecipient = true;
        recipientError = null;
        recipientSuccess = null;
        hasValidRecipient = false;
      });
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        try {
          final resolvedId = await _resolveRecipientId(supabase, value);
          setState(() {
            isResolvingRecipient = false;
            recipientSuccess = 'Sending to: $resolvedId';
            recipientError = null;
            hasValidRecipient = true;
          });
        } catch (e) {
          setState(() {
            isResolvingRecipient = false;
            recipientError = 'Recipient not found';
            recipientSuccess = null;
            hasValidRecipient = false;
          });
        }
      });
    }

    void validateAmount(String value) {
      if (value.trim().isEmpty) {
        setState(() => amountError = null);
        return;
      }
      final parsed = double.tryParse(value.trim());
      if (parsed == null) {
        setState(() => amountError = 'Enter a valid number');
      } else if (parsed <= 0) {
        setState(() => amountError = 'Amount must be greater than 0');
      } else if (parsed > (ref.read(walletProvider).balance)) {
        setState(() => amountError = 'Insufficient ECHO balance');
      } else {
        setState(() {
          amountError = null;
          selectedAmount = parsed.roundToDouble();
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canSend = hasValidRecipient && amountError == null && !isSending;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TestnetBanner(),
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Send ECHO',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                      decoration: InputDecoration(
                        labelText: 'Recipient',
                        hintText: 'User ID, email, or Stellar address',
                        suffixIcon: isResolvingRecipient
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : recipientSuccess != null
                                ? const Icon(Icons.check_circle, color: AppTheme.successColor)
                                : recipientError != null
                                    ? const Icon(Icons.error, color: AppTheme.errorColor)
                                    : null,
                      ),
                      onChanged: (value) => validateRecipient(value),
                    ),
                    if (recipientSuccess != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          recipientSuccess!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ),
                    if (recipientError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          recipientError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
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
                              customAmountController.text =
                                  amount.toString();
                              amountError = null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: customAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        suffixText: 'ECHO',
                        errorText: amountError,
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value.trim());
                        if (parsed != null) {
                          setState(() => selectedAmount = parsed);
                        }
                        validateAmount(value);
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: canSend
                          ? () async {
                              setState(() {
                                isSending = true;
                                errorMessage = null;
                              });
                              try {
                                await sendEcho();
                              } catch (e) {
                                setState(() {
                                  errorMessage = friendlyErrorMessage(e);
                                });
                              }
                              setState(() => isSending = false);
                            }
                          : null,
                      child: isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Send ECHO'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed:
                          isSending ? null : () => Navigator.pop(context),
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
      highlightColor: theme.colorScheme.surfaceContainerHighest,
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

    // Surface friendbot result toasts. The provider stores the message;
    // the listener pops a snackbar then clears the field so it does not
    // replay when the widget rebuilds.
    ref.listen<WalletState>(walletProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final errorChanged = previous?.fundingError != next.fundingError;
      final justFunded =
          previous == null
              ? false
              : !previous.funded && next.funded;
      if (errorChanged && next.fundingError != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(_fundingErrorSnack(next.fundingError!));
      } else if (justFunded) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(_fundingSuccessSnack());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        actions: [
          if (walletState.exists)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () async {
                await walletNotifier.loadWallet();
                await walletNotifier.refreshLiveBalances();
              },
            ),
        ],
      ),
      body: walletState.isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : walletState.error != null
              ? _ErrorState(
                  message: walletState.error!,
                  onRetry: walletNotifier.loadWallet,
                )
              : !walletState.exists
                  ? _buildEmptyState(context, walletNotifier)
                  : RefreshIndicator(
                      onRefresh: () => walletNotifier.loadWallet(),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildWalletContent(
                          context,
                          theme,
                          walletState,
                          walletNotifier,
                          ref,
                        ),
                      ),
                    ),
    );
  }

  SnackBar _fundingSuccessSnack() {
    return SnackBar(
      content: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '10,000 XLM added! Your wallet is now active.',
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.successColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    );
  }

  SnackBar _fundingErrorSnack(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: AppTheme.errorColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WalletNotifier walletNotifier,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 72,
            color: AppTheme.primaryColor,
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
            onPressed: walletNotifier.createWallet,
            child: const Text('Create wallet'),
          ),
        ],
      ),
    );
  }

  Widget _buildStellarError(
    ThemeData theme,
    WalletState walletState,
    WalletNotifier walletNotifier,
  ) {
    final isUnfunded = walletState.xlmBalance == 0 && walletState.echoBalance == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnfunded
                ? Colors.amber.shade100
                : Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isUnfunded
                ? 'Activate your wallet — send any XLM to fund it'
                : (walletState.stellarError ?? 'Could not reach Stellar network'),
            style: TextStyle(
              fontSize: 13,
              color: isUnfunded ? Colors.brown : Colors.red.shade800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: walletState.isFunding
              ? null
              : () => walletNotifier.fundWithFriendbot(),
          icon: walletState.isFunding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_money, size: 18),
          label: Text(walletState.isFunding
              ? 'Funding...'
              : 'Fund with Friendbot'),
          style: FilledButton.styleFrom(
            backgroundColor: isUnfunded ? Colors.amber.shade700 : Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _copyToClipboard(
            context,
            walletState.publicKey!,
          ),
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
      ],
    );
  }

  String _formatLastUpdated(DateTime lastUpdated) {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _buildWalletContent(
    BuildContext context,
    ThemeData theme,
    WalletState walletState,
    WalletNotifier walletNotifier,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TestnetBanner(),
          const SizedBox(height: 16),
          // Show the activation state for unfunded wallets on the
          // primary position — the user cannot transact until the
          // account is active on the network.
          if (!walletState.funded)
            _UnfundedActivationCard(
              walletState: walletState,
              walletNotifier: walletNotifier,
            )
          else
            _FundedBalanceCard(
              walletState: walletState,
              onSend: () => _showSendEchoSheet(context, ref),
              onCopy: () =>
                  _copyToClipboard(context, walletState.publicKey!),
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
                        _formatLastUpdated(walletState.lastUpdated!),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ECHO',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${walletState.echoBalance.toStringAsFixed(1)} ECHO',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'XLM',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${walletState.xlmBalance.toStringAsFixed(2)} XLM',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (walletState.hasStreakBonus) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Streak bonus active',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (walletState.stellarError != null)
                  _buildStellarError(theme, walletState, walletNotifier)
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              _showSendEchoSheet(context, ref),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
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
                          onPressed: () => _copyToClipboard(
                            context,
                            walletState.publicKey!,
                          ),
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
              ],
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
                    Text(
                      'Stellar Public Key',
                      style: theme.textTheme.titleSmall,
                    ),
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
                    walletState.publicKey ?? '',
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
                        onPressed: () => _copyToClipboard(
                          context,
                          walletState.publicKey!,
                        ),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy Key'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showQrModal(
                          context,
                          walletState.publicKey!,
                        ),
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Show QR'),
                      ),
                    ),
                  ],
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
                color: theme.colorScheme.surfaceContainerHighest,
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
                final amountText =
                    '${reward.amount >= 0 ? '+' : '-'}'
                    '${reward.amount.toStringAsFixed(reward.amount.truncateToDouble() == reward.amount ? 0 : 2)} ECHO';
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_formatRewardReason(reward.reason)),
                      subtitle: Text(
                        reward.createdAt
                            .toLocal()
                            .toIso8601String()
                            .split('T')
                            .first,
                      ),
                      trailing: Text(
                        amountText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: reward.amount >= 0
                              ? AppTheme.successColor
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                );
              }).toList(),
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
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan this QR code to get your Stellar public key',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
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

class _TestnetBanner extends StatefulWidget {
  @override
  State<_TestnetBanner> createState() => _TestnetBannerState();
}

class _TestnetBannerState extends State<_TestnetBanner> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _dismissed = prefs.getBool(_testnetDismissKey) ?? false);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testnetDismissKey, true);
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '⚠ Testnet — ECHO and XLM here have no real-world value',
              style: TextStyle(fontSize: 13, color: Colors.brown),
            ),
          ),
          GestureDetector(
            onTap: _dismiss,
            child: const Icon(Icons.close, size: 18, color: Colors.brown),
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

/// Primary balance card shown for funded wallets.
///
/// Renders the live XLM balance next to the ECHO balance pulled from
/// Supabase / Horizon so testers can tell at a glance whether the network
/// has indexed their rewards.
class _FundedBalanceCard extends StatelessWidget {
  const _FundedBalanceCard({
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
    final xlmText =
        '${walletState.xlmBalance.toStringAsFixed(2)} XLM';
    final echoText =
        '${walletState.balance.toStringAsFixed(0)} ECHO';
    final isLiveLoading = walletState.isLiveBalancesLoading;

    return Container(
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Streak bonus active',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white),
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
                    foregroundColor: AppTheme.primaryColor,
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
class _UnfundedActivationCard extends StatelessWidget {
  const _UnfundedActivationCard({
    required this.walletState,
    required this.walletNotifier,
  });

  final WalletState walletState;
  final WalletNotifier walletNotifier;

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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
                onPressed: isFunding ? null : walletNotifier.fundWithFriendbot,
                icon: isFunding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('🚰', style: TextStyle(fontSize: 16)),
                label: Text(
                  isFunding ? 'Funding…' : 'Fund with Friendbot',
                ),
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
