import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/local_models.dart';

part 'offline_storage_service.g.dart';

class OfflineStorageService {
  static const String logEntriesBoxName = 'local_log_entries';
  static const String userProfileBoxName = 'local_user_profile';
  static const String dashboardBoxName = 'local_dashboard_snapshot';

  late Box<LocalLogEntry> _logEntriesBox;
  late Box<LocalUserProfile> _userProfileBox;
  late Box<LocalDashboardSnapshot> _dashboardBox;

  Future<void> initialize() async {
    _logEntriesBox = await Hive.openBox<LocalLogEntry>(logEntriesBoxName);
    _userProfileBox = await Hive.openBox<LocalUserProfile>(userProfileBoxName);
    _dashboardBox = await Hive.openBox<LocalDashboardSnapshot>(dashboardBoxName);
  }

  Future<void> saveLogEntry(LocalLogEntry entry) async {
    await _logEntriesBox.put(entry.id, entry);
  }

  List<LocalLogEntry> getPendingLogEntries() {
    return _logEntriesBox.values.where((e) => !e.synced).toList();
  }

  List<LocalLogEntry> getAllLogEntries() {
    return _logEntriesBox.values.toList();
  }

  Future<void> markEntrySynced(String entryId) async {
    final entry = _logEntriesBox.get(entryId);
    if (entry != null) {
      entry.synced = true;
      await entry.save();
    }
  }

  Future<void> deleteLogEntry(String entryId) async {
    await _logEntriesBox.delete(entryId);
  }

  Future<void> saveUserProfile(LocalUserProfile profile) async {
    await _userProfileBox.put(profile.userId, profile);
  }

  LocalUserProfile? getUserProfile(String userId) {
    return _userProfileBox.get(userId);
  }

  Future<void> saveDashboardSnapshot(LocalDashboardSnapshot snapshot) async {
    await _dashboardBox.put(snapshot.userId, snapshot);
  }

  LocalDashboardSnapshot? getDashboardSnapshot(String userId) {
    final snapshot = _dashboardBox.get(userId);
    if (snapshot != null && snapshot.isExpired()) {
      return null;
    }
    return snapshot;
  }

  Future<void> clearAll() async {
    await _logEntriesBox.clear();
    await _userProfileBox.clear();
    await _dashboardBox.clear();
  }
}

@riverpod
OfflineStorageService offlineStorageService(OfflineStorageServiceRef ref) {
  return OfflineStorageService();
}
