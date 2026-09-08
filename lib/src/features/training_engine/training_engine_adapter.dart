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
  static const double _defaultStrengthRpe = 8.0;
  static const double _defaultCardioEffortRpe = 5.0;
  static const double _defaultIsometricRpe = 7.0;

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
  /// - Strength uses strength RPE, falling back to session RPE or 8.0.
  /// - Timed isometrics use local RPE, falling back to 7.0.
  /// - Timed cardio uses effort RPE, falling back to 5.0.
  /// Missing timed-cardio effort deliberately ignores default session RPE 8.
  EngineSession? toEngineSession(
    WorkoutSession session, {
    ExerciseRegistry? registry,
  }) {
    final sessionRpe = _isSupportedStrengthRpe(session.rpe)
        ? session.rpe
        : null;

    final mappedSets = session.completedSets
        .where((set) => shouldMapSet(set, registry: registry))
        .map(
          (set) => toLoggedSet(
            set,
            sessionRpe: sessionRpe,
            exercise: registry?.lookup(set.exerciseId),
          ),
        )
        .toList();

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

  LoggedSet toLoggedSet(
    CompletedSet set, {
    double? sessionRpe,
    EngineExercise? exercise,
  }) {
    final kind = exercise?.localFatigueKind;
    if (kind == LocalFatigueKind.cardioAerobicLocal) {
      final effort = _isSupportedEffortRpe(set.rpe)
          ? set.rpe!
          : (exercise?.defaultEffortRpe ?? _defaultCardioEffortRpe);
      return LoggedSet(
        exerciseId: set.exerciseId,
        weightKg: set.weightKg,
        reps: set.reps,
        effortRpe: effort,
        completedAt: set.completedAt,
        rpeEstimated: set.rpe == null,
        durationSeconds: set.durationSeconds,
      );
    }

    if (kind == LocalFatigueKind.isometricHold ||
        (set.reps == 0 && set.durationSeconds > 0)) {
      final localRpe = _isSupportedStrengthRpe(set.rpe)
          ? set.rpe!
          : (exercise?.defaultLocalRpe ?? sessionRpe ?? _defaultIsometricRpe);
      return LoggedSet(
        exerciseId: set.exerciseId,
        weightKg: set.weightKg,
        reps: set.reps,
        localRpe: localRpe,
        completedAt: set.completedAt,
        rpeEstimated: set.rpe == null,
        durationSeconds: set.durationSeconds,
      );
    }

    final strengthRpe = resolveStrengthRpe(set.rpe, sessionRpe);
    return LoggedSet(
      exerciseId: set.exerciseId,
      weightKg: set.weightKg,
      reps: set.reps,
      strengthRpe: strengthRpe,
      completedAt: set.completedAt,
      rpeEstimated: set.rpe == null,
      durationSeconds: set.durationSeconds,
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
      return _withAppExerciseLoadKind(
        EngineExercise(
          id: exercise.id,
          name: byId.name,
          muscleMap: byId.muscleMap,
          equipment: byId.equipment,
          movement: byId.movement,
        ),
        exercise,
      );
    }

    // 2. Case-insensitive name match — re-key under the app's exercise ID
    final lower = exercise.name.toLowerCase();
    final byName = registry.all.where((e) => e.name.toLowerCase() == lower);
    if (byName.isNotEmpty) {
      final matched = byName.first;
      return _withAppExerciseLoadKind(
        EngineExercise(
          id: exercise.id,
          name: matched.name,
          muscleMap: matched.muscleMap,
          equipment: matched.equipment,
          movement: matched.movement,
        ),
        exercise,
      );
    }

    // 3. Known timed cardio can be classified from its identity even when
    // the editor has not captured explicit muscles.
    final cardio = _cardioExerciseFor(exercise);
    if (cardio != null) return cardio;

    // 4. Construct synthetic exercise if we have muscle information
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

    return _withAppExerciseLoadKind(
      EngineExercise(
        id: exercise.id,
        name: exercise.name,
        muscleMap: muscleMap,
        equipment: _guessEquipment(exercise.equipment),
        movement: _guessMovement(exercise.name, exercise.primaryMuscles),
      ),
      exercise,
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

  /// Uses the same supported strength channel for replay and historical PRs.
  double resolveStrengthRpe(double? setRpe, double? sessionRpe) {
    if (_isSupportedStrengthRpe(setRpe)) return setRpe!;
    if (_isSupportedStrengthRpe(sessionRpe)) return sessionRpe!;
    return _defaultStrengthRpe;
  }

  bool _isSupportedStrengthRpe(double? rpe) {
    return rpe != null &&
        rpe.isFinite &&
        rpe >= _minStrengthRpe &&
        rpe <= _maxStrengthRpe;
  }

  bool _isSupportedEffortRpe(double? rpe) {
    return rpe != null && rpe >= 0.0 && rpe <= 10.0;
  }

  bool shouldMapSet(CompletedSet set, {ExerciseRegistry? registry}) {
    if (!_hasEngineLoad(set)) return false;
    final kind = registry?.lookup(set.exerciseId)?.localFatigueKind;
    if (kind == LocalFatigueKind.cardioAerobicLocal) {
      return set.rpe == null || _isSupportedEffortRpe(set.rpe);
    }
    return set.rpe == null || _isSupportedStrengthRpe(set.rpe);
  }

  EngineExercise _withAppExerciseLoadKind(
    EngineExercise mapped,
    Exercise source,
  ) {
    if (source.exerciseType != 'timed') return mapped;
    final cardio = _cardioExerciseFor(source);
    if (cardio != null) return cardio;
    return EngineExercise(
      id: mapped.id,
      name: mapped.name,
      muscleMap: mapped.muscleMap,
      equipment: mapped.equipment,
      movement: mapped.movement,
      loadKind: ExerciseLoadKind.timedIsometric,
      localFatigueKind: LocalFatigueKind.isometricHold,
      defaultLocalRpe: _defaultIsometricRpe,
      localFatigueCap: 85.0,
    );
  }

  EngineExercise? _cardioExerciseFor(Exercise exercise) {
    if (exercise.exerciseType != 'timed') return null;
    final key = exercise.id.toLowerCase();
    final name = exercise.name.toLowerCase();
    if (key.contains('treadmill') || name.contains('treadmill')) {
      return _cardioExercise(
        exercise,
        loadKind: ExerciseLoadKind.cardioSteady,
        localFatigueCap: 60.0,
        muscleCoefficients: const {
          'quadriceps': 0.45,
          'glutes': 0.35,
          'calves': 0.35,
          'hamstrings': 0.25,
          'hip_flexors': 0.20,
          'tibialis_anterior': 0.10,
          'core': 0.10,
        },
      );
    }
    if (key.contains('bike') || name.contains('bike')) {
      return _cardioExercise(
        exercise,
        loadKind: ExerciseLoadKind.cardioSteady,
        cardioLocalMultiplier: 0.95,
        metabolicMultiplier: 0.95,
        localFatigueCap: 55.0,
        muscleCoefficients: const {
          'quadriceps': 0.55,
          'glutes': 0.35,
          'calves': 0.25,
          'hamstrings': 0.20,
          'hip_flexors': 0.20,
          'core': 0.08,
        },
      );
    }
    if (key.contains('elliptical') || name.contains('elliptical')) {
      return _cardioExercise(
        exercise,
        loadKind: ExerciseLoadKind.cardioSteady,
        cardioLocalMultiplier: 0.90,
        metabolicMultiplier: 0.95,
        localFatigueCap: 55.0,
        muscleCoefficients: const {
          'quadriceps': 0.35,
          'glutes': 0.35,
          'calves': 0.25,
          'hamstrings': 0.25,
          'hip_flexors': 0.20,
          'core': 0.12,
          'upper_back': 0.10,
          'pectorals': 0.08,
          'biceps': 0.08,
          'triceps': 0.08,
        },
      );
    }
    if (key.contains('rowing') || name.contains('rowing')) {
      return _cardioExercise(
        exercise,
        loadKind: ExerciseLoadKind.cardioMixed,
        metabolicMultiplier: 1.10,
        localFatigueCap: 65.0,
        muscleCoefficients: const {
          'quadriceps': 0.35,
          'glutes': 0.35,
          'hamstrings': 0.25,
          'lats': 0.35,
          'upper_back': 0.30,
          'biceps': 0.20,
          'forearms': 0.15,
          'core': 0.25,
          'erector_spinae': 0.20,
        },
      );
    }
    if (key.contains('stair') || name.contains('stair')) {
      return _cardioExercise(
        exercise,
        loadKind: ExerciseLoadKind.cardioMixed,
        metabolicMultiplier: 1.15,
        localFatigueCap: 65.0,
        muscleCoefficients: const {
          'quadriceps': 0.45,
          'glutes': 0.45,
          'calves': 0.35,
          'hamstrings': 0.25,
          'hip_flexors': 0.20,
          'core': 0.12,
        },
      );
    }
    if (key.contains('jump_rope') || name.contains('jump rope')) {
      return _cardioExercise(
        exercise,
        loadKind: ExerciseLoadKind.cardioMixed,
        cardioLocalMultiplier: 1.15,
        metabolicMultiplier: 1.25,
        localFatigueCap: 65.0,
        muscleCoefficients: const {
          'calves': 0.55,
          'tibialis_anterior': 0.20,
          'quadriceps': 0.20,
          'glutes': 0.15,
          'hamstrings': 0.10,
          'core': 0.15,
          'forearms': 0.10,
          'anterior_deltoid': 0.08,
          'lateral_deltoid': 0.08,
        },
      );
    }
    return null;
  }

  EngineExercise _cardioExercise(
    Exercise exercise, {
    required ExerciseLoadKind loadKind,
    required double localFatigueCap,
    required Map<String, double> muscleCoefficients,
    double cardioLocalMultiplier = 1.0,
    double metabolicMultiplier = 1.0,
  }) {
    return EngineExercise(
      id: exercise.id,
      name: exercise.name,
      muscleMap: [
        for (final entry in muscleCoefficients.entries)
          MuscleActivation(
            muscleId: entry.key,
            role: MuscleRole.synergist,
            coefficient: entry.value,
          ),
      ],
      equipment: _guessEquipment(exercise.equipment),
      movement: MovementClass.compoundLower,
      loadKind: loadKind,
      localFatigueKind: LocalFatigueKind.cardioAerobicLocal,
      defaultEffortRpe: _defaultCardioEffortRpe,
      cardioLocalMultiplier: cardioLocalMultiplier,
      metabolicMultiplier: metabolicMultiplier,
      localFatigueCap: localFatigueCap,
    );
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
