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

  final int id;
  final int senderUserId;
  final int recipientUserId;
  final double echoAmount;
  final DateTime createdAt;
  final String status;
  final String? stellarTxHash;
  final String? message;

  bool get isCompleted => status == 'completed';
}
