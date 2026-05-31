import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_adapter.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const adapter = TrainingEngineAdapter();

  group('TrainingEngineAdapter.toUserProfile', () {
    test('maps app state gender and host defaults into a user profile', () {
      const appState = AppState(
        exercises: [],
        routines: [],
        sessions: [],
        sex: 'female',
      );

      final profile = adapter.toUserProfile(appState);

      expect(profile.sex, Sex.female);
      expect(profile.age, 25);
      expect(profile.bodyWeightKg, 75.0);
      expect(profile.experience, ExperienceLevel.intermediate);
      expect(profile.goal, HypertrophyGoal.general);
      expect(profile.availableDays, [1, 3, 5]);
      expect(profile.maxSessionDuration, const Duration(minutes: 60));
    });

    test('maps captured age weight and explicit fitness goals', () {
      const strengthState = AppState(
        exercises: [],
        routines: [],
        sessions: [],
        age: 41,
        weight: 93.5,
        fitnessGoal: 'strength',
      );
      const hypertrophyState = AppState(
        exercises: [],
        routines: [],
        sessions: [],
        fitnessGoal: 'hypertrophy',
      );

      final strengthProfile = adapter.toUserProfile(strengthState);
      final hypertrophyProfile = adapter.toUserProfile(hypertrophyState);

      expect(strengthProfile.age, 41);
      expect(strengthProfile.bodyWeightKg, 93.5);
      expect(strengthProfile.goal, HypertrophyGoal.strength);
      expect(hypertrophyProfile.goal, HypertrophyGoal.hypertrophy);
    });

    test('maps app training profile preferences into the engine profile', () {
      const appState = AppState(
        exercises: [],
        routines: [],
        sessions: [],
        experience: 'advanced',
        availableDays: [1, 2, 4, 6],
        maxSessionDurationMinutes: 75,
      );

      final profile = adapter.toUserProfile(appState);

      expect(profile.experience, ExperienceLevel.advanced);
      expect(profile.availableDays, [1, 2, 4, 6]);
      expect(profile.maxSessionDuration, const Duration(minutes: 75));
    });

    test('falls back to intermediate for unknown experience values', () {
      const appState = AppState(
        exercises: [],
        routines: [],
        sessions: [],
        experience: 'expert',
      );

      final profile = adapter.toUserProfile(appState);

      expect(profile.experience, ExperienceLevel.intermediate);
    });

    test('maps non-strength goals to the general engine goal', () {
      for (final goal in ['', 'general_fitness', 'endurance', 'weight_loss']) {
        final profile = adapter.toUserProfile(
          AppState(
            exercises: const [],
            routines: const [],
            sessions: const [],
            fitnessGoal: goal,
          ),
        );

        expect(profile.goal, HypertrophyGoal.general, reason: goal);
      }
    });
  });

  group('TrainingEngineAdapter.toEngineExercise', () {
    test('returns the registry exercise on exact id match', () {
      final registry = ExerciseRegistry.withDefaults();
      const exercise = Exercise(
        id: 'barbell_back_squat',
        name: 'My Squat Alias',
        primaryMuscles: ['Quadriceps'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      );

      final mapped = adapter.toEngineExercise(exercise, registry);

      expect(mapped, isNotNull);
      expect(mapped!.id, 'barbell_back_squat');
      expect(mapped.name, 'Barbell Back Squat');
    });

    test('returns the registry exercise on case-insensitive name match', () {
      final registry = ExerciseRegistry.withDefaults();
      const exercise = Exercise(
        id: 'custom_bench_variant',
        name: 'barbell bench press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      );

      final mapped = adapter.toEngineExercise(exercise, registry);

      expect(mapped, isNotNull);
      // Re-keyed under the app's exercise ID so registry.lookup works during ingestion
      expect(mapped!.id, 'custom_bench_variant');
      expect(mapped.name, 'Barbell Bench Press');
      expect(mapped.muscleMap.any((m) => m.muscleId == 'pectorals'), isTrue);
    });

    test('builds a synthetic engine exercise when registry has no match', () {
      final registry = ExerciseRegistry.withDefaults();
      const exercise = Exercise(
        id: 'custom_cable_press',
        name: 'Custom Cable Press',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Triceps'],
        equipment: ['Cable'],
        instructions: '',
        archived: false,
      );

      final mapped = adapter.toEngineExercise(exercise, registry);

      expect(mapped, isNotNull);
      expect(mapped!.id, 'custom_cable_press');
      expect(mapped.equipment, EquipmentClass.cable);
      expect(mapped.movement, MovementClass.compoundUpper);
      expect(mapped.muscleMap.first.muscleId, 'pectorals');
      expect(mapped.muscleMap.first.role, MuscleRole.primary);
      expect(
        mapped.muscleMap.any(
          (muscle) =>
              muscle.muscleId == 'triceps' &&
              muscle.role == MuscleRole.synergist,
        ),
        isTrue,
      );
    });

    test(
      'maps treadmill to capped steady cardio with explicit local muscles',
      () {
        final registry = ExerciseRegistry.withDefaults();
        const exercise = Exercise(
          id: 'treadmill',
          name: 'Treadmill',
          primaryMuscles: ['Legs'],
          secondaryMuscles: [],
          equipment: ['Machine'],
          instructions: '',
          archived: false,
          exerciseType: 'timed',
        );

        final mapped = adapter.toEngineExercise(exercise, registry);

        expect(mapped, isNotNull);
        expect(mapped!.loadKind, ExerciseLoadKind.cardioSteady);
        expect(mapped.localFatigueKind, LocalFatigueKind.cardioAerobicLocal);
        expect(mapped.defaultEffortRpe, 5.0);
        expect(mapped.localFatigueCap, 60.0);
        final coefficients = {
          for (final activation in mapped.muscleMap)
            activation.muscleId: activation.coefficient,
        };
        expect(coefficients['quadriceps'], closeTo(0.45, 0.001));
        expect(coefficients['glutes'], closeTo(0.35, 0.001));
        expect(coefficients['calves'], closeTo(0.35, 0.001));
        expect(coefficients['hamstrings'], closeTo(0.25, 0.001));
        expect(coefficients['quadriceps'], isNot(1.0));
      },
    );

    test('maps custom timed cardio even when muscle lists are empty', () {
      final registry = ExerciseRegistry.withDefaults();
      const exercise = Exercise(
        id: 'hotel_treadmill',
        name: 'Hotel Treadmill',
        primaryMuscles: [],
        secondaryMuscles: [],
        equipment: ['Machine'],
        instructions: '',
        archived: false,
        exerciseType: 'timed',
      );

      final mapped = adapter.toEngineExercise(exercise, registry);

      expect(mapped, isNotNull);
      expect(mapped!.loadKind, ExerciseLoadKind.cardioSteady);
      expect(mapped.localFatigueKind, LocalFatigueKind.cardioAerobicLocal);
      expect(mapped.muscleMap, isNotEmpty);
      expect(
        mapped.muscleMap.any(
          (activation) => activation.muscleId == 'quadriceps',
        ),
        isTrue,
      );
    });

    test('maps plank to timed isometric defaults', () {
      final registry = ExerciseRegistry.withDefaults();
      const exercise = Exercise(
        id: 'plank',
        name: 'Plank',
        primaryMuscles: ['Abs'],
        secondaryMuscles: [],
        equipment: ['Bodyweight'],
        instructions: '',
        archived: false,
        exerciseType: 'timed',
      );

      final mapped = adapter.toEngineExercise(exercise, registry);

      expect(mapped, isNotNull);
      expect(mapped!.loadKind, ExerciseLoadKind.timedIsometric);
      expect(mapped.localFatigueKind, LocalFatigueKind.isometricHold);
      expect(mapped.defaultLocalRpe, 7.0);
      expect(mapped.localFatigueCap, 85.0);
    });
  });

  group('TrainingEngineAdapter.toEngineSession', () {
    test(
      'does not clamp explicit legacy set RPE below the engine contract',
      () {
        final completedAt = DateTime.utc(2026, 3, 7, 17, 0);
        final session = WorkoutSession(
          id: 'legacy-low-rpe-session-01',
          routineId: 'routine-strength',
          status: WorkoutSessionStatus.completed,
          startedAt: completedAt.subtract(const Duration(minutes: 20)),
          endedAt: completedAt,
          lastActivityAt: completedAt,
          currentExerciseIndex: 0,
          completedSets: [
            CompletedSet(
              exerciseId: 'barbell_bench_press',
              setNumber: 1,
              weightKg: 60,
              reps: 8,
              completedAt: completedAt,
              note: '',
              rpe: 4.0,
            ),
            CompletedSet(
              exerciseId: 'barbell_bench_press',
              setNumber: 2,
              weightKg: 70,
              reps: 6,
              completedAt: completedAt.add(const Duration(minutes: 3)),
              note: '',
              rpe: 7.0,
            ),
          ],
          sessionNote: '',
          rpe: null,
        );

        final engineSession = adapter.toEngineSession(session);

        expect(engineSession, isNotNull);
        expect(engineSession!.sets, hasLength(1));
        expect(engineSession.sets.single.weightKg, 70);
        expect(engineSession.sets.single.rpe, 7.0);
        expect(engineSession.sets.single.rpeEstimated, isFalse);
      },
    );

    test(
      'returns null when all completed strength sets have legacy RPE below 5',
      () {
        final completedAt = DateTime.utc(2026, 3, 7, 17, 0);
        final session = WorkoutSession(
          id: 'legacy-low-rpe-session-02',
          routineId: 'routine-strength',
          status: WorkoutSessionStatus.completed,
          startedAt: completedAt.subtract(const Duration(minutes: 20)),
          endedAt: completedAt,
          lastActivityAt: completedAt,
          currentExerciseIndex: 0,
          completedSets: [
            CompletedSet(
              exerciseId: 'barbell_bench_press',
              setNumber: 1,
              weightKg: 60,
              reps: 8,
              completedAt: completedAt,
              note: '',
              rpe: 4.0,
            ),
          ],
          sessionNote: '',
          rpe: null,
        );

        expect(adapter.toEngineSession(session), isNull);
      },
    );

    test(
      'maps a timed-only completed session with isometric local RPE data',
      () {
        final completedAt = DateTime.utc(2026, 3, 7, 17, 0);
        final session = WorkoutSession(
          id: 'timed-only-session-01',
          routineId: 'routine-core',
          status: WorkoutSessionStatus.completed,
          startedAt: completedAt.subtract(const Duration(minutes: 20)),
          endedAt: completedAt,
          lastActivityAt: completedAt,
          currentExerciseIndex: 0,
          completedSets: [
            CompletedSet(
              exerciseId: 'plank',
              setNumber: 1,
              weightKg: 0.0,
              reps: 0,
              durationSeconds: 75,
              completedAt: completedAt,
              note: '',
            ),
          ],
          sessionNote: '',
          rpe: 7.0,
        );

        final engineSession = adapter.toEngineSession(session);

        expect(engineSession, isNotNull);
        expect(engineSession!.sets, hasLength(1));
        expect(engineSession.sets.single.exerciseId, 'plank');
        expect(engineSession.sets.single.reps, 0);
        expect(engineSession.sets.single.durationSeconds, 75);
        expect(engineSession.sets.single.localRpe, 7.0);
        expect(engineSession.sets.single.strengthRpe, isNull);
        expect(engineSession.sets.single.rpeEstimated, isTrue);
      },
    );

    test(
      'maps missing timed cardio RPE to estimated effort 5, not strength 8',
      () {
        final completedAt = DateTime.utc(2026, 3, 7, 17, 0);
        final registry = ExerciseRegistry.withDefaults()
          ..addCustom(
            adapter.toEngineExercise(
              const Exercise(
                id: 'treadmill',
                name: 'Treadmill',
                primaryMuscles: ['Legs'],
                secondaryMuscles: [],
                equipment: ['Machine'],
                instructions: '',
                archived: false,
                exerciseType: 'timed',
              ),
              ExerciseRegistry.withDefaults(),
            )!,
          );
        final session = WorkoutSession(
          id: 'timed-cardio-session-01',
          routineId: 'routine-cardio',
          status: WorkoutSessionStatus.completed,
          startedAt: completedAt.subtract(const Duration(minutes: 12)),
          endedAt: completedAt,
          lastActivityAt: completedAt,
          currentExerciseIndex: 0,
          completedSets: [
            CompletedSet(
              exerciseId: 'treadmill',
              setNumber: 1,
              weightKg: 0.0,
              reps: 0,
              durationSeconds: 600,
              completedAt: completedAt,
              note: '',
            ),
          ],
          sessionNote: '',
          rpe: 8.0,
        );

        final engineSession = adapter.toEngineSession(
          session,
          registry: registry,
        );

        expect(engineSession, isNotNull);
        expect(engineSession!.sets.single.effortRpe, 5.0);
        expect(engineSession.sets.single.strengthRpe, isNull);
        expect(engineSession.sets.single.localRpe, isNull);
        expect(engineSession.sets.single.rpeEstimated, isTrue);
      },
    );
  });
}
