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

    test('maps a timed-only completed session with duration stress data', () {
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
      expect(engineSession.sets.single.rpe, 7.0);
      expect(engineSession.sets.single.rpeEstimated, isTrue);
    });
  });
}
