part of 'protocol.dart';

class MoodPin extends TableRow {
  MoodPin({
    int? id,
    required this.sentiment,
    required this.gridLat,
    required this.gridLon,
    required this.timestamp,
    required this.expiresAt,
    this.userId,
  }) : super(id);

  factory MoodPin.fromJson(Map<String, dynamic> json) {
    return MoodPin(
      id: json['id'] as int?,
      sentiment: json['sentiment'] as String,
      gridLat: (json['gridLat'] as num).toDouble(),
      gridLon: (json['gridLon'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      userId: json['userId'] as int?,
    );
  }

  static const db = MoodPinRepository._();

  String sentiment;
  double gridLat;
  double gridLon;
  DateTime timestamp;
  DateTime expiresAt;
  int? userId;

  @override
  String get tableName => 'mood_pins';

  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  @override
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
      'timestamp': timestamp,
      'expiresAt': expiresAt,
      'userId': userId,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      if (id != null) 'id': id,
      'sentiment': sentiment,
      'gridLat': gridLat,
      'gridLon': gridLon,
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
      case 'sentiment':
        sentiment = value;
        return;
      case 'gridLat':
        gridLat = value;
        return;
      case 'gridLon':
        gridLon = value;
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

  MoodPin copyWith({
    int? id,
    String? sentiment,
    double? gridLat,
    double? gridLon,
    DateTime? timestamp,
    DateTime? expiresAt,
    int? userId,
  }) {
    return MoodPin(
      id: id ?? this.id,
      sentiment: sentiment ?? this.sentiment,
      gridLat: gridLat ?? this.gridLat,
      gridLon: gridLon ?? this.gridLon,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
    );
  }
}

class MoodPinTable extends Table {
  MoodPinTable({super.tableRelation}) : super(tableName: 'mood_pins') {
    sentiment = ColumnString('sentiment');
    gridLat = ColumnDouble('gridLat');
    gridLon = ColumnDouble('gridLon');
    timestamp = ColumnDateTime('timestamp');
    expiresAt = ColumnDateTime('expiresAt');
    userId = ColumnInt('userId');
  }

  late final ColumnString sentiment;
  late final ColumnDouble gridLat;
  late final ColumnDouble gridLon;
  late final ColumnDateTime timestamp;
  late final ColumnDateTime expiresAt;
  late final ColumnInt userId;

  @override
  List<Column> get columns => [
    id,
    sentiment,
    gridLat,
    gridLon,
    timestamp,
    expiresAt,
    userId,
  ];
}

class MoodPinRepository {
  const MoodPinRepository._();

  Future<List<MoodPin>> find(
    Session session, {
    MoodPinExpressionBuilder? where,
    int? limit,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.find<MoodPin>(
      where: where?.call(MoodPinTable()),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<MoodPin?> findFirstRow(
    Session session, {
    MoodPinExpressionBuilder? where,
    int? offset,
    Column? orderBy,
    bool orderDescending = false,
  }) async {
    return session.db.findFirstRow<MoodPin>(
      where: where?.call(MoodPinTable()),
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
    );
  }

  Future<MoodPin?> findById(Session session, int id) async {
    return session.db.findById<MoodPin>(id);
  }

  Future<MoodPin> insertRow(Session session, MoodPin row) async {
    return session.db.insertRow<MoodPin>(row);
  }

  Future<MoodPin> updateRow(Session session, MoodPin row) async {
    return session.db.updateRow<MoodPin>(row);
  }

  Future<int> deleteRow(Session session, MoodPin row) async {
    return session.db.deleteRow<MoodPin>(row);
  }
}

typedef MoodPinExpressionBuilder = Expression Function(MoodPinTable t);
