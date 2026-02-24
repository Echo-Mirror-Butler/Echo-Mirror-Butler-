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

abstract class ScheduledSession
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ScheduledSession._({
    this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    required this.title,
    this.description,
    required this.scheduledTime,
    required this.createdAt,
    required this.isVideoEnabled,
    required this.isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    this.actualSessionId,
  }) : isNotified = isNotified ?? false,
       isCancelled = isCancelled ?? false;

  factory ScheduledSession({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    String? description,
    required DateTime scheduledTime,
    required DateTime createdAt,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    String? actualSessionId,
  }) = _ScheduledSessionImpl;

  factory ScheduledSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScheduledSession(
      id: jsonSerialization['id'] as int?,
      hostId: jsonSerialization['hostId'] as String,
      hostName: jsonSerialization['hostName'] as String,
      hostAvatarUrl: jsonSerialization['hostAvatarUrl'] as String?,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String?,
      scheduledTime: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['scheduledTime'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      isVideoEnabled: jsonSerialization['isVideoEnabled'] as bool,
      isVoiceOnly: jsonSerialization['isVoiceOnly'] as bool,
      isNotified: jsonSerialization['isNotified'] as bool,
      isCancelled: jsonSerialization['isCancelled'] as bool,
      actualSessionId: jsonSerialization['actualSessionId'] as String?,
    );
  }

  static final t = ScheduledSessionTable();

  static const db = ScheduledSessionRepository._();

  @override
  int? id;

  String hostId;

  String hostName;

  String? hostAvatarUrl;

  String title;

  String? description;

  DateTime scheduledTime;

  DateTime createdAt;

  bool isVideoEnabled;

  bool isVoiceOnly;

  bool isNotified;

  bool isCancelled;

  String? actualSessionId;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ScheduledSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ScheduledSession copyWith({
    int? id,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? title,
    String? description,
    DateTime? scheduledTime,
    DateTime? createdAt,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    String? actualSessionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScheduledSession',
      if (id != null) 'id': id,
      'hostId': hostId,
      'hostName': hostName,
      if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      if (description != null) 'description': description,
      'scheduledTime': scheduledTime.toJson(),
      'createdAt': createdAt.toJson(),
      'isVideoEnabled': isVideoEnabled,
      'isVoiceOnly': isVoiceOnly,
      'isNotified': isNotified,
      'isCancelled': isCancelled,
      if (actualSessionId != null) 'actualSessionId': actualSessionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScheduledSession',
      if (id != null) 'id': id,
      'hostId': hostId,
      'hostName': hostName,
      if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      if (description != null) 'description': description,
      'scheduledTime': scheduledTime.toJson(),
      'createdAt': createdAt.toJson(),
      'isVideoEnabled': isVideoEnabled,
      'isVoiceOnly': isVoiceOnly,
      'isNotified': isNotified,
      'isCancelled': isCancelled,
      if (actualSessionId != null) 'actualSessionId': actualSessionId,
    };
  }

  static ScheduledSessionInclude include() {
    return ScheduledSessionInclude._();
  }

  static ScheduledSessionIncludeList includeList({
    _i1.WhereExpressionBuilder<ScheduledSessionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ScheduledSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ScheduledSessionTable>? orderByList,
    ScheduledSessionInclude? include,
  }) {
    return ScheduledSessionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScheduledSession.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ScheduledSession.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScheduledSessionImpl extends ScheduledSession {
  _ScheduledSessionImpl({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    String? description,
    required DateTime scheduledTime,
    required DateTime createdAt,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    String? actualSessionId,
  }) : super._(
         id: id,
         hostId: hostId,
         hostName: hostName,
         hostAvatarUrl: hostAvatarUrl,
         title: title,
         description: description,
         scheduledTime: scheduledTime,
         createdAt: createdAt,
         isVideoEnabled: isVideoEnabled,
         isVoiceOnly: isVoiceOnly,
         isNotified: isNotified,
         isCancelled: isCancelled,
         actualSessionId: actualSessionId,
       );

  /// Returns a shallow copy of this [ScheduledSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ScheduledSession copyWith({
    Object? id = _Undefined,
    String? hostId,
    String? hostName,
    Object? hostAvatarUrl = _Undefined,
    String? title,
    Object? description = _Undefined,
    DateTime? scheduledTime,
    DateTime? createdAt,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isNotified,
    bool? isCancelled,
    Object? actualSessionId = _Undefined,
  }) {
    return ScheduledSession(
      id: id is int? ? id : this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl is String?
          ? hostAvatarUrl
          : this.hostAvatarUrl,
      title: title ?? this.title,
      description: description is String? ? description : this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      createdAt: createdAt ?? this.createdAt,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isVoiceOnly: isVoiceOnly ?? this.isVoiceOnly,
      isNotified: isNotified ?? this.isNotified,
      isCancelled: isCancelled ?? this.isCancelled,
      actualSessionId: actualSessionId is String?
          ? actualSessionId
          : this.actualSessionId,
    );
  }
}

