import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/no_connection_widget.dart';
import '../../viewmodel/providers/wallet_provider.dart';
import '../widgets/wallet/echo_balance_card.dart';
import '../widgets/wallet/send_echo_sheet.dart';
import '../widgets/wallet/wallet_empty_state.dart';
import '../widgets/wallet/wallet_history_section.dart';
import '../widgets/wallet/wallet_public_key_card.dart';
import '../widgets/wallet/wallet_qr_sheet.dart';
import '../widgets/wallet/wallet_status_cards.dart';
import '../widgets/wallet/wallet_testnet_banner.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final walletNotifier = ref.read(walletProvider.notifier);

    // Surface friendbot result toasts. The provider stores the message;
    // the listener pops a snackbar then clears the field so it does not
    // replay when the widget rebuilds.
    ref.listen<WalletState>(walletProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      final errorChanged = previous?.fundingError != next.fundingError;
      final justFunded = previous == null
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
          ? NoConnectionWidget(
              message: walletState.error!,
              onRetry: () => walletNotifier.loadWallet(),
            )
          : !walletState.exists
          ? WalletEmptyState(onCreateWallet: walletNotifier.createWallet)
          : RefreshIndicator(
              onRefresh: () => walletNotifier.loadWallet(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildWalletContent(context, walletState, walletNotifier),
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
          Expanded(child: Text('10,000 XLM added! Your wallet is now active.')),
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

  Widget _buildWalletContent(
    BuildContext context,
    WalletState walletState,
    WalletNotifier walletNotifier,
  ) {
    void onSend() => showSendEchoSheet(context);
    void onCopy() => _copyToClipboard(context, walletState.publicKey!);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WalletTestnetBanner(),
          const SizedBox(height: 16),
          // Show the activation state for unfunded wallets on the
          // primary position — the user cannot transact until the
          // account is active on the network.
          if (!walletState.funded)
            UnfundedActivationCard(
              walletState: walletState,
              onFund: walletNotifier.fundWithFriendbot,
            )
          else
            FundedBalanceCard(
              walletState: walletState,
              onSend: onSend,
              onCopy: onCopy,
            ),
          EchoBalanceCard(
            walletState: walletState,
            onSend: onSend,
            onCopy: onCopy,
            onFund: walletNotifier.fundWithFriendbot,
          ),
          const SizedBox(height: 24),
          WalletPublicKeyCard(
            publicKey: walletState.publicKey,
            onCopy: onCopy,
            onShowQr: () => showWalletQrSheet(context, walletState.publicKey!),
          ),
          const SizedBox(height: 24),
          RewardHistorySection(history: walletState.history),
          const SizedBox(height: 24),
          OnChainActivitySection(
            transactions: walletState.onChainHistory,
            publicKey: walletState.publicKey,
            isLoading: walletState.isOnChainHistoryLoading,
          ),
        ],
      ),
    );
  }
}
