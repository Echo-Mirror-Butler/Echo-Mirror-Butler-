import 'package:flutter/material.dart';

class SendConfirmationDialog extends StatelessWidget {
  final String recipientName;
  final String recipientAddress;
  final double amount;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const SendConfirmationDialog({
    super.key,
    required this.recipientName,
    required this.recipientAddress,
    required this.amount,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Send'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Recipient:', recipientName),
          const SizedBox(height: 8),
          _buildInfoRow('Address:', recipientAddress.substring(0, 6) + '...'),
          const SizedBox(height: 8),
          _buildInfoRow('Amount:', '${amount.toStringAsFixed(2)} ECHO'),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Message:', message),
          ],
          const SizedBox(height: 16),
          const Text(
            'This transaction cannot be reversed.',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm Send'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 80, child: Text('Recipient:', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(value)),
      ],
    );
  }
}