class ScheduledSessionUpdateTable
    extends _i1.UpdateTable<ScheduledSessionTable> {
  ScheduledSessionUpdateTable(super.table);

  _i1.ColumnValue<String, String> hostId(String value) =>
      _i1.ColumnValue(table.hostId, value);

  _i1.ColumnValue<String, String> hostName(String value) =>
      _i1.ColumnValue(table.hostName, value);

  _i1.ColumnValue<String, String> hostAvatarUrl(String? value) =>
      _i1.ColumnValue(table.hostAvatarUrl, value);

  _i1.ColumnValue<String, String> title(String value) =>
      _i1.ColumnValue(table.title, value);

  _i1.ColumnValue<String, String> description(String? value) =>
      _i1.ColumnValue(table.description, value);

  _i1.ColumnValue<DateTime, DateTime> scheduledTime(DateTime value) =>
      _i1.ColumnValue(table.scheduledTime, value);

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(table.createdAt, value);

  _i1.ColumnValue<bool, bool> isVideoEnabled(bool value) =>
      _i1.ColumnValue(table.isVideoEnabled, value);

  _i1.ColumnValue<bool, bool> isVoiceOnly(bool value) =>
      _i1.ColumnValue(table.isVoiceOnly, value);

  _i1.ColumnValue<bool, bool> isNotified(bool value) =>
      _i1.ColumnValue(table.isNotified, value);

  _i1.ColumnValue<bool, bool> isCancelled(bool value) =>
      _i1.ColumnValue(table.isCancelled, value);

  _i1.ColumnValue<String, String> actualSessionId(String? value) =>
      _i1.ColumnValue(table.actualSessionId, value);
}

class ScheduledSessionTable extends _i1.Table<int?> {
  ScheduledSessionTable({super.tableRelation})
    : super(tableName: 'scheduled_sessions') {
    updateTable = ScheduledSessionUpdateTable(this);
    hostId = _i1.ColumnString('hostId', this);
    hostName = _i1.ColumnString('hostName', this);
    hostAvatarUrl = _i1.ColumnString('hostAvatarUrl', this);
    title = _i1.ColumnString('title', this);
    description = _i1.ColumnString('description', this);
    scheduledTime = _i1.ColumnDateTime('scheduledTime', this);
    createdAt = _i1.ColumnDateTime('createdAt', this);
    isVideoEnabled = _i1.ColumnBool('isVideoEnabled', this);
    isVoiceOnly = _i1.ColumnBool('isVoiceOnly', this);
    isNotified = _i1.ColumnBool('isNotified', this, hasDefault: true);
    isCancelled = _i1.ColumnBool('isCancelled', this, hasDefault: true);
    actualSessionId = _i1.ColumnString('actualSessionId', this);
  }

  late final ScheduledSessionUpdateTable updateTable;

  late final _i1.ColumnString hostId;

  late final _i1.ColumnString hostName;

  late final _i1.ColumnString hostAvatarUrl;

  late final _i1.ColumnString title;

  late final _i1.ColumnString description;

  late final _i1.ColumnDateTime scheduledTime;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnBool isVideoEnabled;

