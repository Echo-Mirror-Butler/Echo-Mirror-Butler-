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
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'package:echomirror_server_client/src/protocol/protocol.dart' as _i2;

abstract class LogEntry implements _i1.SerializableModel {
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

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
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
