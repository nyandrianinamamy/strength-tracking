import 'package:training_engine/training_engine.dart';

import '../../data/models/exercise.dart';
import '../../data/models/workout_session.dart';

/// Maps between Kotrana's AppState models and the training engine's domain
/// models.
///
/// This is a pure transformation layer — it has no state of its own and
/// does not interact with the engine directly.
class TrainingEngineAdapter {
  const TrainingEngineAdapter();

  // ---------------------------------------------------------------------------
  // Session mapping
  // ---------------------------------------------------------------------------

  /// Converts a Kotrana [WorkoutSession] to an [EngineSession].
  ///
  /// RPE backfill strategy for each [CompletedSet]:
  /// - If `set.rpe != null`: use it directly, `rpeEstimated = false`
  /// - Else if `session.rpe != null`: backfill with session RPE, `rpeEstimated = true`
  /// - Else: default to 8.0, `rpeEstimated = true`
  EngineSession toEngineSession(WorkoutSession session) {
    final fallbackRpe = (session.rpe ?? 8.0).clamp(5.0, 10.0);

    final mappedSets = session.completedSets.map((set) {
      final double setRpe;
      final bool estimated;

      if (set.rpe != null) {
        setRpe = set.rpe!.clamp(5.0, 10.0);
        estimated = false;
      } else {
        setRpe = fallbackRpe;
        estimated = true;
      }

      return LoggedSet(
        exerciseId: set.exerciseId,
        weightKg: set.weightKg,
        reps: set.reps,
        rpe: setRpe,
        completedAt: set.completedAt,
        rpeEstimated: estimated,
      );
    }).toList();

    return EngineSession(
      id: session.id,
      startedAt: session.startedAt,
      endedAt: session.endedAt ?? session.startedAt,
      sets: mappedSets,
      sessionRpe: session.rpe,
    );
  }

  // ---------------------------------------------------------------------------
  // Exercise mapping
  // ---------------------------------------------------------------------------

  /// Attempts to resolve a Kotrana [Exercise] to an [EngineExercise].
  ///
  /// Strategy:
  /// 1. Try exact ID match in [registry].
  /// 2. Try case-insensitive name match in [registry].
  /// 3. Construct a synthetic [EngineExercise] from the app exercise's
  ///    muscle lists, guessing movement class from the exercise name.
  /// 4. Returns `null` only when [exercise.primaryMuscles] is empty and no
  ///    registry match is found (nothing useful to map).
  EngineExercise? toEngineExercise(Exercise exercise, ExerciseRegistry registry) {
    // 1. Exact ID match
    final byId = registry.lookup(exercise.id);
    if (byId != null) return byId;

    // 2. Case-insensitive name match
    final lower = exercise.name.toLowerCase();
    final byName = registry.all.where(
      (e) => e.name.toLowerCase() == lower,
    );
    if (byName.isNotEmpty) return byName.first;

    // 3. Construct synthetic exercise if we have muscle information
    if (exercise.primaryMuscles.isEmpty) return null;

    final muscleMap = <MuscleActivation>[];
    for (final muscle in exercise.primaryMuscles) {
      muscleMap.add(MuscleActivation(
        muscleId: _normaliseMuscleId(muscle),
        role: MuscleRole.primary,
        coefficient: 1.0,
      ));
    }
    for (final muscle in exercise.secondaryMuscles) {
      muscleMap.add(MuscleActivation(
        muscleId: _normaliseMuscleId(muscle),
        role: MuscleRole.synergist,
        coefficient: 0.5,
      ));
    }

    return EngineExercise(
      id: exercise.id,
      name: exercise.name,
      muscleMap: muscleMap,
      equipment: _guessEquipment(exercise.equipment),
      movement: _guessMovement(exercise.name, exercise.primaryMuscles),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Normalises a human-readable muscle name to an engine muscle ID.
  ///
  /// Converts to lowercase and applies simple substitutions for common
  /// variations used in the app's exercise data.
  String _normaliseMuscleId(String muscle) {
    final m = muscle.toLowerCase().trim();
    // Common substitutions
    const substitutions = <String, String>{
      'chest': 'chest',
      'pectorals': 'chest',
      'pecs': 'chest',
      'shoulders': 'shoulder',
      'deltoid': 'shoulder',
      'anterior deltoid': 'shoulder',
      'lateral deltoid': 'shoulder',
      'posterior deltoid': 'rear_delt',
      'rear delts': 'rear_delt',
      'lats': 'back',
      'latissimus dorsi': 'back',
      'upper back': 'back',
      'trapezius': 'back',
      'biceps': 'bicep',
      'triceps': 'tricep',
      'quadriceps': 'quad',
      'quads': 'quad',
      'hamstrings': 'hamstring',
      'gluteus maximus': 'glute',
      'glutes': 'glute',
      'calves': 'calf',
      'gastrocnemius': 'calf',
      'core': 'core',
      'abdominals': 'core',
      'abs': 'core',
    };
    return substitutions[m] ?? m.replaceAll(' ', '_');
  }

  /// Guesses the [EquipmentClass] from a list of equipment strings.
  EquipmentClass _guessEquipment(List<String> equipment) {
    if (equipment.isEmpty) return EquipmentClass.barbell;
    final lower = equipment.map((e) => e.toLowerCase()).toList();
    if (lower.any((e) => e.contains('barbell'))) return EquipmentClass.barbell;
    if (lower.any((e) => e.contains('dumbbell'))) return EquipmentClass.dumbbell;
    if (lower.any((e) => e.contains('cable'))) return EquipmentClass.cable;
    if (lower.any((e) => e.contains('machine'))) return EquipmentClass.machine;
    if (lower.any((e) => e.contains('body') || e.contains('bodyweight'))) {
      return EquipmentClass.bodyweight;
    }
    return EquipmentClass.barbell;
  }

  /// Guesses the [MovementClass] from the exercise name and primary muscles.
  MovementClass _guessMovement(String name, List<String> primaryMuscles) {
    final n = name.toLowerCase();
    final muscles = primaryMuscles.map((m) => m.toLowerCase()).toList();

    // Compound lower: involves quads, hamstrings, glutes in name
    if (n.contains('squat') ||
        n.contains('deadlift') ||
        n.contains('leg press') ||
        n.contains('lunge') ||
        muscles.any((m) =>
            m.contains('quad') || m.contains('hamstring') || m.contains('glute'))) {
      return MovementClass.compoundLower;
    }

    // Compound upper: involves chest, back, or multi-joint upper body
    if (n.contains('bench') ||
        n.contains('press') ||
        n.contains('row') ||
        n.contains('pull') ||
        n.contains('dip') ||
        muscles.any((m) =>
            m.contains('chest') || m.contains('back') || m.contains('lat'))) {
      return MovementClass.compoundUpper;
    }

    return MovementClass.isolation;
  }
}
