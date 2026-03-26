/// Client-side model for a gift transaction
class GiftTransactionModel {
  const GiftTransactionModel({
    required this.id,
    required this.senderUserId,
    required this.recipientUserId,
    required this.echoAmount,
    required this.createdAt,
    required this.status,
    this.stellarTxHash,
    this.message,
  });

  final String id;
  final String senderUserId;
  final String recipientUserId;
  final double echoAmount;
  final DateTime createdAt;
  final String status;
  final String? stellarTxHash;
  final String? message;

  bool get isCompleted => status == 'completed';

  factory GiftTransactionModel.fromSupabase(Map<String, dynamic> row) {
    return GiftTransactionModel(
      id: row['id'] as String,
      senderUserId: row['sender_user_id'] as String,
      recipientUserId: row['recipient_user_id'] as String,
      echoAmount: (row['echo_amount'] as num).toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
      status: row['status'] as String,
      stellarTxHash: row['stellar_tx_hash'] as String?,
      message: row['message'] as String?,
    );
  }
}
