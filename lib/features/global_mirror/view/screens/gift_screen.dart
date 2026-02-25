import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_theme.dart';
import '../../viewmodel/providers/gift_provider.dart';

/// Screen for sending ECHO token gifts to another user.
class GiftScreen extends ConsumerStatefulWidget {
  const GiftScreen({super.key, required this.recipientUserId});

  final int recipientUserId;

  @override
  ConsumerState<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends ConsumerState<GiftScreen> {
  double _selectedAmount = 5.0;
  final _messageController = TextEditingController();
  late final ConfettiController _confettiController;

  static const _presetAmounts = [1.0, 5.0, 10.0, 25.0];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(giftProvider.notifier).loadBalance();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final success = await ref
        .read(giftProvider.notifier)
        .sendGift(
          recipientUserId: widget.recipientUserId,
          amount: _selectedAmount,
          message: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        );

    if (success && mounted) {
      _confettiController.play();
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final giftState = ref.watch(giftProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send ECHO Gift'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Gift History',
            onPressed: () => context.push('/gift-history'),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ECHO balance
                _buildBalanceCard(theme, giftState.echoBalance),
                const SizedBox(height: 28),

                // Amount picker
                Text('Gift Amount', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildAmountPicker(theme),
                const SizedBox(height: 28),

                // Message field
                Text('Message (optional)', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLength: 140,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a kind note...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Error
                if (giftState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      giftState.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Send button
                FilledButton.icon(
                  onPressed:
                      giftState.isSending ||
                          _selectedAmount > giftState.echoBalance
                      ? null
                      : _handleSend,
                  icon: giftState.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(FontAwesomeIcons.gift),
                  label: Text(
                    giftState.isSending
                        ? 'Sending...'
                        : 'Send ${_selectedAmount.toStringAsFixed(0)} ECHO',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                if (_selectedAmount > giftState.echoBalance)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Insufficient ECHO balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                AppTheme.accentColor,
                Colors.amber,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme, double balance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(FontAwesomeIcons.coins, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your ECHO Balance',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${balance.toStringAsFixed(0)} ECHO',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPicker(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ..._presetAmounts.map(
          (amount) => ChoiceChip(
            label: Text('${amount.toStringAsFixed(0)} ECHO'),
            selected: _selectedAmount == amount,
            selectedColor: AppTheme.primaryColor,
            labelStyle: TextStyle(
              color: _selectedAmount == amount ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => setState(() => _selectedAmount = amount),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        // Custom amount
        ActionChip(
          label: const Text('Custom'),
          avatar: const Icon(Icons.edit, size: 16),
          onPressed: _showCustomAmountDialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }

  void _showCustomAmountDialog() {
    final controller = TextEditingController(
      text: _selectedAmount.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          decoration: const InputDecoration(
            labelText: 'ECHO amount (1–100)',
            suffixText: 'ECHO',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text) ?? 1.0;
              setState(() {
                _selectedAmount = value.clamp(1.0, 100.0);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
