import '../models/engine_exercise.dart';
import '../models/enums.dart';
import '../planner/session_generator.dart';
import '../planner/split_selector.dart';
import 'default_exercises.dart';

/// Registry that holds all exercises (built-in + custom) and implements the
/// [ExerciseRegistryLookup] interface used by the planner.
class ExerciseRegistry implements ExerciseRegistryLookup {
  final Map<String, EngineExercise> _builtIn;
  final Map<String, EngineExercise> _custom = {};

  /// Creates a registry pre-populated with the default exercise library.
  ExerciseRegistry.withDefaults()
      : _builtIn = Map.fromEntries(
          defaultExercises.map((e) => MapEntry(e.id, e)),
        );

  /// Creates an empty registry (useful for testing or custom-only usage).
  ExerciseRegistry.empty() : _builtIn = {};

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Returns the [EngineExercise] for [id], checking custom exercises first.
  /// Returns `null` if not found.
  EngineExercise? lookup(String id) => _custom[id] ?? _builtIn[id];

  /// Alias for [lookup] — required by the fatigue substitution subsystem.
  EngineExercise? exerciseById(String id) => lookup(id);

  // ---------------------------------------------------------------------------
  // Collection views
  // ---------------------------------------------------------------------------

  /// All exercises (custom overrides built-in when IDs clash).
  List<EngineExercise> get all {
    final merged = Map<String, EngineExercise>.from(_builtIn)..addAll(_custom);
    return merged.values.toList();
  }

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Adds (or replaces) a custom [exercise]. Custom exercises take precedence
  /// over built-in ones with the same ID.
  void addCustom(EngineExercise exercise) {
    _custom[exercise.id] = exercise;
  }

  // ---------------------------------------------------------------------------
  // Substitution
  // ---------------------------------------------------------------------------

  /// Returns exercises that share the same primary muscles as [exerciseId]
  /// but do not activate any muscle in [avoidMuscles] above a low threshold
  /// (coefficient < 0.3).
  ///
  /// The source exercise is excluded from results.
  List<EngineExercise> substitutesFor(
    String exerciseId, {
    Set<String> avoidMuscles = const {},
  }) {
    final source = lookup(exerciseId);
    if (source == null) return [];

    final primaryMuscles = source.muscleMap
        .where((m) => m.role == MuscleRole.primary)
        .map((m) => m.muscleId)
        .toSet();

    return all.where((ex) {
      if (ex.id == exerciseId) return false;

      // Must share at least one primary muscle.
      final exPrimaries = ex.muscleMap
          .where((m) => m.role == MuscleRole.primary)
          .map((m) => m.muscleId)
          .toSet();
      if (exPrimaries.intersection(primaryMuscles).isEmpty) return false;

      // Must not activate any avoided muscle at a meaningful level (>= 0.3).
      for (final m in ex.muscleMap) {
        if (avoidMuscles.contains(m.muscleId) && m.coefficient >= 0.3) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // ExerciseRegistryLookup implementation
  // ---------------------------------------------------------------------------

  /// Returns all exercises that target [muscleId] as a primary or high-coefficient
  /// muscle, optionally excluding specific IDs.
  @override
  List<EngineExercise> exercisesForMuscle(
    String muscleId, {
    Set<String>? excludeIds,
  }) {
    return all.where((ex) {
      if (excludeIds != null && excludeIds.contains(ex.id)) return false;
      return ex.muscleMap.any(
        (m) => m.muscleId == muscleId && m.role == MuscleRole.primary,
      );
    }).toList();
  }

  /// Returns compound exercises appropriate for the given [focus],
  /// optionally excluding specific IDs.
  ///
  /// Focus → movement + primary muscle mapping:
  /// - push   → compoundUpper + pectorals or deltoid
  /// - pull   → compoundUpper + lats
  /// - legs   → compoundLower + quadriceps or glutes or hamstrings
  /// - upper  → compoundUpper (any)
  /// - lower  → compoundLower (any)
  /// - fullBody → compoundUpper + compoundLower (any)
  @override
  List<EngineExercise> compoundsForFocus(
    SessionFocus focus, {
    Set<String>? excludeIds,
  }) {
    bool isCompound(EngineExercise ex) =>
        ex.movement == MovementClass.compoundUpper ||
        ex.movement == MovementClass.compoundLower;

    bool isUpper(EngineExercise ex) =>
        ex.movement == MovementClass.compoundUpper;

    bool isLower(EngineExercise ex) =>
        ex.movement == MovementClass.compoundLower;

    bool hasPrimaryMuscle(EngineExercise ex, Set<String> muscles) =>
        ex.muscleMap.any(
          (m) => m.role == MuscleRole.primary && muscles.contains(m.muscleId),
        );

    List<EngineExercise> filtered = all.where((ex) {
      if (excludeIds != null && excludeIds.contains(ex.id)) return false;
      if (!isCompound(ex)) return false;
      return true;
    }).toList();

    switch (focus) {
      case SessionFocus.push:
        return filtered
            .where(
              (ex) =>
                  isUpper(ex) &&
                  hasPrimaryMuscle(ex, {'pectorals', 'anterior_deltoid', 'lateral_deltoid', 'triceps'}),
            )
            .toList();

      case SessionFocus.pull:
        return filtered
            .where(
              (ex) =>
                  isUpper(ex) && hasPrimaryMuscle(ex, {'lats', 'biceps', 'rear_deltoid'}),
            )
            .toList();

      case SessionFocus.legs:
        return filtered
            .where(
              (ex) =>
                  isLower(ex) &&
                  hasPrimaryMuscle(ex, {'quadriceps', 'glutes', 'hamstrings'}),
            )
            .toList();

      case SessionFocus.upper:
        return filtered.where(isUpper).toList();

      case SessionFocus.lower:
        return filtered.where(isLower).toList();

      case SessionFocus.fullBody:
        return filtered;
    }
  }
}
