import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
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
      expect(profile.goal, HypertrophyGoal.hypertrophy);
      expect(profile.availableDays, [1, 3, 5]);
      expect(profile.maxSessionDuration, const Duration(minutes: 60));
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
}
