import '../models/engine_exercise.dart';
import '../models/enums.dart';
import 'session_generator.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class SubstitutionResult {
  final PlannedSession session;

  /// Human-readable substitution notes, e.g.
  /// "Replaced Barbell Deadlift with Seated Leg Curl (erector_spinae fatigued)"
  final List<String> substitutions;

  const SubstitutionResult({
    required this.session,
    required this.substitutions,
  });
}

// ---------------------------------------------------------------------------
// Thresholds
// ---------------------------------------------------------------------------

/// Secondary muscle fatigue above this triggers a substitution.
const double _secondaryFatigueThreshold = 50.0;

/// Primary muscle fatigue above this triggers a warning flag (no auto-replace).
const double _primaryFatigueWarningThreshold = 60.0;

// ---------------------------------------------------------------------------
// Main function
// ---------------------------------------------------------------------------

/// Inspects every exercise in [session] and substitutes alternatives when a
/// **secondary** muscle shows high fatigue (> 50).  When the **primary**
/// muscle is highly fatigued (> 60), a warning is appended instead.
///
/// Substitution logic:
/// 1. Identify the primary muscle of the current exercise (highest-coefficient
///    activation or first `MuscleRole.primary` entry).
/// 2. Look up alternatives that target the same primary muscle but do **not**
///    use the fatigued secondary muscle (the registry excludes IDs already in
///    the session and the original exercise).
/// 3. If an alternative is found, replace; otherwise keep original and note
///    that no substitute was available.
SubstitutionResult adjustSessionForFatigue(
  PlannedSession session,
  Map<String, double> fatigueMap,
  ExerciseRegistryLookup registry,
) {
  final substitutions = <String>[];
  final updatedExercises = <PlannedExercise>[];

  // Track exercise IDs already in the session to avoid duplicates
  final usedIds = session.exercises.map((e) => e.exerciseId).toSet();

  for (final planned in session.exercises) {
    // Resolve EngineExercise from registry by asking for any exercise matching
    // this ID; we use a helper that retrieves the full exercise data.
    final engineEx = _resolveExercise(planned.exerciseId, registry);

    if (engineEx == null) {
      // Registry doesn't know this exercise – keep as-is
      updatedExercises.add(planned);
      continue;
    }

    // Determine primary muscle (highest coefficient among primaries)
    String? primaryMuscleId;
    double bestCoeff = -1;
    for (final a in engineEx.muscleMap) {
      if (a.role == MuscleRole.primary && a.coefficient > bestCoeff) {
        bestCoeff = a.coefficient;
        primaryMuscleId = a.muscleId;
      }
    }

    // Check secondary muscles for fatigue
    final fatiguedSecondaries = engineEx.muscleMap
        .where(
          (a) =>
              a.role != MuscleRole.primary &&
              (fatigueMap[a.muscleId] ?? 0.0) > _secondaryFatigueThreshold,
        )
        .toList();

    // Check primary muscle fatigue
    final primaryFatigue = primaryMuscleId != null
        ? (fatigueMap[primaryMuscleId] ?? 0.0)
        : 0.0;

    if (fatiguedSecondaries.isNotEmpty) {
      // Try to find a substitute that works the same primary but avoids the
      // fatigued secondaries.
      final fatigued = fatiguedSecondaries.map((a) => a.muscleId).toSet();
      final candidateExclude = Set<String>.from(usedIds);

      final candidates = primaryMuscleId != null
          ? registry.exercisesForMuscle(
              primaryMuscleId,
              excludeIds: candidateExclude,
            )
          : <EngineExercise>[];

      EngineExercise? substitute;
      for (final c in candidates) {
        final muscleIds = c.muscleMap.map((a) => a.muscleId).toSet();
        if (!muscleIds.any((id) => fatigued.contains(id))) {
          substitute = c;
          break;
        }
      }

      if (substitute != null) {
        usedIds.add(substitute.id);
        usedIds.remove(planned.exerciseId);

        updatedExercises.add(planned.copyWith(exerciseId: substitute.id));
        substitutions.add(
          'Replaced ${engineEx.name} with ${substitute.name}'
          ' (${fatigued.join(', ')} fatigued)',
        );
        continue;
      } else {
        // No suitable substitute found – keep original but log
        substitutions.add(
          'Could not substitute ${engineEx.name}'
          ' (${fatigued.join(', ')} fatigued, no alternative found)',
        );
      }
    }

    // Primary muscle fatigue warning
    if (primaryFatigue > _primaryFatigueWarningThreshold) {
      substitutions.add(
        'Warning: $primaryMuscleId fatigue is high'
        ' (${primaryFatigue.toStringAsFixed(0)}) for ${engineEx.name} –'
        ' consider reducing intensity',
      );
    }

    updatedExercises.add(planned);
  }

  return SubstitutionResult(
    session: session.copyWith(exercises: updatedExercises),
    substitutions: substitutions,
  );
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Attempts to retrieve the [EngineExercise] for [id] via the registry.
/// Returns `null` if the registry cannot resolve it.
EngineExercise? _resolveExercise(String id, ExerciseRegistryLookup registry) {
  // Try each common muscle group to find the exercise by ID.
  // In a full implementation the registry would expose a direct lookup;
  // here we use a best-effort scan across known muscle IDs.
  const commonMuscles = [
    'pectorals', 'anterior_deltoid', 'lateral_deltoid', 'rear_deltoid',
    'triceps', 'lats', 'upper_back', 'biceps',
    'quadriceps', 'hamstrings', 'glutes', 'calves',
    'erector_spinae', 'abs',
  ];
  for (final muscle in commonMuscles) {
    final results = registry.exercisesForMuscle(muscle);
    for (final ex in results) {
      if (ex.id == id) return ex;
    }
  }
  return null;
}
