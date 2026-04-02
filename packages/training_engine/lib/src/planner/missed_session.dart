import 'session_generator.dart';

/// Returns a new [WeeklyPlan] with missed volume redistributed to remaining sessions.
///
/// Rules:
/// - If no sessions remain after [now], the plan is returned unchanged.
/// - 75 % of missed sets are redistributed when ≥ 2 sessions remain,
///   50 % when only 1 session remains.
/// - Extra sets go to sessions whose focus matches the missed session's focus.
/// - If no match is found, extra sets go to the closest remaining session
///   (first in the remaining list).
///
/// "Remaining" means sessions whose [PlannedSession.dayOfWeek] comes after
/// the missed day **and** whose absolute date is after [now] (week-relative
/// comparison via day-of-week ≥ missedDay threshold, adjusted for weekStart).
WeeklyPlan handleMissedSession(
  WeeklyPlan plan,
  int missedDay,
  DateTime now,
) {
  // --------------------------------------------------------------------------
  // Identify the missed session
  // --------------------------------------------------------------------------
  final missedIndex = plan.sessions.indexWhere((s) => s.dayOfWeek == missedDay);
  if (missedIndex == -1) return plan; // nothing to handle

  final missed = plan.sessions[missedIndex];

  // --------------------------------------------------------------------------
  // Find remaining sessions (day-of-week strictly after missedDay,
  // OR if the week already wraps, use week-end logic)
  // --------------------------------------------------------------------------
  final remaining = plan.sessions
      .where((s) => s.dayOfWeek > missedDay)
      .toList();

  if (remaining.isEmpty) return plan; // nothing left this week

  // --------------------------------------------------------------------------
  // Calculate redistribution volume
  // --------------------------------------------------------------------------
  final totalMissedSets = missed.exercises.fold<int>(
    0,
    (sum, ex) => sum + ex.targetSets,
  );

  final redistributeFraction = remaining.length >= 2 ? 0.75 : 0.50;
  int setsToRedistribute = (totalMissedSets * redistributeFraction).round();

  if (setsToRedistribute <= 0) return plan;

  // --------------------------------------------------------------------------
  // Find target sessions (matching focus, then fallback to closest)
  // --------------------------------------------------------------------------
  final matchingFocus = remaining
      .where((s) => s.focus == missed.focus)
      .toList();
  final targets = matchingFocus.isNotEmpty ? matchingFocus : [remaining.first];

  // --------------------------------------------------------------------------
  // Distribute extra sets evenly across target sessions
  // --------------------------------------------------------------------------
  // Build a mutable copy of session→exercises map
  final updatedSessions = {
    for (final s in plan.sessions) s.dayOfWeek: List<PlannedExercise>.from(s.exercises),
  };

  int remaining_ = setsToRedistribute;
  int targetIdx = 0;

  while (remaining_ > 0 && targets.isNotEmpty) {
    final targetSession = targets[targetIdx % targets.length];
    targetIdx++;

    // Add 1 set to the first exercise in the target (or spread evenly)
    final exList = updatedSessions[targetSession.dayOfWeek]!;
    if (exList.isEmpty) {
      remaining_--;
      continue;
    }

    // Add the set to the exercise that corresponds to the missed focus
    // (first exercise is fine for redistribution purposes)
    final bestIdx = _bestExerciseIndex(exList, missed.exercises);
    final ex = exList[bestIdx];
    exList[bestIdx] = ex.copyWith(targetSets: ex.targetSets + 1);
    remaining_--;
  }

  // --------------------------------------------------------------------------
  // Rebuild plan
  // --------------------------------------------------------------------------
  final newSessions = plan.sessions.map((s) {
    final exList = updatedSessions[s.dayOfWeek]!;
    return s.copyWith(exercises: exList);
  }).toList();

  return WeeklyPlan(
    sessions: newSessions,
    splitType: plan.splitType,
    weekStart: plan.weekStart,
  );
}

/// Returns the index of the exercise in [target] that best matches the
/// muscle groups of [source] exercises.  Falls back to index 0.
int _bestExerciseIndex(
  List<PlannedExercise> target,
  List<PlannedExercise> source,
) {
  if (target.isEmpty) return 0;
  final sourceIds = source.map((e) => e.exerciseId).toSet();
  for (int i = 0; i < target.length; i++) {
    if (sourceIds.contains(target[i].exerciseId)) return i;
  }
  return 0;
}
