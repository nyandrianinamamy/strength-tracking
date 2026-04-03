/// Represents how training volume is distributed across the week.
enum SplitType { fullBody, upperLower, pushPullLegs }

/// The muscle-group focus for a single training session.
enum SessionFocus { fullBody, push, pull, legs, upper, lower }

/// Selects the most appropriate [SplitType] given the available training days.
///
/// Rules:
/// - 0-2 days  → fullBody
/// - 3 days, non-consecutive → fullBody
/// - 3 days, consecutive    → pushPullLegs
/// - 4 days                 → upperLower
/// - 5+ days                → pushPullLegs
SplitType selectSplit(List<int> availableDays) {
  if (availableDays.length <= 2) return SplitType.fullBody;
  if (availableDays.length == 3) {
    return hasConsecutiveDays(availableDays)
        ? SplitType.pushPullLegs
        : SplitType.fullBody;
  }
  if (availableDays.length == 4) return SplitType.upperLower;
  return SplitType.pushPullLegs; // 5+
}

/// Returns `true` if any two days in [days] are adjacent (including 6→0 wrap).
bool hasConsecutiveDays(List<int> days) {
  final sorted = List<int>.from(days)..sort();
  for (int i = 0; i < sorted.length - 1; i++) {
    if (sorted[i + 1] - sorted[i] == 1) return true;
  }
  // Wrap-around check: Sunday (6) → Monday (0)
  if (sorted.isNotEmpty && sorted.last == 6 && sorted.first == 0) return true;
  return false;
}

/// Returns the ordered list of [SessionFocus] for a given [split] and [numDays].
///
/// - fullBody: every session is [SessionFocus.fullBody]
/// - upperLower: repeating [upper, lower, upper, lower, …]
/// - pushPullLegs: repeating [push, pull, legs, push, pull, …]
List<SessionFocus> focusesForSplit(SplitType split, int numDays) {
  if (numDays <= 0) return [];
  switch (split) {
    case SplitType.fullBody:
      return List.filled(numDays, SessionFocus.fullBody);
    case SplitType.upperLower:
      const cycle = [SessionFocus.upper, SessionFocus.lower];
      return List.generate(numDays, (i) => cycle[i % cycle.length]);
    case SplitType.pushPullLegs:
      const cycle = [SessionFocus.push, SessionFocus.pull, SessionFocus.legs];
      return List.generate(numDays, (i) => cycle[i % cycle.length]);
  }
}
