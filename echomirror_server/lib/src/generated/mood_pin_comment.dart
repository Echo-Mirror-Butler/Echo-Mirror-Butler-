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

abstract class MoodPinComment
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  MoodPinComment._({
    this.id,
    required this.moodPinId,
    required this.text,
    required this.timestamp,
    this.userId,
  });

  factory MoodPinComment({
    int? id,
    required int moodPinId,
    required String text,
    required DateTime timestamp,
    int? userId,
  }) = _MoodPinCommentImpl;

  factory MoodPinComment.fromJson(Map<String, dynamic> jsonSerialization) {
    return MoodPinComment(
      id: jsonSerialization['id'] as int?,
      moodPinId: jsonSerialization['moodPinId'] as int,
      text: jsonSerialization['text'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      userId: jsonSerialization['userId'] as int?,
    );
  }

  static final t = MoodPinCommentTable();

  static const db = MoodPinCommentRepository._();

  @override
  int? id;

  int moodPinId;

  String text;

  DateTime timestamp;

  int? userId;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [MoodPinComment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MoodPinComment copyWith({
    int? id,
    int? moodPinId,
    String? text,
    DateTime? timestamp,
    int? userId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodPinComment',
      if (id != null) 'id': id,
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp.toJson(),
      if (userId != null) 'userId': userId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MoodPinComment',
      if (id != null) 'id': id,
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp.toJson(),
      if (userId != null) 'userId': userId,
    };
  }

  static MoodPinCommentInclude include() {
    return MoodPinCommentInclude._();
  }

  static MoodPinCommentIncludeList includeList({
    _i1.WhereExpressionBuilder<MoodPinCommentTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodPinCommentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodPinCommentTable>? orderByList,
    MoodPinCommentInclude? include,
  }) {
    return MoodPinCommentIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MoodPinComment.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(MoodPinComment.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MoodPinCommentImpl extends MoodPinComment {
  _MoodPinCommentImpl({
    int? id,
    required int moodPinId,
    required String text,
    required DateTime timestamp,
    int? userId,
  }) : super._(
         id: id,
         moodPinId: moodPinId,
         text: text,
         timestamp: timestamp,
         userId: userId,
       );

  /// Returns a shallow copy of this [MoodPinComment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MoodPinComment copyWith({
    Object? id = _Undefined,
    int? moodPinId,
    String? text,
    DateTime? timestamp,
    Object? userId = _Undefined,
  }) {
    return MoodPinComment(
      id: id is int? ? id : this.id,
      moodPinId: moodPinId ?? this.moodPinId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      userId: userId is int? ? userId : this.userId,
    );
  }
}

class MoodPinCommentUpdateTable extends _i1.UpdateTable<MoodPinCommentTable> {
  MoodPinCommentUpdateTable(super.table);

  _i1.ColumnValue<int, int> moodPinId(int value) => _i1.ColumnValue(
    table.moodPinId,
    value,
  );

  _i1.ColumnValue<String, String> text(String value) => _i1.ColumnValue(
    table.text,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> timestamp(DateTime value) =>
      _i1.ColumnValue(
        table.timestamp,
        value,
      );

  _i1.ColumnValue<int, int> userId(int? value) => _i1.ColumnValue(
    table.userId,
    value,
  );
}

class MoodPinCommentTable extends _i1.Table<int?> {
  MoodPinCommentTable({super.tableRelation})
    : super(tableName: 'mood_pin_comments') {
    updateTable = MoodPinCommentUpdateTable(this);
    moodPinId = _i1.ColumnInt(
      'moodPinId',
      this,
    );
    text = _i1.ColumnString(
      'text',
      this,
    );
    timestamp = _i1.ColumnDateTime(
      'timestamp',
      this,
    );
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
  }

  late final MoodPinCommentUpdateTable updateTable;

  late final _i1.ColumnInt moodPinId;

  late final _i1.ColumnString text;

  late final _i1.ColumnDateTime timestamp;

  late final _i1.ColumnInt userId;

  @override
  List<_i1.Column> get columns => [
    id,
    moodPinId,
    text,
    timestamp,
    userId,
  ];
}

class MoodPinCommentInclude extends _i1.IncludeObject {
  MoodPinCommentInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => MoodPinComment.t;
}

class MoodPinCommentIncludeList extends _i1.IncludeList {
  MoodPinCommentIncludeList._({
    _i1.WhereExpressionBuilder<MoodPinCommentTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MoodPinComment.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => MoodPinComment.t;
}

class MoodPinCommentRepository {
  const MoodPinCommentRepository._();

  /// Returns a list of [MoodPinComment]s matching the given query parameters.
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
  Future<List<MoodPinComment>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodPinCommentTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodPinCommentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodPinCommentTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<MoodPinComment>(
      where: where?.call(MoodPinComment.t),
      orderBy: orderBy?.call(MoodPinComment.t),
      orderByList: orderByList?.call(MoodPinComment.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [MoodPinComment] matching the given query parameters.
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
  Future<MoodPinComment?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodPinCommentTable>? where,
    int? offset,
    _i1.OrderByBuilder<MoodPinCommentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodPinCommentTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<MoodPinComment>(
      where: where?.call(MoodPinComment.t),
      orderBy: orderBy?.call(MoodPinComment.t),
      orderByList: orderByList?.call(MoodPinComment.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [MoodPinComment] by its [id] or null if no such row exists.
  Future<MoodPinComment?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<MoodPinComment>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [MoodPinComment]s in the list and returns the inserted rows.
  ///
  /// The returned [MoodPinComment]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<MoodPinComment>> insert(
    _i1.Session session,
    List<MoodPinComment> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<MoodPinComment>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [MoodPinComment] and returns the inserted row.
  ///
  /// The returned [MoodPinComment] will have its `id` field set.
  Future<MoodPinComment> insertRow(
    _i1.Session session,
    MoodPinComment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<MoodPinComment>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [MoodPinComment]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<MoodPinComment>> update(
    _i1.Session session,
    List<MoodPinComment> rows, {
    _i1.ColumnSelections<MoodPinCommentTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<MoodPinComment>(
      rows,
      columns: columns?.call(MoodPinComment.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MoodPinComment]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MoodPinComment> updateRow(
    _i1.Session session,
    MoodPinComment row, {
    _i1.ColumnSelections<MoodPinCommentTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<MoodPinComment>(
      row,
      columns: columns?.call(MoodPinComment.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MoodPinComment] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MoodPinComment?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<MoodPinCommentUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<MoodPinComment>(
      id,
      columnValues: columnValues(MoodPinComment.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MoodPinComment]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<MoodPinComment>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<MoodPinCommentUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<MoodPinCommentTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodPinCommentTable>? orderBy,
    _i1.OrderByListBuilder<MoodPinCommentTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<MoodPinComment>(
      columnValues: columnValues(MoodPinComment.t.updateTable),
      where: where(MoodPinComment.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MoodPinComment.t),
      orderByList: orderByList?.call(MoodPinComment.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [MoodPinComment]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<MoodPinComment>> delete(
    _i1.Session session,
    List<MoodPinComment> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<MoodPinComment>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [MoodPinComment].
  Future<MoodPinComment> deleteRow(
    _i1.Session session,
    MoodPinComment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MoodPinComment>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<MoodPinComment>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<MoodPinCommentTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<MoodPinComment>(
      where: where(MoodPinComment.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodPinCommentTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<MoodPinComment>(
      where: where?.call(MoodPinComment.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
