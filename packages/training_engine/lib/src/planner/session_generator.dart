import '../models/engine_exercise.dart';
import '../models/enums.dart';
import '../progression/performance_delta.dart';
import 'split_selector.dart';

// ---------------------------------------------------------------------------
// Registry interface
// ---------------------------------------------------------------------------

/// Minimal read-only interface for exercise lookup used by the planner.
abstract class ExerciseRegistryLookup {
  /// Returns exercises whose primary (or highest-coefficient) muscle is [muscleId].
  /// Optionally excludes specific exercise IDs.
  List<EngineExercise> exercisesForMuscle(
    String muscleId, {
    Set<String>? excludeIds,
  });

  /// Returns compound exercises suitable for the given [focus].
  /// Optionally excludes specific exercise IDs.
  List<EngineExercise> compoundsForFocus(
    SessionFocus focus, {
    Set<String>? excludeIds,
  });
}

// ---------------------------------------------------------------------------
// Config & plan data structures
// ---------------------------------------------------------------------------

class PlannerConfig {
  final List<int> availableDays;
  final Duration maxSessionDuration;
  final HypertrophyGoal goal;
  final List<String> preferredExercises;
  final List<String> excludedExercises;

  const PlannerConfig({
    required this.availableDays,
    this.maxSessionDuration = const Duration(hours: 1),
    this.goal = HypertrophyGoal.hypertrophy,
    this.preferredExercises = const [],
    this.excludedExercises = const [],
  });
}

class PlannedExercise {
  final String exerciseId;
  final int targetSets;
  final int targetReps;
  final double targetRpe;
  final double? suggestedWeightKg;
  final int restSeconds;

  /// Whether this exercise is marked as part of a superset pair (time-bounding).
  final bool isSupersetPair;

  const PlannedExercise({
    required this.exerciseId,
    required this.targetSets,
    required this.targetReps,
    required this.targetRpe,
    this.suggestedWeightKg,
    required this.restSeconds,
    this.isSupersetPair = false,
  });

  PlannedExercise copyWith({
    String? exerciseId,
    int? targetSets,
    int? targetReps,
    double? targetRpe,
    double? suggestedWeightKg,
    int? restSeconds,
    bool? isSupersetPair,
  }) =>
      PlannedExercise(
        exerciseId: exerciseId ?? this.exerciseId,
        targetSets: targetSets ?? this.targetSets,
        targetReps: targetReps ?? this.targetReps,
        targetRpe: targetRpe ?? this.targetRpe,
        suggestedWeightKg: suggestedWeightKg ?? this.suggestedWeightKg,
        restSeconds: restSeconds ?? this.restSeconds,
        isSupersetPair: isSupersetPair ?? this.isSupersetPair,
      );
}

class PlannedSession {
  final int dayOfWeek;
  final SessionFocus focus;
  final List<PlannedExercise> exercises;
  final Duration estimatedDuration;

  const PlannedSession({
    required this.dayOfWeek,
    required this.focus,
    required this.exercises,
    required this.estimatedDuration,
  });

  PlannedSession copyWith({
    int? dayOfWeek,
    SessionFocus? focus,
    List<PlannedExercise>? exercises,
    Duration? estimatedDuration,
  }) =>
      PlannedSession(
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        focus: focus ?? this.focus,
        exercises: exercises ?? this.exercises,
        estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      );
}

class WeeklyPlan {
  final List<PlannedSession> sessions;
  final SplitType splitType;
  final DateTime weekStart;

  const WeeklyPlan({
    required this.sessions,
    required this.splitType,
    required this.weekStart,
  });
}

// ---------------------------------------------------------------------------
// Default sets per movement / focus
// ---------------------------------------------------------------------------

const int _defaultCompoundSets = 3;
const int _defaultIsolationSets = 3;
const int _defaultCompoundRest = 180;
const int _defaultIsolationRest = 90;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [PlannedExercise] from an [EngineExercise] using defaults.
PlannedExercise _toPlanned(EngineExercise ex) {
  final isCompound =
      ex.movement == MovementClass.compoundLower ||
      ex.movement == MovementClass.compoundUpper;
  final params = TargetParams.defaultFor(ex.movement);
  return PlannedExercise(
    exerciseId: ex.id,
    targetSets: isCompound ? _defaultCompoundSets : _defaultIsolationSets,
    targetReps: (params.targetRepsLow + params.targetRepsHigh) ~/ 2,
    targetRpe: params.targetRpe,
    restSeconds: isCompound ? _defaultCompoundRest : _defaultIsolationRest,
  );
}

/// Picks up to [count] exercises for [muscleId], respecting preferred/excluded.
List<PlannedExercise> _pickFor(
  String muscleId,
  int count,
  ExerciseRegistryLookup registry,
  Set<String> excludeIds,
  Set<String> preferred,
) {
  final all = registry.exercisesForMuscle(muscleId, excludeIds: excludeIds);
  if (all.isEmpty) return [];

  // Sort: preferred exercises first
  final sorted = [
    ...all.where((e) => preferred.contains(e.id)),
    ...all.where((e) => !preferred.contains(e.id)),
  ];

  final taken = sorted.take(count).toList();
  // Track used IDs to avoid duplicates across muscle groups in the same session
  excludeIds.addAll(taken.map((e) => e.id));
  return taken.map(_toPlanned).toList();
}