  late final _i1.ColumnBool isVoiceOnly;

  late final _i1.ColumnBool isNotified;

  late final _i1.ColumnBool isCancelled;

  late final _i1.ColumnString actualSessionId;

  @override
  List<_i1.Column> get columns => [
    id,
    hostId,
    hostName,
    hostAvatarUrl,
    title,
    description,
    scheduledTime,
    createdAt,
    isVideoEnabled,
    isVoiceOnly,
    isNotified,
    isCancelled,
    actualSessionId,
  ];
}

class ScheduledSessionInclude extends _i1.IncludeObject {
  ScheduledSessionInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ScheduledSession.t;
}

class ScheduledSessionIncludeList extends _i1.IncludeList {
  ScheduledSessionIncludeList._({
    _i1.WhereExpressionBuilder<ScheduledSessionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScheduledSession.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ScheduledSession.t;
}

class ScheduledSessionRepository {
  const ScheduledSessionRepository._();

  /// Returns a list of [ScheduledSession]s matching the given query parameters.
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
  Future<List<ScheduledSession>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ScheduledSessionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ScheduledSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ScheduledSessionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<ScheduledSession>(
      where: where?.call(ScheduledSession.t),
      orderBy: orderBy?.call(ScheduledSession.t),
      orderByList: orderByList?.call(ScheduledSession.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [ScheduledSession] matching the given query parameters.
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
  Future<ScheduledSession?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ScheduledSessionTable>? where,
    int? offset,
    _i1.OrderByBuilder<ScheduledSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ScheduledSessionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<ScheduledSession>(
      where: where?.call(ScheduledSession.t),
      orderBy: orderBy?.call(ScheduledSession.t),
      orderByList: orderByList?.call(ScheduledSession.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [ScheduledSession] by its [id] or null if no such row exists.
  Future<ScheduledSession?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<ScheduledSession>(id, transaction: transaction);
  }

  /// Inserts all [ScheduledSession]s in the list and returns the inserted rows.
  ///
  /// The returned [ScheduledSession]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<ScheduledSession>> insert(
    _i1.Session session,
    List<ScheduledSession> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<ScheduledSession>(rows, transaction: transaction);
  }

  /// Inserts a single [ScheduledSession] and returns the inserted row.
  ///
  /// The returned [ScheduledSession] will have its `id` field set.
  Future<ScheduledSession> insertRow(
    _i1.Session session,
    ScheduledSession row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScheduledSession>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ScheduledSession]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ScheduledSession>> update(
    _i1.Session session,
    List<ScheduledSession> rows, {
    _i1.ColumnSelections<ScheduledSessionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ScheduledSession>(
      rows,
      columns: columns?.call(ScheduledSession.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScheduledSession]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScheduledSession> updateRow(
    _i1.Session session,
    ScheduledSession row, {
    _i1.ColumnSelections<ScheduledSessionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScheduledSession>(
      row,
      columns: columns?.call(ScheduledSession.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScheduledSession] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScheduledSession?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<ScheduledSessionUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ScheduledSession>(
      id,
      columnValues: columnValues(ScheduledSession.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScheduledSession]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ScheduledSession>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<ScheduledSessionUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<ScheduledSessionTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ScheduledSessionTable>? orderBy,
    _i1.OrderByListBuilder<ScheduledSessionTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ScheduledSession>(
      columnValues: columnValues(ScheduledSession.t.updateTable),
      where: where(ScheduledSession.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScheduledSession.t),
      orderByList: orderByList?.call(ScheduledSession.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ScheduledSession]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ScheduledSession>> delete(
    _i1.Session session,
    List<ScheduledSession> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ScheduledSession>(rows, transaction: transaction);
  }

  /// Deletes a single [ScheduledSession].
  Future<ScheduledSession> deleteRow(
    _i1.Session session,
    ScheduledSession row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScheduledSession>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ScheduledSession>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<ScheduledSessionTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ScheduledSession>(
      where: where(ScheduledSession.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ScheduledSessionTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ScheduledSession>(
      where: where?.call(ScheduledSession.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
