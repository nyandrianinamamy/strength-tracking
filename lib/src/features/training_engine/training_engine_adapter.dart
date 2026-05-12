import 'package:training_engine/training_engine.dart';

import '../../data/models/app_state.dart';
import '../../data/models/completed_set.dart';
import '../../data/models/exercise.dart';
import '../../data/models/workout_session.dart';

/// Maps between Kotrana's AppState models and the training engine's domain
/// models.
///
/// This is a pure transformation layer — it has no state of its own and
/// does not interact with the engine directly.
class TrainingEngineAdapter {
  const TrainingEngineAdapter();

  static const double _minStrengthRpe = 5.0;
  static const double _maxStrengthRpe = 10.0;

  /// Converts host app state into a minimal training-engine user profile.
  ///
  UserProfile toUserProfile(AppState appState) {
    final sex = appState.sex.toLowerCase() == 'female' ? Sex.female : Sex.male;

    return UserProfile(
      sex: sex,
      age: appState.age ?? 25,
      bodyWeightKg: appState.weight ?? 75.0,
      experience: ExperienceLevel.intermediate,
      goal: _mapFitnessGoal(appState.fitnessGoal),
      availableDays: const [1, 3, 5],
      maxSessionDuration: const Duration(minutes: 60),
      createdAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Session mapping
  // ---------------------------------------------------------------------------

  /// Converts a Kotrana [WorkoutSession] to an [EngineSession].
  ///
  /// RPE backfill strategy for each [CompletedSet]:
  /// - If `set.rpe` is 5-10: use it directly, `rpeEstimated = false`.
  /// - If `set.rpe` is outside 5-10: treat it as legacy app history and
  ///   exclude it from engine ingestion instead of silently changing it.
  /// - Else if `session.rpe` is 5-10: backfill with session RPE,
  ///   `rpeEstimated = true`.
  /// - Else: default to 8.0, `rpeEstimated = true`.
  EngineSession? toEngineSession(WorkoutSession session) {
    final fallbackRpe = _isSupportedStrengthRpe(session.rpe)
        ? session.rpe!
        : 8.0;
    final sessionRpe = _isSupportedStrengthRpe(session.rpe)
        ? session.rpe
        : null;

    final mappedSets = session.completedSets.where(_shouldMapSet).map((set) {
      final double setRpe;
      final bool estimated;

      if (set.rpe != null) {
        setRpe = set.rpe!;
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
        durationSeconds: set.durationSeconds,
      );
    }).toList();

    if (mappedSets.isEmpty) {
      return null;
    }

    return EngineSession(
      id: session.id,
      startedAt: session.startedAt,
      endedAt: session.endedAt ?? session.startedAt,
      sets: mappedSets,
      sessionRpe: sessionRpe,
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
  EngineExercise? toEngineExercise(
    Exercise exercise,
    ExerciseRegistry registry,
  ) {
    // 1. Exact ID match — re-key under the app's exercise ID
    final byId = registry.lookup(exercise.id);
    if (byId != null) {
      return EngineExercise(
        id: exercise.id,
        name: byId.name,
        muscleMap: byId.muscleMap,
        equipment: byId.equipment,
        movement: byId.movement,
      );
    }

    // 2. Case-insensitive name match — re-key under the app's exercise ID
    final lower = exercise.name.toLowerCase();
    final byName = registry.all.where((e) => e.name.toLowerCase() == lower);
    if (byName.isNotEmpty) {
      final matched = byName.first;
      return EngineExercise(
        id: exercise.id,
        name: matched.name,
        muscleMap: matched.muscleMap,
        equipment: matched.equipment,
        movement: matched.movement,
      );
    }

    // 3. Construct synthetic exercise if we have muscle information
    if (exercise.primaryMuscles.isEmpty) return null;

    final muscleMap = <MuscleActivation>[];
    for (final muscle in exercise.primaryMuscles) {
      muscleMap.add(
        MuscleActivation(
          muscleId: MuscleNormalizer.normalize(muscle),
          role: MuscleRole.primary,
          coefficient: 1.0,
        ),
      );
    }
    for (final muscle in exercise.secondaryMuscles) {
      muscleMap.add(
        MuscleActivation(
          muscleId: MuscleNormalizer.normalize(muscle),
          role: MuscleRole.synergist,
          coefficient: 0.5,
        ),
      );
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

  HypertrophyGoal _mapFitnessGoal(String fitnessGoal) {
    switch (fitnessGoal.trim().toLowerCase()) {
      case 'strength':
        return HypertrophyGoal.strength;
      case 'hypertrophy':
        return HypertrophyGoal.hypertrophy;
      case 'general_fitness':
      case 'endurance':
      case 'weight_loss':
      case '':
      default:
        return HypertrophyGoal.general;
    }
  }

  bool _hasEngineLoad(CompletedSet set) {
    return set.reps > 0 || set.durationSeconds > 0;
  }

  bool _isSupportedStrengthRpe(double? rpe) {
    return rpe != null && rpe >= _minStrengthRpe && rpe <= _maxStrengthRpe;
  }

  bool _shouldMapSet(CompletedSet set) {
    if (!_hasEngineLoad(set)) return false;
    return set.rpe == null || _isSupportedStrengthRpe(set.rpe);
  }

  /// Guesses the [EquipmentClass] from a list of equipment strings.
  EquipmentClass _guessEquipment(List<String> equipment) {
    if (equipment.isEmpty) return EquipmentClass.barbell;
    final lower = equipment.map((e) => e.toLowerCase()).toList();
    if (lower.any((e) => e.contains('barbell'))) return EquipmentClass.barbell;
    if (lower.any((e) => e.contains('dumbbell'))) {
      return EquipmentClass.dumbbell;
    }
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
        muscles.any(
          (m) =>
              m.contains('quad') ||
              m.contains('hamstring') ||
              m.contains('glute'),
        )) {
      return MovementClass.compoundLower;
    }

    // Compound upper: involves chest, back, or multi-joint upper body
    if (n.contains('bench') ||
        n.contains('press') ||
        n.contains('row') ||
        n.contains('pull') ||
        n.contains('dip') ||
        muscles.any(
          (m) => m.contains('chest') || m.contains('back') || m.contains('lat'),
        )) {
      return MovementClass.compoundUpper;
    }

    return MovementClass.isolation;
  }
}
