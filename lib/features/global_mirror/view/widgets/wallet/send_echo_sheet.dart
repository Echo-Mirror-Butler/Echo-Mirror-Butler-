import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/services/toast_service.dart';
import '../../../../../core/themes/app_theme.dart';
import '../../../../../core/utils/error_message_mapper.dart';
import '../../../viewmodel/providers/wallet_provider.dart';
import '../../../widgets/send_confirmation_dialog.dart';
import 'recipient_resolver.dart';
import 'wallet_testnet_banner.dart';

/// Preset amounts offered as chips in the send sheet.
const sendEchoPresetAmounts = [5, 10, 25, 50];

/// Opens the "Send ECHO" bottom sheet and shows a success toast on the
/// host [context] once the transfer completes.
Future<void> showSendEchoSheet(BuildContext context) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SendEchoSheet(),
  );
  if (sent == true && context.mounted) {
    ToastService.success(context, 'ECHO sent successfully.');
  }
}

/// Bottom sheet for sending ECHO to another user. Pops with `true` once the
/// transfer succeeds and the wallet has been reloaded.
class SendEchoSheet extends ConsumerStatefulWidget {
  const SendEchoSheet({super.key, this.client});

  /// Supabase client used to resolve recipients and invoke `send-echo`.
  /// Defaults to [Supabase.instance.client].
  final SupabaseClient? client;

  @override
  ConsumerState<SendEchoSheet> createState() => _SendEchoSheetState();
}

class _SendEchoSheetState extends ConsumerState<SendEchoSheet> {
  late final SupabaseClient _supabase;
  final _recipientController = TextEditingController();
  final _customAmountController = TextEditingController(
    text: sendEchoPresetAmounts[1].toString(),
  );
  var _selectedAmount = sendEchoPresetAmounts[1].toDouble();
  var _isSending = false;
  String? _errorMessage;
  String? _recipientError;
  String? _recipientSuccess;
  bool _isResolvingRecipient = false;
  bool _hasValidRecipient = false;
  String? _amountError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _supabase = widget.client ?? Supabase.instance.client;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recipientController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _sendEcho() async {
    if (_recipientController.text.trim().isEmpty) {
      throw Exception('Recipient is required.');
    }
    final rawAmount =
        double.tryParse(_customAmountController.text.trim()) ??
        _selectedAmount;
    final amount = (rawAmount * 100).round() / 100; // Round to 2 decimal places
    if (amount <= 0) throw Exception('Enter a valid ECHO amount.');

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SendConfirmationDialog(
        recipientName: _recipientController.text.trim(),
        recipientAddress: _recipientController.text.trim(),
        amount: amount,
        message: '',
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed != true) {
      return;
    }

    final recipientId = await resolveRecipientId(
      _supabase,
      _recipientController.text,
    );
    final response = await _supabase.functions.invoke(
      'send-echo',
      body: {'recipient_id': recipientId, 'amount': amount},
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    await ref.read(walletProvider.notifier).loadWallet();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _validateRecipient(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _isResolvingRecipient = false;
        _recipientError = null;
        _recipientSuccess = null;
        _hasValidRecipient = false;
      });
      return;
    }
    setState(() {
      _isResolvingRecipient = true;
      _recipientError = null;
      _recipientSuccess = null;
      _hasValidRecipient = false;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final resolvedId = await resolveRecipientId(_supabase, value);
        if (!mounted) return;
        setState(() {
          _isResolvingRecipient = false;
          _recipientSuccess = 'Sending to: $resolvedId';
          _recipientError = null;
          _hasValidRecipient = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isResolvingRecipient = false;
          _recipientError = 'Recipient not found';
          _recipientSuccess = null;
          _hasValidRecipient = false;
        });
      }
    });
  }

  void _validateAmount(String value) {
    if (value.trim().isEmpty) {
      setState(() => _amountError = null);
      return;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      setState(() => _amountError = "Enter a valid number");
    } else {
      // Round to 2 decimal places
      final rounded = (parsed * 100).round() / 100;
      if (rounded <= 0) {
        setState(() => _amountError = "Amount must be greater than 0");
      } else if (rounded > (ref.read(walletProvider).balance)) {
        setState(() => _amountError = "Insufficient ECHO balance");
      } else {
        setState(() {
          _amountError = null;
          _selectedAmount = rounded;
          _customAmountController.text = rounded.toStringAsFixed(2);
        });
      }
    }
  }

  Future<void> _onSendPressed() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await _sendEcho();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = friendlyErrorMessage(e);
        });
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  Widget? _recipientSuffixIcon() {
    if (_isResolvingRecipient) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_recipientSuccess != null) {
      return const Icon(Icons.check_circle, color: AppTheme.successColor);
    }
    if (_recipientError != null) {
      return const Icon(Icons.error, color: AppTheme.errorColor);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasValidRecipient && _amountError == null && !_isSending;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            const WalletTestnetBanner(),
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Send ECHO',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a recipient and the amount of ECHO to send.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _recipientController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Recipient',
                hintText: 'User ID, email, or Stellar address',
                suffixIcon: _recipientSuffixIcon(),
              ),
              onChanged: _validateRecipient,
            ),
            if (_recipientSuccess != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  _recipientSuccess!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            if (_recipientError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  _recipientError!,
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
              children: sendEchoPresetAmounts.map((amount) {
                return ChoiceChip(
                  label: Text('$amount ECHO'),
                  selected: _selectedAmount == amount,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _selectedAmount = amount.toDouble();
                      _customAmountController.text = amount.toString();
                      _amountError = null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: 'ECHO',
                errorText: _amountError,
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value.trim());
                if (parsed != null) {
                  setState(() => _selectedAmount = parsed);
                }
                _validateAmount(value);
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: canSend ? _onSendPressed : null,
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send ECHO'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSending ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
