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

abstract class GiftTransaction
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  GiftTransaction._({
    this.id,
    required this.senderUserId,
    required this.recipientUserId,
    required this.echoAmount,
    required this.createdAt,
    required this.status,
    this.stellarTxHash,
    this.message,
  });

  factory GiftTransaction({
    int? id,
    required int senderUserId,
    required int recipientUserId,
    required double echoAmount,
    required DateTime createdAt,
    required String status,
    String? stellarTxHash,
    String? message,
  }) = _GiftTransactionImpl;

  factory GiftTransaction.fromJson(Map<String, dynamic> jsonSerialization) {
    return GiftTransaction(
      id: jsonSerialization['id'] as int?,
      senderUserId: jsonSerialization['senderUserId'] as int,
      recipientUserId: jsonSerialization['recipientUserId'] as int,
      echoAmount: (jsonSerialization['echoAmount'] as num).toDouble(),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      status: jsonSerialization['status'] as String,
      stellarTxHash: jsonSerialization['stellarTxHash'] as String?,
      message: jsonSerialization['message'] as String?,
    );
  }

  static final t = GiftTransactionTable();

  static const db = GiftTransactionRepository._();

  @override
  int? id;

  int senderUserId;

  int recipientUserId;

  double echoAmount;

  DateTime createdAt;

  String status;

  String? stellarTxHash;

  String? message;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [GiftTransaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  GiftTransaction copyWith({
    int? id,
    int? senderUserId,
    int? recipientUserId,
    double? echoAmount,
    DateTime? createdAt,
    String? status,
    String? stellarTxHash,
    String? message,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'GiftTransaction',
      if (id != null) 'id': id,
      'senderUserId': senderUserId,
      'recipientUserId': recipientUserId,
      'echoAmount': echoAmount,
      'createdAt': createdAt.toJson(),
      'status': status,
      if (stellarTxHash != null) 'stellarTxHash': stellarTxHash,
      if (message != null) 'message': message,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'GiftTransaction',
      if (id != null) 'id': id,
      'senderUserId': senderUserId,
      'recipientUserId': recipientUserId,
      'echoAmount': echoAmount,
      'createdAt': createdAt.toJson(),
      'status': status,
      if (stellarTxHash != null) 'stellarTxHash': stellarTxHash,
      if (message != null) 'message': message,
    };
  }

  static GiftTransactionInclude include() {
    return GiftTransactionInclude._();
  }

  static GiftTransactionIncludeList includeList({
    _i1.WhereExpressionBuilder<GiftTransactionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<GiftTransactionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<GiftTransactionTable>? orderByList,
    GiftTransactionInclude? include,
  }) {
    return GiftTransactionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(GiftTransaction.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(GiftTransaction.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _GiftTransactionImpl extends GiftTransaction {
  _GiftTransactionImpl({
    int? id,
    required int senderUserId,
    required int recipientUserId,
    required double echoAmount,
    required DateTime createdAt,
    required String status,
    String? stellarTxHash,
    String? message,
  }) : super._(
         id: id,
         senderUserId: senderUserId,
         recipientUserId: recipientUserId,
         echoAmount: echoAmount,
         createdAt: createdAt,
         status: status,
         stellarTxHash: stellarTxHash,
         message: message,
       );

  /// Returns a shallow copy of this [GiftTransaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  GiftTransaction copyWith({
    Object? id = _Undefined,
    int? senderUserId,
    int? recipientUserId,
    double? echoAmount,
    DateTime? createdAt,
    String? status,
    Object? stellarTxHash = _Undefined,
    Object? message = _Undefined,
  }) {
    return GiftTransaction(
      id: id is int? ? id : this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      echoAmount: echoAmount ?? this.echoAmount,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      stellarTxHash: stellarTxHash is String?
          ? stellarTxHash
          : this.stellarTxHash,
      message: message is String? ? message : this.message,
    );
  }
}

class GiftTransactionUpdateTable extends _i1.UpdateTable<GiftTransactionTable> {
  GiftTransactionUpdateTable(super.table);

  _i1.ColumnValue<int, int> senderUserId(int value) => _i1.ColumnValue(
    table.senderUserId,
    value,
  );

  _i1.ColumnValue<int, int> recipientUserId(int value) => _i1.ColumnValue(
    table.recipientUserId,
    value,
  );

  _i1.ColumnValue<double, double> echoAmount(double value) => _i1.ColumnValue(
    table.echoAmount,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> stellarTxHash(String? value) =>
      _i1.ColumnValue(
        table.stellarTxHash,
        value,
      );

  _i1.ColumnValue<String, String> message(String? value) => _i1.ColumnValue(
    table.message,
    value,
  );
}

class GiftTransactionTable extends _i1.Table<int?> {
  GiftTransactionTable({super.tableRelation})
    : super(tableName: 'gift_transactions') {
    updateTable = GiftTransactionUpdateTable(this);
    senderUserId = _i1.ColumnInt(
      'senderUserId',
      this,
    );
    recipientUserId = _i1.ColumnInt(
      'recipientUserId',
      this,
    );
    echoAmount = _i1.ColumnDouble(
      'echoAmount',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    stellarTxHash = _i1.ColumnString(
      'stellarTxHash',
      this,
    );
    message = _i1.ColumnString(
      'message',
      this,
    );
  }

  late final GiftTransactionUpdateTable updateTable;

  late final _i1.ColumnInt senderUserId;

  late final _i1.ColumnInt recipientUserId;

  late final _i1.ColumnDouble echoAmount;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnString status;

  late final _i1.ColumnString stellarTxHash;

  late final _i1.ColumnString message;

  @override
  List<_i1.Column> get columns => [
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

class GiftTransactionInclude extends _i1.IncludeObject {
  GiftTransactionInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => GiftTransaction.t;
}

class GiftTransactionIncludeList extends _i1.IncludeList {
  GiftTransactionIncludeList._({
    _i1.WhereExpressionBuilder<GiftTransactionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(GiftTransaction.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => GiftTransaction.t;
}

class GiftTransactionRepository {
  const GiftTransactionRepository._();

  /// Returns a list of [GiftTransaction]s matching the given query parameters.
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
  Future<List<GiftTransaction>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<GiftTransactionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<GiftTransactionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<GiftTransactionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<GiftTransaction>(
      where: where?.call(GiftTransaction.t),
      orderBy: orderBy?.call(GiftTransaction.t),
      orderByList: orderByList?.call(GiftTransaction.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [GiftTransaction] matching the given query parameters.
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
  Future<GiftTransaction?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<GiftTransactionTable>? where,
    int? offset,
    _i1.OrderByBuilder<GiftTransactionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<GiftTransactionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<GiftTransaction>(
      where: where?.call(GiftTransaction.t),
      orderBy: orderBy?.call(GiftTransaction.t),
      orderByList: orderByList?.call(GiftTransaction.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [GiftTransaction] by its [id] or null if no such row exists.
  Future<GiftTransaction?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<GiftTransaction>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [GiftTransaction]s in the list and returns the inserted rows.
  ///
  /// The returned [GiftTransaction]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<GiftTransaction>> insert(
    _i1.Session session,
    List<GiftTransaction> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<GiftTransaction>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [GiftTransaction] and returns the inserted row.
  ///
  /// The returned [GiftTransaction] will have its `id` field set.
  Future<GiftTransaction> insertRow(
    _i1.Session session,
    GiftTransaction row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<GiftTransaction>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [GiftTransaction]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<GiftTransaction>> update(
    _i1.Session session,
    List<GiftTransaction> rows, {
    _i1.ColumnSelections<GiftTransactionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<GiftTransaction>(
      rows,
      columns: columns?.call(GiftTransaction.t),
      transaction: transaction,
    );
  }

  /// Updates a single [GiftTransaction]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<GiftTransaction> updateRow(
    _i1.Session session,
    GiftTransaction row, {
    _i1.ColumnSelections<GiftTransactionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<GiftTransaction>(
      row,
      columns: columns?.call(GiftTransaction.t),
      transaction: transaction,
    );
  }

  /// Updates a single [GiftTransaction] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<GiftTransaction?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<GiftTransactionUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<GiftTransaction>(
      id,
      columnValues: columnValues(GiftTransaction.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [GiftTransaction]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<GiftTransaction>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<GiftTransactionUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<GiftTransactionTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<GiftTransactionTable>? orderBy,
    _i1.OrderByListBuilder<GiftTransactionTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<GiftTransaction>(
      columnValues: columnValues(GiftTransaction.t.updateTable),
      where: where(GiftTransaction.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(GiftTransaction.t),
      orderByList: orderByList?.call(GiftTransaction.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [GiftTransaction]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<GiftTransaction>> delete(
    _i1.Session session,
    List<GiftTransaction> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<GiftTransaction>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [GiftTransaction].
  Future<GiftTransaction> deleteRow(
    _i1.Session session,
    GiftTransaction row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<GiftTransaction>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<GiftTransaction>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<GiftTransactionTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<GiftTransaction>(
      where: where(GiftTransaction.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<GiftTransactionTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<GiftTransaction>(
      where: where?.call(GiftTransaction.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
