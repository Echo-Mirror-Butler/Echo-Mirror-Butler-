import 'package:hive_flutter/hive_flutter.dart';

/// A locally cached daily log entry. Entries created while offline are stored
/// with `synced = false` and pushed to Supabase by [SyncService] when the
/// connection is restored.
class LocalLogEntry extends HiveObject {
  String id;
  String userId;

  /// Date-only string in `YYYY-MM-DD` format (matches the `log_entries.date`
  /// convention used by LoggingRepository).
  String date;
  int? mood;
  List<String> habits;
  String? notes;
  DateTime createdAt;
  DateTime updatedAt;
  bool synced;

  LocalLogEntry({
    required this.id,
    required this.userId,
    required this.date,
    this.mood,
    required this.habits,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
  });
}

class LocalUserProfile extends HiveObject {
  String userId;
  String displayName;
  String? avatarUrl;
  String timezone;
  int overallStreak;
  DateTime lastUpdated;

  LocalUserProfile({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.timezone,
    required this.overallStreak,
    required this.lastUpdated,
  });
}

class LocalDashboardSnapshot extends HiveObject {
  String userId;
  int totalLogs;
  double averageMood;
  int currentStreak;
  List<String> topHabits;
  DateTime cachedAt;

  LocalDashboardSnapshot({
    required this.userId,
    required this.totalLogs,
    required this.averageMood,
    required this.currentStreak,
    required this.topHabits,
    required this.cachedAt,
  });

  bool isExpired() {
    return DateTime.now().difference(cachedAt).inHours > 24;
  }
}

// Hand-written Hive adapters. The project does not run build_runner in CI,
// so adapters are maintained manually. Field indexes must stay stable across
// releases — append new fields with new indexes, never reuse old ones.

class LocalLogEntryAdapter extends TypeAdapter<LocalLogEntry> {
  @override
  final int typeId = 0;

  @override
  LocalLogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalLogEntry(
      id: fields[0] as String,
      userId: fields[1] as String,
      date: fields[2] as String,
      mood: fields[3] as int?,
      habits: (fields[4] as List).cast<String>(),
      notes: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
      synced: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalLogEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.mood)
      ..writeByte(4)
      ..write(obj.habits)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.synced);
  }
}

class LocalUserProfileAdapter extends TypeAdapter<LocalUserProfile> {
  @override
  final int typeId = 1;

  @override
  LocalUserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalUserProfile(
      userId: fields[0] as String,
      displayName: fields[1] as String,
      avatarUrl: fields[2] as String?,
      timezone: fields[3] as String,
      overallStreak: fields[4] as int,
      lastUpdated: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LocalUserProfile obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.avatarUrl)
      ..writeByte(3)
      ..write(obj.timezone)
      ..writeByte(4)
      ..write(obj.overallStreak)
      ..writeByte(5)
      ..write(obj.lastUpdated);
  }
}

class LocalDashboardSnapshotAdapter
    extends TypeAdapter<LocalDashboardSnapshot> {
  @override
  final int typeId = 2;

  @override
  LocalDashboardSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalDashboardSnapshot(
      userId: fields[0] as String,
      totalLogs: fields[1] as int,
      averageMood: fields[2] as double,
      currentStreak: fields[3] as int,
      topHabits: (fields[4] as List).cast<String>(),
      cachedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LocalDashboardSnapshot obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.totalLogs)
      ..writeByte(2)
      ..write(obj.averageMood)
      ..writeByte(3)
      ..write(obj.currentStreak)
      ..writeByte(4)
      ..write(obj.topHabits)
      ..writeByte(5)
      ..write(obj.cachedAt);
  }
}
