import 'session_generator.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class BoundedSession {
  final PlannedSession session;

  /// Human-readable descriptions of adjustments made (empty if none needed).
  final List<String> adjustments;

  /// False when the supported adjustments cannot meet the requested limit.
  final bool fitsWithinLimit;

  const BoundedSession({
    required this.session,
    required this.adjustments,
    required this.fitsWithinLimit,
  });
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const int _minIsolationRest = 90;
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
/// Set [allowSupersets] to false when the consumer does not execute paired
/// rests; existing pair flags are then removed before estimating.
///
/// Returns a [BoundedSession] that includes the (possibly adjusted) session
/// and a list of human-readable adjustment descriptions.
BoundedSession boundSessionToTime(
  PlannedSession session,
  Duration maxDuration, {
  bool allowSupersets = true,
}) {
  final maxSeconds = maxDuration.inSeconds;
  final adjustments = <String>[];

  var exercises = session.exercises
      .map(
        (exercise) => allowSupersets
            ? exercise
            : exercise.copyWith(isSupersetPair: false),
      )
      .toList();

  BoundedSession result() {
    final duration = estimateSessionDuration(exercises);
    return BoundedSession(
      session: session.copyWith(
        exercises: exercises,
        estimatedDuration: duration,
      ),
      adjustments: adjustments,
      fitsWithinLimit: duration.inSeconds <= maxSeconds,
    );
  }

  // Short-circuit: already within budget
  if (estimateSessionDuration(exercises).inSeconds <= maxSeconds) {
    return result();
  }

  // ── Pass 1: reduce isolation rest to 90 s ────────────────────────────────
  bool pass1Applied = false;
  exercises = exercises.map((ex) {
    if (ex.restSeconds > _minIsolationRest &&
        ex.restSeconds <
            120 // isolation proxy: rest < 2 min
            ) {
      pass1Applied = true;
      return ex.copyWith(restSeconds: _minIsolationRest);
    }
    return ex;
  }).toList();

  if (pass1Applied) {
    adjustments.add('Reduced rest on isolation exercises');
  }

  if (estimateSessionDuration(exercises).inSeconds <= maxSeconds) {
    return result();
  }

  // ── Pass 2: superset pairing ──────────────────────────────────────────────
  // Pair adjacent exercises; supersets halve the rest for the paired exercise.
  bool pass2Applied = false;
  final paired = <PlannedExercise>[];
  for (int i = 0; i < exercises.length; i++) {
    if (allowSupersets &&
        i < exercises.length - 1 &&
        !exercises[i].isSupersetPair) {
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

  if (estimateSessionDuration(exercises).inSeconds <= maxSeconds) {
    return result();
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
      if (estimateSessionDuration(trimmed).inSeconds <= maxSeconds) break;
    }
  }

  if (pass3Applied) {
    adjustments.add('Trimmed sets from lower-priority isolation exercises');
    exercises = trimmed;
  }

  return result();
}
