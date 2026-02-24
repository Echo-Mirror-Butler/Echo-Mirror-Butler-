part of 'protocol.dart';

class EchoWallet extends TableRow {
  EchoWallet({
    int? id,
    required this.userId,
    required this.balance,
    required this.createdAt,
  }) : super(id);

  factory EchoWallet.fromJson(Map<String, dynamic> json) {
    return EchoWallet(
      id: json['id'] as int?,
      userId: json['userId'] as int,
      balance: (json['balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static const db = EchoWalletRepository._();

  int userId;
  double balance;
  DateTime createdAt;

  @override
  String get tableName => 'echo_wallets';

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {'userId': userId, 'balance': balance, 'createdAt': createdAt};
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  void setColumn(String columnName, value) {
    switch (columnName) {
      case 'id':
        id = value;
        return;
      case 'userId':
        userId = value;
        return;
      case 'balance':
        balance = value;
        return;
      case 'createdAt':
        createdAt = value;
        return;
    }
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

class EchoWalletTable extends Table {
  EchoWalletTable({super.tableRelation}) : super(tableName: 'echo_wallets') {
    userId = ColumnInt('userId');
    balance = ColumnDouble('balance');
    createdAt = ColumnDateTime('createdAt');
  }

  late final ColumnInt userId;
  late final ColumnDouble balance;
  late final ColumnDateTime createdAt;

  @override
  List<Column> get columns => [id, userId, balance, createdAt];
}

class EchoWalletRepository {
  const EchoWalletRepository._();

  Future<List<EchoWallet>> find(
    Session session, {
    EchoWalletExpressionBuilder? where,
    int? limit,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.find<EchoWallet>(
      where: where?.call(EchoWalletTable()),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<EchoWallet?> findFirstRow(
    Session session, {
    EchoWalletExpressionBuilder? where,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.findFirstRow<EchoWallet>(
      where: where?.call(EchoWalletTable()),
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<EchoWallet?> findById(Session session, int id) async {
    return session.db.findById<EchoWallet>(id);
  }

  Future<EchoWallet> insertRow(Session session, EchoWallet row) async {
    return session.db.insertRow<EchoWallet>(row);
  }

  Future<EchoWallet> updateRow(Session session, EchoWallet row) async {
    return session.db.updateRow<EchoWallet>(row);
  }

  Future<int> deleteRow(Session session, EchoWallet row) async {
    return session.db.deleteRow<EchoWallet>(row);
  }
}

typedef EchoWalletExpressionBuilder = Expression Function(EchoWalletTable t);
