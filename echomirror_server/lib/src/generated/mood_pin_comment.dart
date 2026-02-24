part of 'protocol.dart';

class MoodPinComment extends TableRow {
  MoodPinComment({
    int? id,
    required this.moodPinId,
    required this.text,
    required this.timestamp,
    this.userId,
  }) : super(id);

  factory MoodPinComment.fromJson(Map<String, dynamic> json) {
    return MoodPinComment(
      id: json['id'] as int?,
      moodPinId: json['moodPinId'] as int,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as int?,
    );
  }

  static const db = MoodPinCommentRepository._();

  int moodPinId;
  String text;
  DateTime timestamp;
  int? userId;

  @override
  String get tableName => 'mood_pin_comments';

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp,
      'userId': userId,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      if (id != null) 'id': id,
      'moodPinId': moodPinId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  @override
  void setColumn(String columnName, value) {
    switch (columnName) {
      case 'id':
        id = value;
        return;
      case 'moodPinId':
        moodPinId = value;
        return;
      case 'text':
        text = value;
        return;
      case 'timestamp':
        timestamp = value;
        return;
      case 'userId':
        userId = value;
        return;
    }
  }

  MoodPinComment copyWith({
    int? id,
    int? moodPinId,
    String? text,
    DateTime? timestamp,
    int? userId,
  }) {
    return MoodPinComment(
      id: id ?? this.id,
      moodPinId: moodPinId ?? this.moodPinId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}

class MoodPinCommentTable extends Table {
  MoodPinCommentTable({super.tableRelation}) : super(tableName: 'mood_pin_comments') {
    moodPinId = ColumnInt('moodPinId');
    text = ColumnString('text');
    timestamp = ColumnDateTime('timestamp');
    userId = ColumnInt('userId');
  }

  late final ColumnInt moodPinId;
  late final ColumnString text;
  late final ColumnDateTime timestamp;
  late final ColumnInt userId;

  @override
  List<Column> get columns => [
        id,
        moodPinId,
        text,
        timestamp,
        userId,
      ];
}

class MoodPinCommentRepository {
  const MoodPinCommentRepository._();

  Future<List<MoodPinComment>> find(
    Session session, {
    MoodPinCommentExpressionBuilder? where,
    int? limit,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.find<MoodPinComment>(
      where: where?.call(MoodPinCommentTable()),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<MoodPinComment?> findFirstRow(
    Session session, {
    MoodPinCommentExpressionBuilder? where,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.findFirstRow<MoodPinComment>(
      where: where?.call(MoodPinCommentTable()),
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<MoodPinComment?> findById(Session session, int id) async {
    return session.db.findById<MoodPinComment>(id);
  }

  Future<MoodPinComment> insertRow(Session session, MoodPinComment row) async {
    return session.db.insertRow<MoodPinComment>(row);
  }

  Future<MoodPinComment> updateRow(Session session, MoodPinComment row) async {
    return session.db.updateRow<MoodPinComment>(row);
  }

  Future<int> deleteRow(Session session, MoodPinComment row) async {
    return session.db.deleteRow<MoodPinComment>(row);
  }
}

typedef MoodPinCommentExpressionBuilder = Expression Function(MoodPinCommentTable t);
