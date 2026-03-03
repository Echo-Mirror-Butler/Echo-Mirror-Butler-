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
import 'package:echomirror_server_server/src/generated/protocol.dart' as _i2;

abstract class LogEntry
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  LogEntry._({
    this.id,
    required this.userId,
    required this.date,
    this.mood,
    required this.habits,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory LogEntry({
    int? id,
    required String userId,
    required DateTime date,
    int? mood,
    required List<String> habits,
    String? notes,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _LogEntryImpl;

  factory LogEntry.fromJson(Map<String, dynamic> jsonSerialization) {
    return LogEntry(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as String,
      date: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['date']),
      mood: jsonSerialization['mood'] as int?,
      habits: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['habits'],
      ),
      notes: jsonSerialization['notes'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = LogEntryTable();

  static const db = LogEntryRepository._();

  @override
  int? id;

  /// The user ID who owns this entry
  String userId;

  /// The date of the log entry
  DateTime date;

  /// Mood rating from 1-5 (optional)
  int? mood;

  /// List of habits for this day
  List<String> habits;

  /// Optional notes about the day
  String? notes;

  /// When the entry was created
  DateTime createdAt;

  /// When the entry was last updated (optional)
  DateTime? updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [LogEntry]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  LogEntry copyWith({
    int? id,
    String? userId,
    DateTime? date,
    int? mood,
    List<String>? habits,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'LogEntry',
      if (id != null) 'id': id,
      'userId': userId,
      'date': date.toJson(),
      if (mood != null) 'mood': mood,
      'habits': habits.toJson(),
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'LogEntry',
      if (id != null) 'id': id,
      'userId': userId,
      'date': date.toJson(),
      if (mood != null) 'mood': mood,
      'habits': habits.toJson(),
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
    };
  }

  static LogEntryInclude include() {
    return LogEntryInclude._();
  }

  static LogEntryIncludeList includeList({
    _i1.WhereExpressionBuilder<LogEntryTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<LogEntryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<LogEntryTable>? orderByList,
    LogEntryInclude? include,
  }) {
    return LogEntryIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(LogEntry.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(LogEntry.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _LogEntryImpl extends LogEntry {
  _LogEntryImpl({
    int? id,
    required String userId,
    required DateTime date,
    int? mood,
    required List<String> habits,
    String? notes,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         date: date,
         mood: mood,
         habits: habits,
         notes: notes,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [LogEntry]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  LogEntry copyWith({
    Object? id = _Undefined,
    String? userId,
    DateTime? date,
    Object? mood = _Undefined,
    List<String>? habits,
    Object? notes = _Undefined,
    DateTime? createdAt,
    Object? updatedAt = _Undefined,
  }) {
    return LogEntry(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      mood: mood is int? ? mood : this.mood,
      habits: habits ?? this.habits.map((e0) => e0).toList(),
      notes: notes is String? ? notes : this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
    );
  }
}

class LogEntryUpdateTable extends _i1.UpdateTable<LogEntryTable> {
  LogEntryUpdateTable(super.table);

  _i1.ColumnValue<String, String> userId(String value) =>
      _i1.ColumnValue(table.userId, value);

  _i1.ColumnValue<DateTime, DateTime> date(DateTime value) =>
      _i1.ColumnValue(table.date, value);

  _i1.ColumnValue<int, int> mood(int? value) =>
      _i1.ColumnValue(table.mood, value);

  _i1.ColumnValue<List<String>, List<String>> habits(List<String> value) =>
      _i1.ColumnValue(table.habits, value);

  _i1.ColumnValue<String, String> notes(String? value) =>
      _i1.ColumnValue(table.notes, value);

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(table.createdAt, value);

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime? value) =>
      _i1.ColumnValue(table.updatedAt, value);
}

class LogEntryTable extends _i1.Table<int?> {
  LogEntryTable({super.tableRelation}) : super(tableName: 'log_entries') {
    updateTable = LogEntryUpdateTable(this);
    userId = _i1.ColumnString('userId', this);
    date = _i1.ColumnDateTime('date', this);
    mood = _i1.ColumnInt('mood', this);
    habits = _i1.ColumnSerializable<List<String>>('habits', this);
    notes = _i1.ColumnString('notes', this);
    createdAt = _i1.ColumnDateTime('createdAt', this);
    updatedAt = _i1.ColumnDateTime('updatedAt', this);
  }

  late final LogEntryUpdateTable updateTable;

  /// The user ID who owns this entry
  late final _i1.ColumnString userId;

  /// The date of the log entry
  late final _i1.ColumnDateTime date;

  /// Mood rating from 1-5 (optional)
  late final _i1.ColumnInt mood;

  /// List of habits for this day
  late final _i1.ColumnSerializable<List<String>> habits;

  /// Optional notes about the day
  late final _i1.ColumnString notes;

  /// When the entry was created
  late final _i1.ColumnDateTime createdAt;

  /// When the entry was last updated (optional)
  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    userId,
    date,
    mood,
    habits,
    notes,
    createdAt,
    updatedAt,
  ];
}

class LogEntryInclude extends _i1.IncludeObject {
  LogEntryInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => LogEntry.t;
}

class LogEntryIncludeList extends _i1.IncludeList {
  LogEntryIncludeList._({
    _i1.WhereExpressionBuilder<LogEntryTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(LogEntry.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => LogEntry.t;
}

class LogEntryRepository {
  const LogEntryRepository._();

  /// Returns a list of [LogEntry]s matching the given query parameters.
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
  Future<List<LogEntry>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<LogEntryTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<LogEntryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<LogEntryTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<LogEntry>(
      where: where?.call(LogEntry.t),
      orderBy: orderBy?.call(LogEntry.t),
      orderByList: orderByList?.call(LogEntry.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [LogEntry] matching the given query parameters.
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
  Future<LogEntry?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<LogEntryTable>? where,
    int? offset,
    _i1.OrderByBuilder<LogEntryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<LogEntryTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<LogEntry>(
      where: where?.call(LogEntry.t),
      orderBy: orderBy?.call(LogEntry.t),
      orderByList: orderByList?.call(LogEntry.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [LogEntry] by its [id] or null if no such row exists.
  Future<LogEntry?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<LogEntry>(id, transaction: transaction);
  }

  /// Inserts all [LogEntry]s in the list and returns the inserted rows.
  ///
  /// The returned [LogEntry]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<LogEntry>> insert(
    _i1.Session session,
    List<LogEntry> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<LogEntry>(rows, transaction: transaction);
  }

  /// Inserts a single [LogEntry] and returns the inserted row.
  ///
  /// The returned [LogEntry] will have its `id` field set.
  Future<LogEntry> insertRow(
    _i1.Session session,
    LogEntry row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<LogEntry>(row, transaction: transaction);
  }

  /// Updates all [LogEntry]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<LogEntry>> update(
    _i1.Session session,
    List<LogEntry> rows, {
    _i1.ColumnSelections<LogEntryTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<LogEntry>(
      rows,
      columns: columns?.call(LogEntry.t),
      transaction: transaction,
    );
  }

  /// Updates a single [LogEntry]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<LogEntry> updateRow(
    _i1.Session session,
    LogEntry row, {
    _i1.ColumnSelections<LogEntryTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<LogEntry>(
      row,
      columns: columns?.call(LogEntry.t),
      transaction: transaction,
    );
  }

  /// Updates a single [LogEntry] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<LogEntry?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<LogEntryUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<LogEntry>(
      id,
      columnValues: columnValues(LogEntry.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [LogEntry]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<LogEntry>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<LogEntryUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<LogEntryTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<LogEntryTable>? orderBy,
    _i1.OrderByListBuilder<LogEntryTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<LogEntry>(
      columnValues: columnValues(LogEntry.t.updateTable),
      where: where(LogEntry.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(LogEntry.t),
      orderByList: orderByList?.call(LogEntry.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [LogEntry]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<LogEntry>> delete(
    _i1.Session session,
    List<LogEntry> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<LogEntry>(rows, transaction: transaction);
  }

  /// Deletes a single [LogEntry].
  Future<LogEntry> deleteRow(
    _i1.Session session,
    LogEntry row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<LogEntry>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<LogEntry>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<LogEntryTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<LogEntry>(
      where: where(LogEntry.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<LogEntryTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<LogEntry>(
      where: where?.call(LogEntry.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
