part of 'protocol.dart';

class GiftTransaction extends TableRow {
  GiftTransaction({
    int? id,
    required this.senderUserId,
    required this.recipientUserId,
    required this.echoAmount,
    required this.createdAt,
    required this.status,
    this.stellarTxHash,
    this.message,
  }) : super(id);

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

  static const db = GiftTransactionRepository._();

  int senderUserId;
  int recipientUserId;
  double echoAmount;
  DateTime createdAt;
  String status;
  String? stellarTxHash;
  String? message;

  @override
  String get tableName => 'gift_transactions';

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

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'senderUserId': senderUserId,
      'recipientUserId': recipientUserId,
      'echoAmount': echoAmount,
      'createdAt': createdAt,
      'status': status,
      'stellarTxHash': stellarTxHash,
      'message': message,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      if (id != null) 'id': id,
      'senderUserId': senderUserId,
      'recipientUserId': recipientUserId,
      'echoAmount': echoAmount,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'stellarTxHash': stellarTxHash,
      'message': message,
    };
  }

  @override
  void setColumn(String columnName, value) {
    switch (columnName) {
      case 'id':
        id = value;
        return;
      case 'senderUserId':
        senderUserId = value;
        return;
      case 'recipientUserId':
        recipientUserId = value;
        return;
      case 'echoAmount':
        echoAmount = value;
        return;
      case 'createdAt':
        createdAt = value;
        return;
      case 'status':
        status = value;
        return;
      case 'stellarTxHash':
        stellarTxHash = value;
        return;
      case 'message':
        message = value;
        return;
    }
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

class GiftTransactionTable extends Table {
  GiftTransactionTable({super.tableRelation}) : super(tableName: 'gift_transactions') {
    senderUserId = ColumnInt('senderUserId');
    recipientUserId = ColumnInt('recipientUserId');
    echoAmount = ColumnDouble('echoAmount');
    createdAt = ColumnDateTime('createdAt');
    status = ColumnString('status');
    stellarTxHash = ColumnString('stellarTxHash');
    message = ColumnString('message');
  }

  late final ColumnInt senderUserId;
  late final ColumnInt recipientUserId;
  late final ColumnDouble echoAmount;
  late final ColumnDateTime createdAt;
  late final ColumnString status;
  late final ColumnString stellarTxHash;
  late final ColumnString message;

  @override
  List<Column> get columns => [
        id,
        senderUserId,
        recipientUserId,
        echoAmount,
        createdAt,
        status,
        stellarTxHash,
        message,
      ];
}

class GiftTransactionRepository {
  const GiftTransactionRepository._();

  Future<List<GiftTransaction>> find(
    Session session, {
    GiftTransactionExpressionBuilder? where,
    int? limit,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.find<GiftTransaction>(
      where: where?.call(GiftTransactionTable()),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<GiftTransaction?> findFirstRow(
    Session session, {
    GiftTransactionExpressionBuilder? where,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.findFirstRow<GiftTransaction>(
      where: where?.call(GiftTransactionTable()),
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<GiftTransaction?> findById(Session session, int id) async {
    return session.db.findById<GiftTransaction>(id);
  }

  Future<GiftTransaction> insertRow(Session session, GiftTransaction row) async {
    return session.db.insertRow<GiftTransaction>(row);
  }

  Future<GiftTransaction> updateRow(Session session, GiftTransaction row) async {
    return session.db.updateRow<GiftTransaction>(row);
  }

  Future<int> deleteRow(Session session, GiftTransaction row) async {
    return session.db.deleteRow<GiftTransaction>(row);
  }
}

typedef GiftTransactionExpressionBuilder = Expression Function(GiftTransactionTable t);
