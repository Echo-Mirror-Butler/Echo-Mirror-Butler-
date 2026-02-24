part of 'protocol.dart';

class GiftTransaction extends SerializableModel {
  GiftTransaction({
    this.id,
    required this.senderUserId,
    required this.recipientUserId,
    required this.echoAmount,
    required this.createdAt,
    required this.status,
    this.stellarTxHash,
    this.message,
  });

  factory GiftTransaction.fromJson(Map<String, dynamic> json) {
    return GiftTransaction(
      id: json['id'] as int?,
      senderUserId: json['senderUserId'] as int,
      recipientUserId: json['recipientUserId'] as int,
      echoAmount: (json['echoAmount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: json['status'] as String,
      stellarTxHash: json['stellarTxHash'] as String?,
      message: json['message'] as String?,
    );
  }

  int? id;
  int senderUserId;
  int recipientUserId;
  double echoAmount;
  DateTime createdAt;
  String status;
  String? stellarTxHash;
  String? message;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'senderUserId': senderUserId,
      'recipientUserId': recipientUserId,
      'echoAmount': echoAmount,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      if (stellarTxHash != null) 'stellarTxHash': stellarTxHash,
      if (message != null) 'message': message,
    };
  }

  GiftTransaction copyWith({
    int? id,
    int? senderUserId,
    int? recipientUserId,
    double? echoAmount,
    DateTime? createdAt,
    String? status,
    String? stellarTxHash,
    String? message,
  }) {
    return GiftTransaction(
      id: id ?? this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      echoAmount: echoAmount ?? this.echoAmount,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      stellarTxHash: stellarTxHash ?? this.stellarTxHash,
      message: message ?? this.message,
    );
  }
}
