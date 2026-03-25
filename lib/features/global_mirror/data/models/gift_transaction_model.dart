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

  factory GiftTransactionModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    DateTime parseDateTime(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return GiftTransactionModel(
      id: parseInt(json['id']),
      senderUserId: parseInt(json['sender_user_id'] ?? json['senderUserId']),
      recipientUserId: parseInt(
        json['recipient_user_id'] ?? json['recipientUserId'],
      ),
      echoAmount: parseDouble(json['echo_amount'] ?? json['echoAmount']),
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      status: (json['status'] ?? 'completed').toString(),
      stellarTxHash: json['stellar_tx_hash']?.toString(),
      message: json['message']?.toString(),
    );
  }
}
