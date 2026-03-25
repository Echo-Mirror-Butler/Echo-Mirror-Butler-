/// Model for a scheduled video session (migrated from Serverpod to Supabase)
class ScheduledSession {
  final int? id;
  final String hostId;
  final String hostName;
  final String? hostAvatarUrl;
  final String title;
  final String? description;
  final DateTime scheduledTime;
  final DateTime createdAt;
  final bool isVideoEnabled;
  final bool isVoiceOnly;
  final bool isNotified;
  final bool isCancelled;
  final String? actualSessionId;

  const ScheduledSession({
    this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    required this.title,
    this.description,
    required this.scheduledTime,
    required this.createdAt,
    this.isVideoEnabled = true,
    this.isVoiceOnly = false,
    this.isNotified = false,
    this.isCancelled = false,
    this.actualSessionId,
  });
}
