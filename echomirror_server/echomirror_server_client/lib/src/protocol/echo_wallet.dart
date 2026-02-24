part of 'protocol.dart';

class EchoWallet extends SerializableModel {
  EchoWallet({
    this.id,
    required this.userId,
    required this.balance,
    required this.createdAt,
  });

  factory EchoWallet.fromJson(Map<String, dynamic> json) {
    return EchoWallet(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      balance: (json['balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  int? id;
  int userId;
  double balance;
  DateTime createdAt;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  EchoWallet copyWith({
    int? id,
    int? userId,
    double? balance,
    DateTime? createdAt,
  }) {
    return EchoWallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
