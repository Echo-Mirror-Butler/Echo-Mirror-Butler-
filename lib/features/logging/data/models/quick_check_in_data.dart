/// Data passed from QuickCheckInWidget to CreateEntryScreen via go_router extra.
class QuickCheckInData {
  const QuickCheckInData({this.mood, this.note});

  final int? mood; // 1–5, or null if none selected
  final String? note; // trimmed, or null if empty
}
