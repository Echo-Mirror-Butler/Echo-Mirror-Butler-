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

abstract class VideoSession
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  VideoSession._({
    this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    required this.title,
    required this.createdAt,
    required this.expiresAt,
    required this.participantCount,
    required this.isVideoEnabled,
    required this.isVoiceOnly,
    required this.isActive,
  });

  factory VideoSession({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    required DateTime createdAt,
    required DateTime expiresAt,
    required int participantCount,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    required bool isActive,
  }) = _VideoSessionImpl;

  factory VideoSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return VideoSession(
      id: jsonSerialization['id'] as int?,
      hostId: jsonSerialization['hostId'] as String,
      hostName: jsonSerialization['hostName'] as String,
      hostAvatarUrl: jsonSerialization['hostAvatarUrl'] as String?,
      title: jsonSerialization['title'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      participantCount: jsonSerialization['participantCount'] as int,
      isVideoEnabled: jsonSerialization['isVideoEnabled'] as bool,
      isVoiceOnly: jsonSerialization['isVoiceOnly'] as bool,
      isActive: jsonSerialization['isActive'] as bool,
    );
  }

  static final t = VideoSessionTable();

  static const db = VideoSessionRepository._();

  @override
  int? id;

  String hostId;

  String hostName;

  String? hostAvatarUrl;

  String title;

  DateTime createdAt;

  DateTime expiresAt;

  int participantCount;

  bool isVideoEnabled;

  bool isVoiceOnly;

  bool isActive;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [VideoSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  VideoSession copyWith({
    int? id,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? title,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? participantCount,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isActive,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VideoSession',
      if (id != null) 'id': id,
      'hostId': hostId,
      'hostName': hostName,
      if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'participantCount': participantCount,
      'isVideoEnabled': isVideoEnabled,
      'isVoiceOnly': isVoiceOnly,
      'isActive': isActive,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VideoSession',
      if (id != null) 'id': id,
      'hostId': hostId,
      'hostName': hostName,
      if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'participantCount': participantCount,
      'isVideoEnabled': isVideoEnabled,
      'isVoiceOnly': isVoiceOnly,
      'isActive': isActive,
    };
  }

  static VideoSessionInclude include() {
    return VideoSessionInclude._();
  }

  static VideoSessionIncludeList includeList({
    _i1.WhereExpressionBuilder<VideoSessionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoSessionTable>? orderByList,
    VideoSessionInclude? include,
  }) {
    return VideoSessionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VideoSession.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(VideoSession.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VideoSessionImpl extends VideoSession {
  _VideoSessionImpl({
    int? id,
    required String hostId,
    required String hostName,
    String? hostAvatarUrl,
    required String title,
    required DateTime createdAt,
    required DateTime expiresAt,
    required int participantCount,
    required bool isVideoEnabled,
    required bool isVoiceOnly,
    required bool isActive,
  }) : super._(
         id: id,
         hostId: hostId,
         hostName: hostName,
         hostAvatarUrl: hostAvatarUrl,
         title: title,
         createdAt: createdAt,
         expiresAt: expiresAt,
         participantCount: participantCount,
         isVideoEnabled: isVideoEnabled,
         isVoiceOnly: isVoiceOnly,
         isActive: isActive,
       );

  /// Returns a shallow copy of this [VideoSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  VideoSession copyWith({
    Object? id = _Undefined,
    String? hostId,
    String? hostName,
    Object? hostAvatarUrl = _Undefined,
    String? title,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? participantCount,
    bool? isVideoEnabled,
    bool? isVoiceOnly,
    bool? isActive,
  }) {
    return VideoSession(
      id: id is int? ? id : this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl is String?
          ? hostAvatarUrl
          : this.hostAvatarUrl,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      participantCount: participantCount ?? this.participantCount,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isVoiceOnly: isVoiceOnly ?? this.isVoiceOnly,
      isActive: isActive ?? this.isActive,
    );
  }
}

class VideoSessionUpdateTable extends _i1.UpdateTable<VideoSessionTable> {
  VideoSessionUpdateTable(super.table);

  _i1.ColumnValue<String, String> hostId(String value) =>
      _i1.ColumnValue(table.hostId, value);

  _i1.ColumnValue<String, String> hostName(String value) =>
      _i1.ColumnValue(table.hostName, value);

  _i1.ColumnValue<String, String> hostAvatarUrl(String? value) =>
      _i1.ColumnValue(table.hostAvatarUrl, value);

  _i1.ColumnValue<String, String> title(String value) =>
      _i1.ColumnValue(table.title, value);

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(table.createdAt, value);

  _i1.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _i1.ColumnValue(table.expiresAt, value);

  _i1.ColumnValue<int, int> participantCount(int value) =>
      _i1.ColumnValue(table.participantCount, value);

  _i1.ColumnValue<bool, bool> isVideoEnabled(bool value) =>
      _i1.ColumnValue(table.isVideoEnabled, value);

  _i1.ColumnValue<bool, bool> isVoiceOnly(bool value) =>
      _i1.ColumnValue(table.isVoiceOnly, value);

  _i1.ColumnValue<bool, bool> isActive(bool value) =>
      _i1.ColumnValue(table.isActive, value);
}

class VideoSessionTable extends _i1.Table<int?> {
  VideoSessionTable({super.tableRelation})
    : super(tableName: 'video_sessions') {
    updateTable = VideoSessionUpdateTable(this);
    hostId = _i1.ColumnString('hostId', this);
    hostName = _i1.ColumnString('hostName', this);
    hostAvatarUrl = _i1.ColumnString('hostAvatarUrl', this);
    title = _i1.ColumnString('title', this);
    createdAt = _i1.ColumnDateTime('createdAt', this);
    expiresAt = _i1.ColumnDateTime('expiresAt', this);
    participantCount = _i1.ColumnInt('participantCount', this);
    isVideoEnabled = _i1.ColumnBool('isVideoEnabled', this);
    isVoiceOnly = _i1.ColumnBool('isVoiceOnly', this);
    isActive = _i1.ColumnBool('isActive', this);
  }

  late final VideoSessionUpdateTable updateTable;

  late final _i1.ColumnString hostId;

  late final _i1.ColumnString hostName;

  late final _i1.ColumnString hostAvatarUrl;

  late final _i1.ColumnString title;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime expiresAt;

  late final _i1.ColumnInt participantCount;

  late final _i1.ColumnBool isVideoEnabled;

  late final _i1.ColumnBool isVoiceOnly;

  late final _i1.ColumnBool isActive;

  @override
  List<_i1.Column> get columns => [
    id,
    hostId,
    hostName,
    hostAvatarUrl,
    title,
    createdAt,
    expiresAt,
    participantCount,
    isVideoEnabled,
    isVoiceOnly,
    isActive,
  ];
}

class VideoSessionInclude extends _i1.IncludeObject {
  VideoSessionInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => VideoSession.t;
}

class VideoSessionIncludeList extends _i1.IncludeList {
  VideoSessionIncludeList._({
    _i1.WhereExpressionBuilder<VideoSessionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(VideoSession.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => VideoSession.t;
}

class VideoSessionRepository {
  const VideoSessionRepository._();

  /// Returns a list of [VideoSession]s matching the given query parameters.
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
  Future<List<VideoSession>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoSessionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoSessionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VideoSession>(
      where: where?.call(VideoSession.t),
      orderBy: orderBy?.call(VideoSession.t),
      orderByList: orderByList?.call(VideoSession.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [VideoSession] matching the given query parameters.
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
  Future<VideoSession?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoSessionTable>? where,
    int? offset,
    _i1.OrderByBuilder<VideoSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoSessionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<VideoSession>(
      where: where?.call(VideoSession.t),
      orderBy: orderBy?.call(VideoSession.t),
      orderByList: orderByList?.call(VideoSession.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [VideoSession] by its [id] or null if no such row exists.
  Future<VideoSession?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<VideoSession>(id, transaction: transaction);
  }

  /// Inserts all [VideoSession]s in the list and returns the inserted rows.
  ///
  /// The returned [VideoSession]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<VideoSession>> insert(
    _i1.Session session,
    List<VideoSession> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<VideoSession>(rows, transaction: transaction);
  }

  /// Inserts a single [VideoSession] and returns the inserted row.
  ///
  /// The returned [VideoSession] will have its `id` field set.
  Future<VideoSession> insertRow(
    _i1.Session session,
    VideoSession row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<VideoSession>(row, transaction: transaction);
  }

  /// Updates all [VideoSession]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<VideoSession>> update(
    _i1.Session session,
    List<VideoSession> rows, {
    _i1.ColumnSelections<VideoSessionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<VideoSession>(
      rows,
      columns: columns?.call(VideoSession.t),
      transaction: transaction,
    );
  }

  /// Updates a single [VideoSession]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<VideoSession> updateRow(
    _i1.Session session,
    VideoSession row, {
    _i1.ColumnSelections<VideoSessionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<VideoSession>(
      row,
      columns: columns?.call(VideoSession.t),
      transaction: transaction,
    );
  }

  /// Updates a single [VideoSession] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<VideoSession?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<VideoSessionUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<VideoSession>(
      id,
      columnValues: columnValues(VideoSession.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [VideoSession]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<VideoSession>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<VideoSessionUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<VideoSessionTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoSessionTable>? orderBy,
    _i1.OrderByListBuilder<VideoSessionTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<VideoSession>(
      columnValues: columnValues(VideoSession.t.updateTable),
      where: where(VideoSession.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VideoSession.t),
      orderByList: orderByList?.call(VideoSession.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [VideoSession]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<VideoSession>> delete(
    _i1.Session session,
    List<VideoSession> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VideoSession>(rows, transaction: transaction);
  }

  /// Deletes a single [VideoSession].
  Future<VideoSession> deleteRow(
    _i1.Session session,
    VideoSession row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<VideoSession>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<VideoSession>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<VideoSessionTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<VideoSession>(
      where: where(VideoSession.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoSessionTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VideoSession>(
      where: where?.call(VideoSession.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
