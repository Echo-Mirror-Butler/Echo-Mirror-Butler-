/// Represents a payment operation from the Stellar Horizon API.
class OnChainTransactionModel {
  const OnChainTransactionModel({
    required this.id,
    required this.type,
    required this.transactionHash,
    required this.sourceAccount,
    required this.amount,
    required this.asset,
    required this.from,
    required this.to,
    required this.timestamp,
    this.memo,
  });

  final String id;
  final String type;
  final String transactionHash;
  final String sourceAccount;
  final String amount;
  final String asset;
  final String from;
  final String to;
  final DateTime timestamp;
  final String? memo;

  /// Determines if this transaction is incoming or outgoing relative to [relativeToAccount].
  bool isIncoming(String relativeToAccount) => to == relativeToAccount;

  /// User-friendly label for the transaction type.
  String get typeLabel {
    switch (type) {
      case 'payment':
        return 'Payment';
      case 'create_account':
        return 'Account Created';
      case 'change_trust':
        return 'Trust Line Changed';
      default:
        return 'Account Activity';
    }
  }

  factory OnChainTransactionModel.fromHorizon(Map<String, dynamic> json) {
    return OnChainTransactionModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      transactionHash: json['transaction_hash'] as String? ?? '',
      sourceAccount: json['source_account'] as String? ?? '',
      amount: json['amount'] as String? ?? '0',
      asset: json['asset_code'] as String? ?? 'native',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      timestamp: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      memo: json['memo'] as String?,
    );
  }
}
