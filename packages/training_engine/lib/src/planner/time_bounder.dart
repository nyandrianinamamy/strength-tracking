import 'session_generator.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class BoundedSession {
  final PlannedSession session;

  /// Human-readable descriptions of adjustments made (empty if none needed).
  final List<String> adjustments;

  const BoundedSession({required this.session, required this.adjustments});
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const int _minIsolationRest = 90;
const int _avgSetDurationCompound = 45; // seconds
const int _avgSetDurationIsolation = 30; // seconds

// ---------------------------------------------------------------------------
// Duration estimation (internal)
// ---------------------------------------------------------------------------

int _setDurationFor(PlannedExercise ex) =>
    ex.restSeconds >= 120 ? _avgSetDurationCompound : _avgSetDurationIsolation;

int _effectiveRestFor(PlannedExercise ex) =>
    ex.isSupersetPair ? ex.restSeconds ~/ 2 : ex.restSeconds;

int _exerciseDurationSeconds(PlannedExercise ex) =>
    ex.targetSets * (_setDurationFor(ex) + _effectiveRestFor(ex));

int _totalDurationSeconds(List<PlannedExercise> exercises) =>
    exercises.fold(0, (sum, ex) => sum + _exerciseDurationSeconds(ex));

// ---------------------------------------------------------------------------
// Main function
// ---------------------------------------------------------------------------

/// Adjusts [session] so its estimated duration fits within [maxDuration].
///
/// Three passes are applied in order until the session fits:
///   1. Reduce isolation rest to 90 s (if currently > 90).
///   2. Pair agonist/antagonist exercises as supersets (halves rest between
///      paired sets; marks [PlannedExercise.isSupersetPair]).
///   3. Trim 1 set from the lowest-priority isolation exercises.
///
/// Returns a [BoundedSession] that includes the (possibly adjusted) session
/// and a list of human-readable adjustment descriptions.
BoundedSession boundSessionToTime(
  PlannedSession session,
  Duration maxDuration,
) {
  final maxSeconds = maxDuration.inSeconds;
  final adjustments = <String>[];

  var exercises = List<PlannedExercise>.from(session.exercises);

  // Short-circuit: already within budget
  if (_totalDurationSeconds(exercises) <= maxSeconds) {
    return BoundedSession(
      session: session,
      adjustments: adjustments,
    );
  }

  // ── Pass 1: reduce isolation rest to 90 s ────────────────────────────────
  bool pass1Applied = false;
  exercises = exercises.map((ex) {
    if (ex.restSeconds > _minIsolationRest &&
        ex.restSeconds < 120 // isolation proxy: rest < 2 min
        ) {
      pass1Applied = true;
      return ex.copyWith(restSeconds: _minIsolationRest);
    }
    return ex;
  }).toList();

  if (pass1Applied) {
    adjustments.add('Reduced rest on isolation exercises');
  }

  if (_totalDurationSeconds(exercises) <= maxSeconds) {
    return BoundedSession(
      session: session.copyWith(exercises: exercises),
      adjustments: adjustments,
    );
  }

  // ── Pass 2: superset pairing ──────────────────────────────────────────────
  // Pair adjacent exercises; supersets halve the rest for the paired exercise.
  bool pass2Applied = false;
  final paired = <PlannedExercise>[];
  for (int i = 0; i < exercises.length; i++) {
    if (i < exercises.length - 1 && !exercises[i].isSupersetPair) {
      // Pair this exercise with the next one
      paired.add(exercises[i].copyWith(isSupersetPair: true));
      paired.add(exercises[i + 1].copyWith(isSupersetPair: true));
      i++; // skip next, already paired
      pass2Applied = true;
    } else {
      paired.add(exercises[i]);
    }
  }

  if (pass2Applied) {
    adjustments.add('Paired exercises as supersets to save time');
    exercises = paired;
  }

  if (_totalDurationSeconds(exercises) <= maxSeconds) {
    return BoundedSession(
      session: session.copyWith(exercises: exercises),
      adjustments: adjustments,
    );
  }

  // ── Pass 3: trim sets from isolation exercises ────────────────────────────
  // Find isolation exercises (rest < 120 s) with more than 1 set and reduce
  // by 1 set, starting from the end of the list (lowest priority).
  bool pass3Applied = false;
  final trimmed = List<PlannedExercise>.from(exercises);
  for (int i = trimmed.length - 1; i >= 0; i--) {
    final ex = trimmed[i];
    if (ex.restSeconds < 120 && ex.targetSets > 1) {
      trimmed[i] = ex.copyWith(targetSets: ex.targetSets - 1);
      pass3Applied = true;
      if (_totalDurationSeconds(trimmed) <= maxSeconds) break;
    }
  }

  if (pass3Applied) {
    adjustments.add('Trimmed sets from lower-priority isolation exercises');
    exercises = trimmed;
  }

  return BoundedSession(
    session: session.copyWith(exercises: exercises),
    adjustments: adjustments,
  );
}
