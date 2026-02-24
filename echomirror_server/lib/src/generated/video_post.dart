part of 'protocol.dart';

class VideoPost extends TableRow {
  VideoPost({
    int? id,
    required this.videoUrl,
    required this.moodTag,
    required this.timestamp,
    required this.expiresAt,
    this.userId,
  }) : super(id);

  factory VideoPost.fromJson(Map<String, dynamic> json) {
    return VideoPost(
      id: json['id'] as int?,
      videoUrl: json['videoUrl'] as String,
      moodTag: json['moodTag'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      userId: json['userId'] as int?,
    );
  }

  static const db = VideoPostRepository._();

  String videoUrl;
  String moodTag;
  DateTime timestamp;
  DateTime expiresAt;
  int? userId;

  @override
  String get tableName => 'video_posts';

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp,
      'expiresAt': expiresAt,
      'userId': userId,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'moodTag': moodTag,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'userId': userId,
    };
  }

  @override
  void setColumn(String columnName, value) {
    switch (columnName) {
      case 'id':
        id = value;
        return;
      case 'videoUrl':
        videoUrl = value;
        return;
      case 'moodTag':
        moodTag = value;
        return;
      case 'timestamp':
        timestamp = value;
        return;
      case 'expiresAt':
        expiresAt = value;
        return;
      case 'userId':
        userId = value;
        return;
    }
  }

  VideoPost copyWith({
    int? id,
    String? videoUrl,
    String? moodTag,
    DateTime? timestamp,
    DateTime? expiresAt,
    int? userId,
  }) {
    return VideoPost(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      moodTag: moodTag ?? this.moodTag,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
    );
  }
}

class VideoPostTable extends Table {
  VideoPostTable({super.tableRelation}) : super(tableName: 'video_posts') {
    videoUrl = ColumnString('videoUrl');
    moodTag = ColumnString('moodTag');
    timestamp = ColumnDateTime('timestamp');
    expiresAt = ColumnDateTime('expiresAt');
    userId = ColumnInt('userId');
  }

  late final ColumnString videoUrl;
  late final ColumnString moodTag;
  late final ColumnDateTime timestamp;
  late final ColumnDateTime expiresAt;
  late final ColumnInt userId;

  @override
  List<Column> get columns => [
    id,
    videoUrl,
    moodTag,
    timestamp,
    expiresAt,
    userId,
  ];
}

class VideoPostRepository {
  const VideoPostRepository._();

  Future<List<VideoPost>> find(
    Session session, {
    VideoPostExpressionBuilder? where,
    int? limit,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.find<VideoPost>(
      where: where?.call(VideoPostTable()),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<VideoPost?> findFirstRow(
    Session session, {
    VideoPostExpressionBuilder? where,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.findFirstRow<VideoPost>(
      where: where?.call(VideoPostTable()),
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<VideoPost?> findById(Session session, int id) async {
    return session.db.findById<VideoPost>(id);
  }

  Future<VideoPost> insertRow(Session session, VideoPost row) async {
    return session.db.insertRow<VideoPost>(row);
  }

  Future<VideoPost> updateRow(Session session, VideoPost row) async {
    return session.db.updateRow<VideoPost>(row);
  }

  Future<int> deleteRow(Session session, VideoPost row) async {
    return session.db.deleteRow<VideoPost>(row);
  }
}

typedef VideoPostExpressionBuilder = Expression Function(VideoPostTable t);