/// Picks up to [count] compounds for [focus], respecting preferred/excluded.
List<PlannedExercise> _pickCompounds(
  SessionFocus focus,
  int count,
  ExerciseRegistryLookup registry,
  Set<String> excludeIds,
  Set<String> preferred,
) {
  final all = registry.compoundsForFocus(focus, excludeIds: excludeIds);
  if (all.isEmpty) return [];

  final sorted = [
    ...all.where((e) => preferred.contains(e.id)),
    ...all.where((e) => !preferred.contains(e.id)),
  ];

  final taken = sorted.take(count).toList();
  excludeIds.addAll(taken.map((e) => e.id));
  return taken.map(_toPlanned).toList();
}

// ---------------------------------------------------------------------------
// Focus → exercise selection
// ---------------------------------------------------------------------------

List<PlannedExercise> _exercisesForFocus(
  SessionFocus focus,
  ExerciseRegistryLookup registry,
  Set<String> baseExcluded,
  Set<String> preferred,
) {
  // Work on a mutable copy so we avoid duplicates within the session
  final excluded = Set<String>.from(baseExcluded);
  final result = <PlannedExercise>[];

  switch (focus) {
    case SessionFocus.push:
      result
        ..addAll(_pickFor('pectorals', 2, registry, excluded, preferred))
        ..addAll(_pickFor('anterior_deltoid', 2, registry, excluded, preferred))
        ..addAll(_pickFor('triceps', 2, registry, excluded, preferred));

    case SessionFocus.pull:
      result
        ..addAll(_pickFor('lats', 3, registry, excluded, preferred))
        ..addAll(_pickFor('biceps', 2, registry, excluded, preferred))
        ..addAll(_pickFor('rear_deltoid', 1, registry, excluded, preferred));

    case SessionFocus.legs:
      result
        ..addAll(_pickFor('quadriceps', 2, registry, excluded, preferred))
        ..addAll(_pickFor('hamstrings', 2, registry, excluded, preferred))
        ..addAll(_pickFor('glutes', 1, registry, excluded, preferred))
        ..addAll(_pickFor('calves', 1, registry, excluded, preferred));

    case SessionFocus.upper:
      result
        ..addAll(_pickFor('pectorals', 2, registry, excluded, preferred))
        ..addAll(_pickFor('lats', 2, registry, excluded, preferred))
        ..addAll(_pickFor('anterior_deltoid', 1, registry, excluded, preferred))
        ..addAll(_pickFor('biceps', 1, registry, excluded, preferred))
        ..addAll(_pickFor('triceps', 1, registry, excluded, preferred));

    case SessionFocus.lower:
      result
        ..addAll(_pickFor('quadriceps', 2, registry, excluded, preferred))
        ..addAll(_pickFor('hamstrings', 2, registry, excluded, preferred))
        ..addAll(_pickFor('glutes', 1, registry, excluded, preferred))
        ..addAll(_pickFor('calves', 1, registry, excluded, preferred));

    case SessionFocus.fullBody:
      // 1 push compound, 1 pull compound, 1 leg compound, 2-3 accessories
      result
        ..addAll(
          _pickCompounds(SessionFocus.push, 1, registry, excluded, preferred),
        )
        ..addAll(
          _pickCompounds(SessionFocus.pull, 1, registry, excluded, preferred),
        )
        ..addAll(
          _pickCompounds(SessionFocus.legs, 1, registry, excluded, preferred),
        )
        // Accessories: 1 shoulder + 1 arm
        ..addAll(_pickFor('anterior_deltoid', 1, registry, excluded, preferred))
        ..addAll(_pickFor('biceps', 1, registry, excluded, preferred))
        ..addAll(_pickFor('triceps', 1, registry, excluded, preferred));
  }

  return result;
}

// ---------------------------------------------------------------------------
// Duration estimation
// ---------------------------------------------------------------------------

/// Estimates total session duration based on sets, rest, and set duration.
Duration estimateSessionDuration(List<PlannedExercise> exercises) {
  int totalSeconds = 0;
  for (final ex in exercises) {
    // Compounds: 45s per set; isolation: 30s per set
    const avgSetDurationCompound = 45;
    const avgSetDurationIsolation = 30;

    // We don't have the EngineExercise here, so we use restSeconds as a proxy:
    // rest ≥ 120s implies compound treatment.
    final setDuration =
        ex.restSeconds >= 120
            ? avgSetDurationCompound
            : avgSetDurationIsolation;

    // For supersets, rest is halved between paired sets.
    final effectiveRest =
        ex.isSupersetPair ? ex.restSeconds ~/ 2 : ex.restSeconds;

    totalSeconds += ex.targetSets * (setDuration + effectiveRest);
  }
  return Duration(seconds: totalSeconds);
}

// ---------------------------------------------------------------------------
// Main generator
// ---------------------------------------------------------------------------

/// Generates a [WeeklyPlan] for the given [config] and [registry].
WeeklyPlan generateWeeklyPlan(
  PlannerConfig config,
  ExerciseRegistryLookup registry, {
  DateTime? weekStart,
}) {
  final split = selectSplit(config.availableDays);
  final sortedDays = List<int>.from(config.availableDays)..sort();
  final focuses = focusesForSplit(split, sortedDays.length);
  final excluded = Set<String>.from(config.excludedExercises);
  final preferred = Set<String>.from(config.preferredExercises);

  final sessions = <PlannedSession>[];
  for (int i = 0; i < sortedDays.length; i++) {
    final focus = focuses[i];
    final exercises = _exercisesForFocus(focus, registry, excluded, preferred);
    final estimated = estimateSessionDuration(exercises);
    sessions.add(
      PlannedSession(
        dayOfWeek: sortedDays[i],
        focus: focus,
        exercises: exercises,
        estimatedDuration: estimated,
      ),
    );
  }

  return WeeklyPlan(
    sessions: sessions,
    splitType: split,
    weekStart: weekStart ?? DateTime.now(),
  );
}
