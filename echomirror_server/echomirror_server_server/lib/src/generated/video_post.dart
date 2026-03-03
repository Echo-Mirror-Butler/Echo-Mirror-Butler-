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

abstract class VideoPost
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  VideoPost._({
    this.id,
    required this.videoUrl,
    required this.moodTag,
    required this.timestamp,
    required this.expiresAt,
  });

  factory VideoPost({
    int? id,
    required String videoUrl,
    required String moodTag,
    required DateTime timestamp,
    required DateTime expiresAt,
  }) = _VideoPostImpl;

  factory VideoPost.fromJson(Map<String, dynamic> jsonSerialization) {
    return VideoPost(
      id: jsonSerialization['id'] as int?,
      videoUrl: jsonSerialization['videoUrl'] as String,
      moodTag: jsonSerialization['moodTag'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  static final t = VideoPostTable();

  static const db = VideoPostRepository._();

  @override
  int? id;

  String videoUrl;

  String moodTag;

  DateTime timestamp;

  DateTime expiresAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [VideoPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  VideoPost copyWith({
    int? id,
    String? videoUrl,
    String? moodTag,
    DateTime? timestamp,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VideoPost',
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VideoPost',
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  static VideoPostInclude include() {
    return VideoPostInclude._();
  }

  static VideoPostIncludeList includeList({
    _i1.WhereExpressionBuilder<VideoPostTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoPostTable>? orderByList,
    VideoPostInclude? include,
  }) {
    return VideoPostIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VideoPost.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(VideoPost.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VideoPostImpl extends VideoPost {
  _VideoPostImpl({
    int? id,
    required String videoUrl,
    required String moodTag,
    required DateTime timestamp,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         videoUrl: videoUrl,
         moodTag: moodTag,
         timestamp: timestamp,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [VideoPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  VideoPost copyWith({
    Object? id = _Undefined,
    String? videoUrl,
    String? moodTag,
    DateTime? timestamp,
    DateTime? expiresAt,
  }) {
    return VideoPost(
      id: id is int? ? id : this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      moodTag: moodTag ?? this.moodTag,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class VideoPostUpdateTable extends _i1.UpdateTable<VideoPostTable> {
  VideoPostUpdateTable(super.table);

  _i1.ColumnValue<String, String> videoUrl(String value) =>
      _i1.ColumnValue(table.videoUrl, value);

  _i1.ColumnValue<String, String> moodTag(String value) =>
      _i1.ColumnValue(table.moodTag, value);

  _i1.ColumnValue<DateTime, DateTime> timestamp(DateTime value) =>
      _i1.ColumnValue(table.timestamp, value);

  _i1.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _i1.ColumnValue(table.expiresAt, value);
}

class VideoPostTable extends _i1.Table<int?> {
  VideoPostTable({super.tableRelation}) : super(tableName: 'video_posts') {
    updateTable = VideoPostUpdateTable(this);
    videoUrl = _i1.ColumnString('videoUrl', this);
    moodTag = _i1.ColumnString('moodTag', this);
    timestamp = _i1.ColumnDateTime('timestamp', this);
    expiresAt = _i1.ColumnDateTime('expiresAt', this);
  }

  late final VideoPostUpdateTable updateTable;

  late final _i1.ColumnString videoUrl;

  late final _i1.ColumnString moodTag;

  late final _i1.ColumnDateTime timestamp;

  late final _i1.ColumnDateTime expiresAt;

  @override
  List<_i1.Column> get columns => [id, videoUrl, moodTag, timestamp, expiresAt];
}

class VideoPostInclude extends _i1.IncludeObject {
  VideoPostInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => VideoPost.t;
}

class VideoPostIncludeList extends _i1.IncludeList {
  VideoPostIncludeList._({
    _i1.WhereExpressionBuilder<VideoPostTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(VideoPost.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => VideoPost.t;
}

class VideoPostRepository {
  const VideoPostRepository._();

  /// Returns a list of [VideoPost]s matching the given query parameters.
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
  Future<List<VideoPost>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoPostTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoPostTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VideoPost>(
      where: where?.call(VideoPost.t),
      orderBy: orderBy?.call(VideoPost.t),
      orderByList: orderByList?.call(VideoPost.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [VideoPost] matching the given query parameters.
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
  Future<VideoPost?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoPostTable>? where,
    int? offset,
    _i1.OrderByBuilder<VideoPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoPostTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<VideoPost>(
      where: where?.call(VideoPost.t),
      orderBy: orderBy?.call(VideoPost.t),
      orderByList: orderByList?.call(VideoPost.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [VideoPost] by its [id] or null if no such row exists.
  Future<VideoPost?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<VideoPost>(id, transaction: transaction);
  }

  /// Inserts all [VideoPost]s in the list and returns the inserted rows.
  ///
  /// The returned [VideoPost]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<VideoPost>> insert(
    _i1.Session session,
    List<VideoPost> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<VideoPost>(rows, transaction: transaction);
  }

  /// Inserts a single [VideoPost] and returns the inserted row.
  ///
  /// The returned [VideoPost] will have its `id` field set.
  Future<VideoPost> insertRow(
    _i1.Session session,
    VideoPost row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<VideoPost>(row, transaction: transaction);
  }

  /// Updates all [VideoPost]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<VideoPost>> update(
    _i1.Session session,
    List<VideoPost> rows, {
    _i1.ColumnSelections<VideoPostTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<VideoPost>(
      rows,
      columns: columns?.call(VideoPost.t),
      transaction: transaction,
    );
  }

  /// Updates a single [VideoPost]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<VideoPost> updateRow(
    _i1.Session session,
    VideoPost row, {
    _i1.ColumnSelections<VideoPostTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<VideoPost>(
      row,
      columns: columns?.call(VideoPost.t),
      transaction: transaction,
    );
  }

  /// Updates a single [VideoPost] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<VideoPost?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<VideoPostUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<VideoPost>(
      id,
      columnValues: columnValues(VideoPost.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [VideoPost]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<VideoPost>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<VideoPostUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<VideoPostTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoPostTable>? orderBy,
    _i1.OrderByListBuilder<VideoPostTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<VideoPost>(
      columnValues: columnValues(VideoPost.t.updateTable),
      where: where(VideoPost.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VideoPost.t),
      orderByList: orderByList?.call(VideoPost.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [VideoPost]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<VideoPost>> delete(
    _i1.Session session,
    List<VideoPost> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VideoPost>(rows, transaction: transaction);
  }

  /// Deletes a single [VideoPost].
  Future<VideoPost> deleteRow(
    _i1.Session session,
    VideoPost row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<VideoPost>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<VideoPost>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<VideoPostTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<VideoPost>(
      where: where(VideoPost.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoPostTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VideoPost>(
      where: where?.call(VideoPost.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
