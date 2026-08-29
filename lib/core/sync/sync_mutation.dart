import 'package:hive_flutter/hive_flutter.dart';
import 'hlc.dart';
import 'version_vector.dart';

/// Supported mutable entity types in the application.
enum SyncEntityType {
  moodEntry,
  habitLog,
  gift,
  story,
  follow,
  moodPin,
  moodComment,
}

/// Operation action performed on the entity.
enum SyncMutationAction {
  create,
  update,
  delete,
}

/// Status of a local mutation.
enum SyncMutationStatus {
  pending,
  inFlight,
  synced,
  conflicted,
  failed,
}

/// Priority tier for network synchronization and bandwidth-conscious ordering.
enum SyncPriority {
  high, // Habit logs, follows, quick mood check-ins (lightweight, high immediacy)
  normal, // Mood entries with notes, comments, pins
  low, // Media uploads, video posts, stories (heavy payloads)
}

/// Represents an atomic local-first mutation queued for synchronization.
class SyncMutation extends HiveObject {
  SyncMutation({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.action,
    required this.payload,
    required this.hlc,
    required this.versionVector,
    required this.createdAt,
    required this.updatedAt,
    this.status = SyncMutationStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    this.priority = SyncPriority.normal,
  });

  String id;
  String entityId;
  SyncEntityType entityType;
  SyncMutationAction action;
  Map<String, dynamic> payload;
  String hlc;
  Map<String, int> versionVector;
  DateTime createdAt;
  DateTime updatedAt;
  SyncMutationStatus status;
  int retryCount;
  String? errorMessage;
  SyncPriority priority;

  Hlc get parsedHlc => Hlc.parse(hlc);
  VersionVector get parsedVersionVector => VersionVector.fromMap(versionVector);

  SyncMutation copyWith({
    String? id,
    String? entityId,
    SyncEntityType? entityType,
    SyncMutationAction? action,
    Map<String, dynamic>? payload,
    String? hlc,
    Map<String, int>? versionVector,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncMutationStatus? status,
    int? retryCount,
    String? errorMessage,
    SyncPriority? priority,
  }) {
    return SyncMutation(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      action: action ?? this.action,
      payload: payload ?? Map<String, dynamic>.from(this.payload),
      hlc: hlc ?? this.hlc,
      versionVector: versionVector ?? Map<String, int>.from(this.versionVector),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity_id': entityId,
    'entity_type': entityType.name,
    'action': action.name,
    'payload': payload,
    'hlc': hlc,
    'version_vector': versionVector,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'status': status.name,
    'retry_count': retryCount,
    'error_message': errorMessage,
    'priority': priority.name,
  };

  factory SyncMutation.fromJson(Map<String, dynamic> json) {
    return SyncMutation(
      id: json['id'] as String,
      entityId: json['entity_id'] as String,
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == json['entity_type'],
        orElse: () => SyncEntityType.moodEntry,
      ),
      action: SyncMutationAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => SyncMutationAction.create,
      ),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
      hlc: json['hlc'] as String,
      versionVector: (json['version_vector'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ??
          {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: SyncMutationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncMutationStatus.pending,
      ),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message'] as String?,
      priority: SyncPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => SyncPriority.normal,
      ),
    );
  }
}

/// Hand-written Hive Adapter for [SyncMutation] (stable typeId = 10).
class SyncMutationAdapter extends TypeAdapter<SyncMutation> {
  @override
  final int typeId = 10;

  @override
  SyncMutation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return SyncMutation(
      id: fields[0] as String,
      entityId: fields[1] as String,
      entityType: SyncEntityType.values[fields[2] as int],
      action: SyncMutationAction.values[fields[3] as int],
      payload: (fields[4] as Map).cast<String, dynamic>(),
      hlc: fields[5] as String,
      versionVector: (fields[6] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      status: SyncMutationStatus.values[fields[9] as int],
      retryCount: fields[10] as int,
      errorMessage: fields[11] as String?,
      priority: SyncPriority.values[fields[12] as int? ?? SyncPriority.normal.index],
    );
  }

  @override
  void write(BinaryWriter writer, SyncMutation obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.entityId)
      ..writeByte(2)
      ..write(obj.entityType.index)
      ..writeByte(3)
      ..write(obj.action.index)
      ..writeByte(4)
      ..write(obj.payload)
      ..writeByte(5)
      ..write(obj.hlc)
      ..writeByte(6)
      ..write(obj.versionVector)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.status.index)
      ..writeByte(10)
      ..write(obj.retryCount)
      ..writeByte(11)
      ..write(obj.errorMessage)
      ..writeByte(12)
      ..write(obj.priority.index);
  }
}
