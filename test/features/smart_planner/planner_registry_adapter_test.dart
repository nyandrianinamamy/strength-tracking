// test/features/smart_planner/planner_registry_adapter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/smart_planner/planner_registry_adapter.dart';

void main() {
  group('PlannerRegistryAdapter', () {
    test('builds registry with user exercises mapped via adapter', () {
      final exercises = [
        const Exercise(
          id: 'ex1',
          name: 'Bench Press',
          primaryMuscles: ['Chest'],
          secondaryMuscles: ['Triceps'],
          equipment: ['Barbell'],
          instructions: '',
          archived: false,
          exerciseType: 'strength',
        ),
      ];

      final registry = PlannerRegistryAdapter.buildRegistry(exercises);

      // Should find the exercise by ID
      expect(registry.lookup('ex1'), isNotNull);
      expect(registry.lookup('ex1')!.name, 'Bench Press');
    });

    test('includes default exercises from engine registry', () {
      final registry = PlannerRegistryAdapter.buildRegistry(const []);

      // Default registry has exercises
      expect(registry.all, isNotEmpty);
    });

    test('user exercise with same ID as a default is findable in registry', () {
      final exercises = [
        const Exercise(
          id: 'barbell_bench_press',
          name: 'My Custom Bench',
          primaryMuscles: ['Chest'],
          secondaryMuscles: [],
          equipment: ['Barbell'],
          instructions: '',
          archived: false,
          exerciseType: 'strength',
        ),
      ];

      final registry = PlannerRegistryAdapter.buildRegistry(exercises);
      final found = registry.lookup('barbell_bench_press');
      expect(found, isNotNull);
    });

    test('excludes archived built-ins from lookup and selection', () {
      final registry = PlannerRegistryAdapter.buildRegistry(const [
        Exercise(
          id: 'barbell_bench_press',
          name: 'Bench',
          primaryMuscles: ['Chest'],
          secondaryMuscles: [],
          equipment: [],
          instructions: '',
          archived: true,
        ),
      ]);
      expect(registry.lookup('barbell_bench_press'), isNull);
      expect(
        registry.all.map((e) => e.id),
        isNot(contains('barbell_bench_press')),
      );
      expect(
        registry.exercisesForMuscle('pectorals').map((e) => e.id),
        isNot(contains('barbell_bench_press')),
      );
    });

    test('skips archived exercises', () {
      final exercises = [
        const Exercise(
          id: 'ex_archived',
          name: 'Old Exercise',
          primaryMuscles: ['Chest'],
          secondaryMuscles: [],
          equipment: [],
          instructions: '',
          archived: true,
          exerciseType: 'strength',
        ),
      ];

      final registry = PlannerRegistryAdapter.buildRegistry(exercises);
      expect(registry.lookup('ex_archived'), isNull);
    });
  });
}
