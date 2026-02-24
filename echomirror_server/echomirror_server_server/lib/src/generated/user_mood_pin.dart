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

abstract class UserMoodPin
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  UserMoodPin._({
    this.id,
    required this.userId,
    required this.moodPinId,
    required this.createdAt,
  });

  factory UserMoodPin({
    int? id,
    required int userId,
    required int moodPinId,
    required DateTime createdAt,
  }) = _UserMoodPinImpl;

  factory UserMoodPin.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserMoodPin(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      moodPinId: jsonSerialization['moodPinId'] as int,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = UserMoodPinTable();

  static const db = UserMoodPinRepository._();

  @override
  int? id;

  int userId;

  int moodPinId;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [UserMoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  UserMoodPin copyWith({
    int? id,
    int? userId,
    int? moodPinId,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserMoodPin',
      if (id != null) 'id': id,
      'userId': userId,
      'moodPinId': moodPinId,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserMoodPin',
      if (id != null) 'id': id,
      'userId': userId,
      'moodPinId': moodPinId,
      'createdAt': createdAt.toJson(),
    };
  }

  static UserMoodPinInclude include() {
    return UserMoodPinInclude._();
  }

  static UserMoodPinIncludeList includeList({
    _i1.WhereExpressionBuilder<UserMoodPinTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UserMoodPinTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<UserMoodPinTable>? orderByList,
    UserMoodPinInclude? include,
  }) {
    return UserMoodPinIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserMoodPin.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(UserMoodPin.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserMoodPinImpl extends UserMoodPin {
  _UserMoodPinImpl({
    int? id,
    required int userId,
    required int moodPinId,
    required DateTime createdAt,
  }) : super._(
         id: id,
         userId: userId,
         moodPinId: moodPinId,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [UserMoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  UserMoodPin copyWith({
    Object? id = _Undefined,
    int? userId,
    int? moodPinId,
    DateTime? createdAt,
  }) {
    return UserMoodPin(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      moodPinId: moodPinId ?? this.moodPinId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class UserMoodPinUpdateTable extends _i1.UpdateTable<UserMoodPinTable> {
  UserMoodPinUpdateTable(super.table);

  _i1.ColumnValue<int, int> userId(int value) =>
      _i1.ColumnValue(table.userId, value);

  _i1.ColumnValue<int, int> moodPinId(int value) =>
      _i1.ColumnValue(table.moodPinId, value);

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(table.createdAt, value);
}

class UserMoodPinTable extends _i1.Table<int?> {
  UserMoodPinTable({super.tableRelation}) : super(tableName: 'user_mood_pins') {
    updateTable = UserMoodPinUpdateTable(this);
    userId = _i1.ColumnInt('userId', this);
    moodPinId = _i1.ColumnInt('moodPinId', this);
    createdAt = _i1.ColumnDateTime('createdAt', this);
  }

  late final UserMoodPinUpdateTable updateTable;

  late final _i1.ColumnInt userId;

  late final _i1.ColumnInt moodPinId;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [id, userId, moodPinId, createdAt];
}

class UserMoodPinInclude extends _i1.IncludeObject {
  UserMoodPinInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => UserMoodPin.t;
}

class UserMoodPinIncludeList extends _i1.IncludeList {
  UserMoodPinIncludeList._({
    _i1.WhereExpressionBuilder<UserMoodPinTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UserMoodPin.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => UserMoodPin.t;
}

class UserMoodPinRepository {
  const UserMoodPinRepository._();

  /// Returns a list of [UserMoodPin]s matching the given query parameters.
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
  Future<List<UserMoodPin>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<UserMoodPinTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UserMoodPinTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<UserMoodPinTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<UserMoodPin>(
      where: where?.call(UserMoodPin.t),
      orderBy: orderBy?.call(UserMoodPin.t),
      orderByList: orderByList?.call(UserMoodPin.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [UserMoodPin] matching the given query parameters.
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
  Future<UserMoodPin?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<UserMoodPinTable>? where,
    int? offset,
    _i1.OrderByBuilder<UserMoodPinTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<UserMoodPinTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<UserMoodPin>(
      where: where?.call(UserMoodPin.t),
      orderBy: orderBy?.call(UserMoodPin.t),
      orderByList: orderByList?.call(UserMoodPin.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [UserMoodPin] by its [id] or null if no such row exists.
  Future<UserMoodPin?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<UserMoodPin>(id, transaction: transaction);
  }

  /// Inserts all [UserMoodPin]s in the list and returns the inserted rows.
  ///
  /// The returned [UserMoodPin]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<UserMoodPin>> insert(
    _i1.Session session,
    List<UserMoodPin> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<UserMoodPin>(rows, transaction: transaction);
  }

  /// Inserts a single [UserMoodPin] and returns the inserted row.
  ///
  /// The returned [UserMoodPin] will have its `id` field set.
  Future<UserMoodPin> insertRow(
    _i1.Session session,
    UserMoodPin row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<UserMoodPin>(row, transaction: transaction);
  }

  /// Updates all [UserMoodPin]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<UserMoodPin>> update(
    _i1.Session session,
    List<UserMoodPin> rows, {
    _i1.ColumnSelections<UserMoodPinTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<UserMoodPin>(
      rows,
      columns: columns?.call(UserMoodPin.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UserMoodPin]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UserMoodPin> updateRow(
    _i1.Session session,
    UserMoodPin row, {
    _i1.ColumnSelections<UserMoodPinTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<UserMoodPin>(
      row,
      columns: columns?.call(UserMoodPin.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UserMoodPin] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UserMoodPin?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<UserMoodPinUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<UserMoodPin>(
      id,
      columnValues: columnValues(UserMoodPin.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UserMoodPin]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<UserMoodPin>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<UserMoodPinUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<UserMoodPinTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UserMoodPinTable>? orderBy,
    _i1.OrderByListBuilder<UserMoodPinTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<UserMoodPin>(
      columnValues: columnValues(UserMoodPin.t.updateTable),
      where: where(UserMoodPin.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserMoodPin.t),
      orderByList: orderByList?.call(UserMoodPin.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [UserMoodPin]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<UserMoodPin>> delete(
    _i1.Session session,
    List<UserMoodPin> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<UserMoodPin>(rows, transaction: transaction);
  }

  /// Deletes a single [UserMoodPin].
  Future<UserMoodPin> deleteRow(
    _i1.Session session,
    UserMoodPin row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UserMoodPin>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<UserMoodPin>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<UserMoodPinTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<UserMoodPin>(
      where: where(UserMoodPin.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<UserMoodPinTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<UserMoodPin>(
      where: where?.call(UserMoodPin.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
