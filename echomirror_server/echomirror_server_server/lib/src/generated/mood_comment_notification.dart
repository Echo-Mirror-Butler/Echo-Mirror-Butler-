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

abstract class MoodCommentNotification
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  MoodCommentNotification._({
    this.id,
    required this.userId,
    required this.moodPinId,
    required this.commentId,
    required this.commentText,
    required this.sentiment,
    required this.timestamp,
    required this.isRead,
  });

  factory MoodCommentNotification({
    int? id,
    required int userId,
    required int moodPinId,
    required int commentId,
    required String commentText,
    required String sentiment,
    required DateTime timestamp,
    required bool isRead,
  }) = _MoodCommentNotificationImpl;

  factory MoodCommentNotification.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return MoodCommentNotification(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      moodPinId: jsonSerialization['moodPinId'] as int,
      commentId: jsonSerialization['commentId'] as int,
      commentText: jsonSerialization['commentText'] as String,
      sentiment: jsonSerialization['sentiment'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      isRead: jsonSerialization['isRead'] as bool,
    );
  }

  static final t = MoodCommentNotificationTable();

  static const db = MoodCommentNotificationRepository._();

  @override
  int? id;

  int userId;

  int moodPinId;

  int commentId;

  String commentText;

  String sentiment;

  DateTime timestamp;

  bool isRead;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [MoodCommentNotification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MoodCommentNotification copyWith({
    int? id,
    int? userId,
    int? moodPinId,
    int? commentId,
    String? commentText,
    String? sentiment,
    DateTime? timestamp,
    bool? isRead,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodCommentNotification',
      if (id != null) 'id': id,
      'userId': userId,
      'moodPinId': moodPinId,
      'commentId': commentId,
      'commentText': commentText,
      'sentiment': sentiment,
      'timestamp': timestamp.toJson(),
      'isRead': isRead,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MoodCommentNotification',
      if (id != null) 'id': id,
      'userId': userId,
      'moodPinId': moodPinId,
      'commentId': commentId,
      'commentText': commentText,
      'sentiment': sentiment,
      'timestamp': timestamp.toJson(),
      'isRead': isRead,
    };
  }

  static MoodCommentNotificationInclude include() {
    return MoodCommentNotificationInclude._();
  }

  static MoodCommentNotificationIncludeList includeList({
    _i1.WhereExpressionBuilder<MoodCommentNotificationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodCommentNotificationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodCommentNotificationTable>? orderByList,
    MoodCommentNotificationInclude? include,
  }) {
    return MoodCommentNotificationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MoodCommentNotification.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(MoodCommentNotification.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MoodCommentNotificationImpl extends MoodCommentNotification {
  _MoodCommentNotificationImpl({
    int? id,
    required int userId,
    required int moodPinId,
    required int commentId,
    required String commentText,
    required String sentiment,
    required DateTime timestamp,
    required bool isRead,
  }) : super._(
         id: id,
         userId: userId,
         moodPinId: moodPinId,
         commentId: commentId,
         commentText: commentText,
         sentiment: sentiment,
         timestamp: timestamp,
         isRead: isRead,
       );

  /// Returns a shallow copy of this [MoodCommentNotification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MoodCommentNotification copyWith({
    Object? id = _Undefined,
    int? userId,
    int? moodPinId,
    int? commentId,
    String? commentText,
    String? sentiment,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return MoodCommentNotification(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      moodPinId: moodPinId ?? this.moodPinId,
      commentId: commentId ?? this.commentId,
      commentText: commentText ?? this.commentText,
      sentiment: sentiment ?? this.sentiment,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

class MoodCommentNotificationUpdateTable
    extends _i1.UpdateTable<MoodCommentNotificationTable> {
  MoodCommentNotificationUpdateTable(super.table);

  _i1.ColumnValue<int, int> userId(int value) =>
      _i1.ColumnValue(table.userId, value);

  _i1.ColumnValue<int, int> moodPinId(int value) =>
      _i1.ColumnValue(table.moodPinId, value);

  _i1.ColumnValue<int, int> commentId(int value) =>
      _i1.ColumnValue(table.commentId, value);

  _i1.ColumnValue<String, String> commentText(String value) =>
      _i1.ColumnValue(table.commentText, value);

  _i1.ColumnValue<String, String> sentiment(String value) =>
      _i1.ColumnValue(table.sentiment, value);

  _i1.ColumnValue<DateTime, DateTime> timestamp(DateTime value) =>
      _i1.ColumnValue(table.timestamp, value);

  _i1.ColumnValue<bool, bool> isRead(bool value) =>
      _i1.ColumnValue(table.isRead, value);
}

class MoodCommentNotificationTable extends _i1.Table<int?> {
  MoodCommentNotificationTable({super.tableRelation})
    : super(tableName: 'mood_comment_notifications') {
    updateTable = MoodCommentNotificationUpdateTable(this);
    userId = _i1.ColumnInt('userId', this);
    moodPinId = _i1.ColumnInt('moodPinId', this);
    commentId = _i1.ColumnInt('commentId', this);
    commentText = _i1.ColumnString('commentText', this);
    sentiment = _i1.ColumnString('sentiment', this);
    timestamp = _i1.ColumnDateTime('timestamp', this);
    isRead = _i1.ColumnBool('isRead', this);
  }

  late final MoodCommentNotificationUpdateTable updateTable;

  late final _i1.ColumnInt userId;

  late final _i1.ColumnInt moodPinId;

  late final _i1.ColumnInt commentId;

  late final _i1.ColumnString commentText;

  late final _i1.ColumnString sentiment;

  late final _i1.ColumnDateTime timestamp;

  late final _i1.ColumnBool isRead;

  @override
  List<_i1.Column> get columns => [
    id,
    userId,
    moodPinId,
    commentId,
    commentText,
    sentiment,
    timestamp,
    isRead,
  ];
}

class MoodCommentNotificationInclude extends _i1.IncludeObject {
  MoodCommentNotificationInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => MoodCommentNotification.t;
}

class MoodCommentNotificationIncludeList extends _i1.IncludeList {
  MoodCommentNotificationIncludeList._({
    _i1.WhereExpressionBuilder<MoodCommentNotificationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MoodCommentNotification.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => MoodCommentNotification.t;
}

class MoodCommentNotificationRepository {
  const MoodCommentNotificationRepository._();

  /// Returns a list of [MoodCommentNotification]s matching the given query parameters.
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
  Future<List<MoodCommentNotification>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodCommentNotificationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodCommentNotificationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodCommentNotificationTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<MoodCommentNotification>(
      where: where?.call(MoodCommentNotification.t),
      orderBy: orderBy?.call(MoodCommentNotification.t),
      orderByList: orderByList?.call(MoodCommentNotification.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [MoodCommentNotification] matching the given query parameters.
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
  Future<MoodCommentNotification?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodCommentNotificationTable>? where,
    int? offset,
    _i1.OrderByBuilder<MoodCommentNotificationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodCommentNotificationTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<MoodCommentNotification>(
      where: where?.call(MoodCommentNotification.t),
      orderBy: orderBy?.call(MoodCommentNotification.t),
      orderByList: orderByList?.call(MoodCommentNotification.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [MoodCommentNotification] by its [id] or null if no such row exists.
  Future<MoodCommentNotification?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<MoodCommentNotification>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [MoodCommentNotification]s in the list and returns the inserted rows.
  ///
  /// The returned [MoodCommentNotification]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<MoodCommentNotification>> insert(
    _i1.Session session,
    List<MoodCommentNotification> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<MoodCommentNotification>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [MoodCommentNotification] and returns the inserted row.
  ///
  /// The returned [MoodCommentNotification] will have its `id` field set.
  Future<MoodCommentNotification> insertRow(
    _i1.Session session,
    MoodCommentNotification row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<MoodCommentNotification>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [MoodCommentNotification]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<MoodCommentNotification>> update(
    _i1.Session session,
    List<MoodCommentNotification> rows, {
    _i1.ColumnSelections<MoodCommentNotificationTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<MoodCommentNotification>(
      rows,
      columns: columns?.call(MoodCommentNotification.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MoodCommentNotification]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MoodCommentNotification> updateRow(
    _i1.Session session,
    MoodCommentNotification row, {
    _i1.ColumnSelections<MoodCommentNotificationTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<MoodCommentNotification>(
      row,
      columns: columns?.call(MoodCommentNotification.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MoodCommentNotification] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MoodCommentNotification?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<MoodCommentNotificationUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<MoodCommentNotification>(
      id,
      columnValues: columnValues(MoodCommentNotification.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MoodCommentNotification]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<MoodCommentNotification>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<MoodCommentNotificationUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<MoodCommentNotificationTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodCommentNotificationTable>? orderBy,
    _i1.OrderByListBuilder<MoodCommentNotificationTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<MoodCommentNotification>(
      columnValues: columnValues(MoodCommentNotification.t.updateTable),
      where: where(MoodCommentNotification.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MoodCommentNotification.t),
      orderByList: orderByList?.call(MoodCommentNotification.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [MoodCommentNotification]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<MoodCommentNotification>> delete(
    _i1.Session session,
    List<MoodCommentNotification> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<MoodCommentNotification>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [MoodCommentNotification].
  Future<MoodCommentNotification> deleteRow(
    _i1.Session session,
    MoodCommentNotification row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MoodCommentNotification>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<MoodCommentNotification>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<MoodCommentNotificationTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<MoodCommentNotification>(
      where: where(MoodCommentNotification.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodCommentNotificationTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<MoodCommentNotification>(
      where: where?.call(MoodCommentNotification.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
