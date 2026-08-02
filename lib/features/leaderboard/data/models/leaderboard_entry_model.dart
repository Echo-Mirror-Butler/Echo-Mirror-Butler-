/// Model representing a leaderboard entry
class LeaderboardEntryModel {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final bool leaderboardAnonymous;
  final int echoEarnedThisWeek;
  final int rank;

  const LeaderboardEntryModel({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.leaderboardAnonymous = false,
    required this.echoEarnedThisWeek,
    required this.rank,
  });

  /// Create LeaderboardEntryModel from JSON
  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      leaderboardAnonymous: json['leaderboard_anonymous'] as bool? ?? false,
      echoEarnedThisWeek: (json['echo_earned_this_week'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert LeaderboardEntryModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'leaderboard_anonymous': leaderboardAnonymous,
      'echo_earned_this_week': echoEarnedThisWeek,
      'rank': rank,
    };
  }

  /// Get the display name (or "Anonymous" if anonymous is true)
  String get displayText {
    if (leaderboardAnonymous) return 'Anonymous';
    return displayName?.isNotEmpty == true ? displayName! : 'User';
  }

  /// Get initials for avatar fallback
  String get initials {
    if (leaderboardAnonymous) return 'A';
    if (displayName?.isNotEmpty == true) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return '?';
  }

  /// Create a copy with updated fields
  LeaderboardEntryModel copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? leaderboardAnonymous,
    int? echoEarnedThisWeek,
    int? rank,
  }) {
    return LeaderboardEntryModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      leaderboardAnonymous: leaderboardAnonymous ?? this.leaderboardAnonymous,
      echoEarnedThisWeek: echoEarnedThisWeek ?? this.echoEarnedThisWeek,
      rank: rank ?? this.rank,
    );
  }
}
