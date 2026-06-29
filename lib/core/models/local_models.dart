import 'package:hive_flutter/hive_flutter.dart';

part 'local_models.g.dart';

@HiveType(typeId: 0)
class LocalLogEntry extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String userId;

  @HiveField(2)
  late String date;

  @HiveField(3)
  late int? mood;

  @HiveField(4)
  late List<String> habits;

  @HiveField(5)
  late String? notes;

  @HiveField(6)
  late DateTime createdAt;

  @HiveField(7)
  late DateTime updatedAt;

  @HiveField(8)
  late bool synced;

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

@HiveType(typeId: 1)
class LocalUserProfile extends HiveObject {
  @HiveField(0)
  late String userId;

  @HiveField(1)
  late String displayName;

  @HiveField(2)
  late String? avatarUrl;

  @HiveField(3)
  late String timezone;

  @HiveField(4)
  late int overallStreak;

  @HiveField(5)
  late DateTime lastUpdated;

  LocalUserProfile({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.timezone,
    required this.overallStreak,
    required this.lastUpdated,
  });
}

@HiveType(typeId: 2)
class LocalDashboardSnapshot extends HiveObject {
  @HiveField(0)
  late String userId;

  @HiveField(1)
  late int totalLogs;

  @HiveField(2)
  late double averageMood;

  @HiveField(3)
  late int currentStreak;

  @HiveField(4)
  late List<String> topHabits;

  @HiveField(5)
  late DateTime cachedAt;

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
