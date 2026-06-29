/// Data passed from QuickCheckInWidget to CreateEntryScreen
/// via go_router extra.
class QuickCheckInData {
  const QuickCheckInData({this.mood, this.note});

  /// Mood value 1–5, or null if none selected.
  final int? mood;

  /// Note text (trimmed), or null if empty.
  final String? note;
}
