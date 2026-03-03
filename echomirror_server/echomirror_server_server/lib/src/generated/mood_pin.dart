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

abstract class MoodPin
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  MoodPin._({
    this.id,
    required this.sentiment,
    required this.gridLat,
    required this.gridLon,
    required this.timestamp,
    this.expiresAt,
  });

  factory MoodPin({
    int? id,
    required String sentiment,
    required double gridLat,
    required double gridLon,
    required DateTime timestamp,
    DateTime? expiresAt,
  }) = _MoodPinImpl;

  factory MoodPin.fromJson(Map<String, dynamic> jsonSerialization) {
    return MoodPin(
      id: jsonSerialization['id'] as int?,
      sentiment: jsonSerialization['sentiment'] as String,
      gridLat: (jsonSerialization['gridLat'] as num).toDouble(),
      gridLon: (jsonSerialization['gridLon'] as num).toDouble(),
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
    );
  }

  static final t = MoodPinTable();

  static const db = MoodPinRepository._();

  @override
  int? id;

  String sentiment;

  double gridLat;

  double gridLon;

  DateTime timestamp;

  DateTime? expiresAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [MoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MoodPin copyWith({
    int? id,
    String? sentiment,
    double? gridLat,
    double? gridLon,
    DateTime? timestamp,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodPin',
      if (id != null) 'id': id,
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
      'timestamp': timestamp.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MoodPin',
      if (id != null) 'id': id,
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
      'timestamp': timestamp.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
    };
  }

  static MoodPinInclude include() {
    return MoodPinInclude._();
  }

  static MoodPinIncludeList includeList({
    _i1.WhereExpressionBuilder<MoodPinTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodPinTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodPinTable>? orderByList,
    MoodPinInclude? include,
  }) {
    return MoodPinIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MoodPin.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(MoodPin.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MoodPinImpl extends MoodPin {
  _MoodPinImpl({
    int? id,
    required String sentiment,
    required double gridLat,
    required double gridLon,
    required DateTime timestamp,
    DateTime? expiresAt,
  }) : super._(
         id: id,
         sentiment: sentiment,
         gridLat: gridLat,
         gridLon: gridLon,
         timestamp: timestamp,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [MoodPin]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MoodPin copyWith({
    Object? id = _Undefined,
    String? sentiment,
    double? gridLat,
    double? gridLon,
    DateTime? timestamp,
    Object? expiresAt = _Undefined,
  }) {
    return MoodPin(
      id: id is int? ? id : this.id,
      sentiment: sentiment ?? this.sentiment,
      gridLat: gridLat ?? this.gridLat,
      gridLon: gridLon ?? this.gridLon,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt is DateTime? ? expiresAt : this.expiresAt,
    );
  }
}

class MoodPinUpdateTable extends _i1.UpdateTable<MoodPinTable> {
  MoodPinUpdateTable(super.table);

  _i1.ColumnValue<String, String> sentiment(String value) =>
      _i1.ColumnValue(table.sentiment, value);

  _i1.ColumnValue<double, double> gridLat(double value) =>
      _i1.ColumnValue(table.gridLat, value);

  _i1.ColumnValue<double, double> gridLon(double value) =>
      _i1.ColumnValue(table.gridLon, value);

  _i1.ColumnValue<DateTime, DateTime> timestamp(DateTime value) =>
      _i1.ColumnValue(table.timestamp, value);

  _i1.ColumnValue<DateTime, DateTime> expiresAt(DateTime? value) =>
      _i1.ColumnValue(table.expiresAt, value);
}

class MoodPinTable extends _i1.Table<int?> {
  MoodPinTable({super.tableRelation}) : super(tableName: 'mood_pins') {
    updateTable = MoodPinUpdateTable(this);
    sentiment = _i1.ColumnString('sentiment', this);
    gridLat = _i1.ColumnDouble('gridLat', this);
    gridLon = _i1.ColumnDouble('gridLon', this);
    timestamp = _i1.ColumnDateTime('timestamp', this);
    expiresAt = _i1.ColumnDateTime('expiresAt', this);
  }

  late final MoodPinUpdateTable updateTable;

  late final _i1.ColumnString sentiment;

  late final _i1.ColumnDouble gridLat;

  late final _i1.ColumnDouble gridLon;

  late final _i1.ColumnDateTime timestamp;

  late final _i1.ColumnDateTime expiresAt;

  @override
  List<_i1.Column> get columns => [
    id,
    sentiment,
    gridLat,
    gridLon,
    timestamp,
    expiresAt,
  ];
}

class MoodPinInclude extends _i1.IncludeObject {
  MoodPinInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => MoodPin.t;
}

class MoodPinIncludeList extends _i1.IncludeList {
  MoodPinIncludeList._({
    _i1.WhereExpressionBuilder<MoodPinTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MoodPin.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => MoodPin.t;
}

class MoodPinRepository {
  const MoodPinRepository._();

  /// Returns a list of [MoodPin]s matching the given query parameters.
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
  Future<List<MoodPin>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodPinTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodPinTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodPinTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<MoodPin>(
      where: where?.call(MoodPin.t),
      orderBy: orderBy?.call(MoodPin.t),
      orderByList: orderByList?.call(MoodPin.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [MoodPin] matching the given query parameters.
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
  Future<MoodPin?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodPinTable>? where,
    int? offset,
    _i1.OrderByBuilder<MoodPinTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<MoodPinTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<MoodPin>(
      where: where?.call(MoodPin.t),
      orderBy: orderBy?.call(MoodPin.t),
      orderByList: orderByList?.call(MoodPin.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [MoodPin] by its [id] or null if no such row exists.
  Future<MoodPin?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<MoodPin>(id, transaction: transaction);
  }

  /// Inserts all [MoodPin]s in the list and returns the inserted rows.
  ///
  /// The returned [MoodPin]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<MoodPin>> insert(
    _i1.Session session,
    List<MoodPin> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<MoodPin>(rows, transaction: transaction);
  }

  /// Inserts a single [MoodPin] and returns the inserted row.
  ///
  /// The returned [MoodPin] will have its `id` field set.
  Future<MoodPin> insertRow(
    _i1.Session session,
    MoodPin row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<MoodPin>(row, transaction: transaction);
  }

  /// Updates all [MoodPin]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<MoodPin>> update(
    _i1.Session session,
    List<MoodPin> rows, {
    _i1.ColumnSelections<MoodPinTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<MoodPin>(
      rows,
      columns: columns?.call(MoodPin.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MoodPin]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MoodPin> updateRow(
    _i1.Session session,
    MoodPin row, {
    _i1.ColumnSelections<MoodPinTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<MoodPin>(
      row,
      columns: columns?.call(MoodPin.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MoodPin] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MoodPin?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<MoodPinUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<MoodPin>(
      id,
      columnValues: columnValues(MoodPin.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MoodPin]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<MoodPin>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<MoodPinUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<MoodPinTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<MoodPinTable>? orderBy,
    _i1.OrderByListBuilder<MoodPinTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<MoodPin>(
      columnValues: columnValues(MoodPin.t.updateTable),
      where: where(MoodPin.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MoodPin.t),
      orderByList: orderByList?.call(MoodPin.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [MoodPin]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<MoodPin>> delete(
    _i1.Session session,
    List<MoodPin> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<MoodPin>(rows, transaction: transaction);
  }

  /// Deletes a single [MoodPin].
  Future<MoodPin> deleteRow(
    _i1.Session session,
    MoodPin row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MoodPin>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<MoodPin>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<MoodPinTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<MoodPin>(
      where: where(MoodPin.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<MoodPinTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<MoodPin>(
      where: where?.call(MoodPin.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
