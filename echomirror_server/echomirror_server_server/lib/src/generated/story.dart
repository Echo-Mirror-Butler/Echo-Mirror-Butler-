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

abstract class Story implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Story._({
    this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.imageUrls,
    required this.createdAt,
    required this.expiresAt,
    int? viewCount,
    required this.viewedBy,
    bool? isActive,
  }) : viewCount = viewCount ?? 0,
       isActive = isActive ?? true;

  factory Story({
    int? id,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required List<String> imageUrls,
    required DateTime createdAt,
    required DateTime expiresAt,
    int? viewCount,
    required List<String> viewedBy,
    bool? isActive,
  }) = _StoryImpl;

  factory Story.fromJson(Map<String, dynamic> jsonSerialization) {
    return Story(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as String,
      userName: jsonSerialization['userName'] as String,
      userAvatarUrl: jsonSerialization['userAvatarUrl'] as String?,
      imageUrls: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['imageUrls'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      viewCount: jsonSerialization['viewCount'] as int,
      viewedBy: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['viewedBy'],
      ),
      isActive: jsonSerialization['isActive'] as bool,
    );
  }

  static final t = StoryTable();

  static const db = StoryRepository._();

  @override
  int? id;

  String userId;

  String userName;

  String? userAvatarUrl;

  List<String> imageUrls;

  DateTime createdAt;

  DateTime expiresAt;

  int viewCount;

  List<String> viewedBy;

  bool isActive;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Story copyWith({
    int? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    List<String>? viewedBy,
    bool? isActive,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Story',
      if (id != null) 'id': id,
      'userId': userId,
      'userName': userName,
      if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
      'imageUrls': imageUrls.toJson(),
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'viewCount': viewCount,
      'viewedBy': viewedBy.toJson(),
      'isActive': isActive,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Story',
      if (id != null) 'id': id,
      'userId': userId,
      'userName': userName,
      if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
      'imageUrls': imageUrls.toJson(),
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'viewCount': viewCount,
      'viewedBy': viewedBy.toJson(),
      'isActive': isActive,
    };
  }

  static StoryInclude include() {
    return StoryInclude._();
  }

  static StoryIncludeList includeList({
    _i1.WhereExpressionBuilder<StoryTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StoryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StoryTable>? orderByList,
    StoryInclude? include,
  }) {
    return StoryIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Story.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Story.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StoryImpl extends Story {
  _StoryImpl({
    int? id,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required List<String> imageUrls,
    required DateTime createdAt,
    required DateTime expiresAt,
    int? viewCount,
    required List<String> viewedBy,
    bool? isActive,
  }) : super._(
         id: id,
         userId: userId,
         userName: userName,
         userAvatarUrl: userAvatarUrl,
         imageUrls: imageUrls,
         createdAt: createdAt,
         expiresAt: expiresAt,
         viewCount: viewCount,
         viewedBy: viewedBy,
         isActive: isActive,
       );

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Story copyWith({
    Object? id = _Undefined,
    String? userId,
    String? userName,
    Object? userAvatarUrl = _Undefined,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    List<String>? viewedBy,
    bool? isActive,
  }) {
    return Story(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl is String?
          ? userAvatarUrl
          : this.userAvatarUrl,
      imageUrls: imageUrls ?? this.imageUrls.map((e0) => e0).toList(),
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewCount: viewCount ?? this.viewCount,
      viewedBy: viewedBy ?? this.viewedBy.map((e0) => e0).toList(),
      isActive: isActive ?? this.isActive,
    );
  }
}

class StoryUpdateTable extends _i1.UpdateTable<StoryTable> {
  StoryUpdateTable(super.table);

  _i1.ColumnValue<String, String> userId(String value) =>
      _i1.ColumnValue(table.userId, value);

  _i1.ColumnValue<String, String> userName(String value) =>
      _i1.ColumnValue(table.userName, value);

  _i1.ColumnValue<String, String> userAvatarUrl(String? value) =>
      _i1.ColumnValue(table.userAvatarUrl, value);

  _i1.ColumnValue<List<String>, List<String>> imageUrls(List<String> value) =>
      _i1.ColumnValue(table.imageUrls, value);

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(table.createdAt, value);

  _i1.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _i1.ColumnValue(table.expiresAt, value);

  _i1.ColumnValue<int, int> viewCount(int value) =>
      _i1.ColumnValue(table.viewCount, value);

  _i1.ColumnValue<List<String>, List<String>> viewedBy(List<String> value) =>
      _i1.ColumnValue(table.viewedBy, value);

  _i1.ColumnValue<bool, bool> isActive(bool value) =>
      _i1.ColumnValue(table.isActive, value);
}

class StoryTable extends _i1.Table<int?> {
  StoryTable({super.tableRelation}) : super(tableName: 'stories') {
    updateTable = StoryUpdateTable(this);
    userId = _i1.ColumnString('userId', this);
    userName = _i1.ColumnString('userName', this);
    userAvatarUrl = _i1.ColumnString('userAvatarUrl', this);
    imageUrls = _i1.ColumnSerializable<List<String>>('imageUrls', this);
    createdAt = _i1.ColumnDateTime('createdAt', this);
    expiresAt = _i1.ColumnDateTime('expiresAt', this);
    viewCount = _i1.ColumnInt('viewCount', this, hasDefault: true);
    viewedBy = _i1.ColumnSerializable<List<String>>('viewedBy', this);
    isActive = _i1.ColumnBool('isActive', this, hasDefault: true);
  }

  late final StoryUpdateTable updateTable;

  late final _i1.ColumnString userId;

  late final _i1.ColumnString userName;

  late final _i1.ColumnString userAvatarUrl;

  late final _i1.ColumnSerializable<List<String>> imageUrls;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime expiresAt;

  late final _i1.ColumnInt viewCount;

  late final _i1.ColumnSerializable<List<String>> viewedBy;

  late final _i1.ColumnBool isActive;

  @override
  List<_i1.Column> get columns => [
    id,
    userId,
    userName,
    userAvatarUrl,
    imageUrls,
    createdAt,
    expiresAt,
    viewCount,
    viewedBy,
    isActive,
  ];
}

class StoryInclude extends _i1.IncludeObject {
  StoryInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Story.t;
}

class StoryIncludeList extends _i1.IncludeList {
  StoryIncludeList._({
    _i1.WhereExpressionBuilder<StoryTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Story.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Story.t;
}

class StoryRepository {
  const StoryRepository._();

  /// Returns a list of [Story]s matching the given query parameters.
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
  Future<List<Story>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<StoryTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StoryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StoryTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Story>(
      where: where?.call(Story.t),
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [Story] matching the given query parameters.
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
  Future<Story?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<StoryTable>? where,
    int? offset,
    _i1.OrderByBuilder<StoryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StoryTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Story>(
      where: where?.call(Story.t),
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Story] by its [id] or null if no such row exists.
  Future<Story?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Story>(id, transaction: transaction);
  }

  /// Inserts all [Story]s in the list and returns the inserted rows.
  ///
  /// The returned [Story]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Story>> insert(
    _i1.Session session,
    List<Story> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Story>(rows, transaction: transaction);
  }

  /// Inserts a single [Story] and returns the inserted row.
  ///
  /// The returned [Story] will have its `id` field set.
  Future<Story> insertRow(
    _i1.Session session,
    Story row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Story>(row, transaction: transaction);
  }

  /// Updates all [Story]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Story>> update(
    _i1.Session session,
    List<Story> rows, {
    _i1.ColumnSelections<StoryTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Story>(
      rows,
      columns: columns?.call(Story.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Story]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Story> updateRow(
    _i1.Session session,
    Story row, {
    _i1.ColumnSelections<StoryTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Story>(
      row,
      columns: columns?.call(Story.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Story] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Story?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<StoryUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Story>(
      id,
      columnValues: columnValues(Story.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Story]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Story>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<StoryUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<StoryTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StoryTable>? orderBy,
    _i1.OrderByListBuilder<StoryTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Story>(
      columnValues: columnValues(Story.t.updateTable),
      where: where(Story.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Story.t),
      orderByList: orderByList?.call(Story.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Story]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Story>> delete(
    _i1.Session session,
    List<Story> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Story>(rows, transaction: transaction);
  }

  /// Deletes a single [Story].
  Future<Story> deleteRow(
    _i1.Session session,
    Story row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Story>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Story>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<StoryTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Story>(
      where: where(Story.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<StoryTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Story>(
      where: where?.call(Story.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
