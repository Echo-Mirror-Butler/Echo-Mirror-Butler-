/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

abstract class EchoWallet
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  EchoWallet._({
    this.id,
    required this.userId,
    required this.balance,
    required this.createdAt,
  });

  factory EchoWallet({
    int? id,
    required int userId,
    required double balance,
    required DateTime createdAt,
  }) = _EchoWalletImpl;

  factory EchoWallet.fromJson(Map<String, dynamic> jsonSerialization) {
    return EchoWallet(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      balance: (jsonSerialization['balance'] as num).toDouble(),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = EchoWalletTable();

  static const db = EchoWalletRepository._();

  @override
  int? id;

  int userId;

  double balance;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [EchoWallet]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  EchoWallet copyWith({
    int? id,
    int? userId,
    double? balance,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EchoWallet',
      if (id != null) 'id': id,
      'userId': userId,
      'balance': balance,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'EchoWallet',
      if (id != null) 'id': id,
      'userId': userId,
      'balance': balance,
      'createdAt': createdAt.toJson(),
    };
  }

  static EchoWalletInclude include() {
    return EchoWalletInclude._();
  }

  static EchoWalletIncludeList includeList({
    _i1.WhereExpressionBuilder<EchoWalletTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EchoWalletTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EchoWalletTable>? orderByList,
    EchoWalletInclude? include,
  }) {
    return EchoWalletIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EchoWallet.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(EchoWallet.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EchoWalletImpl extends EchoWallet {
  _EchoWalletImpl({
    int? id,
    required int userId,
    required double balance,
    required DateTime createdAt,
  }) : super._(
         id: id,
         userId: userId,
         balance: balance,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [EchoWallet]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  EchoWallet copyWith({
    Object? id = _Undefined,
    int? userId,
    double? balance,
    DateTime? createdAt,
  }) {
    return EchoWallet(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class EchoWalletUpdateTable extends _i1.UpdateTable<EchoWalletTable> {
  EchoWalletUpdateTable(super.table);

  _i1.ColumnValue<int, int> userId(int value) => _i1.ColumnValue(
    table.userId,
    value,
  );

  _i1.ColumnValue<double, double> balance(double value) => _i1.ColumnValue(
    table.balance,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class EchoWalletTable extends _i1.Table<int?> {
  EchoWalletTable({super.tableRelation}) : super(tableName: 'echo_wallets') {
    updateTable = EchoWalletUpdateTable(this);
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
    balance = _i1.ColumnDouble(
      'balance',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final EchoWalletUpdateTable updateTable;

  late final _i1.ColumnInt userId;

  late final _i1.ColumnDouble balance;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    userId,
    balance,
    createdAt,
  ];
}

class EchoWalletInclude extends _i1.IncludeObject {
  EchoWalletInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => EchoWallet.t;
}

class EchoWalletIncludeList extends _i1.IncludeList {
  EchoWalletIncludeList._({
    _i1.WhereExpressionBuilder<EchoWalletTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EchoWallet.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => EchoWallet.t;
}

class EchoWalletRepository {
  const EchoWalletRepository._();

  /// Returns a list of [EchoWallet]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<EchoWallet>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<EchoWalletTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EchoWalletTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EchoWalletTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<EchoWallet>(
      where: where?.call(EchoWallet.t),
      orderBy: orderBy?.call(EchoWallet.t),
      orderByList: orderByList?.call(EchoWallet.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [EchoWallet] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<EchoWallet?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<EchoWalletTable>? where,
    int? offset,
    _i1.OrderByBuilder<EchoWalletTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EchoWalletTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<EchoWallet>(
      where: where?.call(EchoWallet.t),
      orderBy: orderBy?.call(EchoWallet.t),
      orderByList: orderByList?.call(EchoWallet.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [EchoWallet] by its [id] or null if no such row exists.
  Future<EchoWallet?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<EchoWallet>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [EchoWallet]s in the list and returns the inserted rows.
  ///
  /// The returned [EchoWallet]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<EchoWallet>> insert(
    _i1.Session session,
    List<EchoWallet> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<EchoWallet>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [EchoWallet] and returns the inserted row.
  ///
  /// The returned [EchoWallet] will have its `id` field set.
  Future<EchoWallet> insertRow(
    _i1.Session session,
    EchoWallet row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<EchoWallet>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [EchoWallet]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<EchoWallet>> update(
    _i1.Session session,
    List<EchoWallet> rows, {
    _i1.ColumnSelections<EchoWalletTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<EchoWallet>(
      rows,
      columns: columns?.call(EchoWallet.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EchoWallet]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EchoWallet> updateRow(
    _i1.Session session,
    EchoWallet row, {
    _i1.ColumnSelections<EchoWalletTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<EchoWallet>(
      row,
      columns: columns?.call(EchoWallet.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EchoWallet] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<EchoWallet?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<EchoWalletUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<EchoWallet>(
      id,
      columnValues: columnValues(EchoWallet.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EchoWallet]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<EchoWallet>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<EchoWalletUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<EchoWalletTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EchoWalletTable>? orderBy,
    _i1.OrderByListBuilder<EchoWalletTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<EchoWallet>(
      columnValues: columnValues(EchoWallet.t.updateTable),
      where: where(EchoWallet.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EchoWallet.t),
      orderByList: orderByList?.call(EchoWallet.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [EchoWallet]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<EchoWallet>> delete(
    _i1.Session session,
    List<EchoWallet> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<EchoWallet>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [EchoWallet].
  Future<EchoWallet> deleteRow(
    _i1.Session session,
    EchoWallet row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EchoWallet>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<EchoWallet>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<EchoWalletTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<EchoWallet>(
      where: where(EchoWallet.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<EchoWalletTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<EchoWallet>(
      where: where?.call(EchoWallet.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
