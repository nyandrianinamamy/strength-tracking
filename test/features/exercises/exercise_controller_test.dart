import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_controller.dart';

void main() {
  late ProviderContainer container;

  final initialState = AppState(
    exercises: [
      const Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 10,
      ),
      const Exercise(
        id: 'ex2',
        name: 'Squat',
        primaryMuscles: ['Quads'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 5,
      ),
      const Exercise(
        id: 'ex3',
        name: 'Deadlift',
        primaryMuscles: ['Back'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 20,
      ),
    ],
    routines: [],
    sessions: [],
  );

  setUp(() {
    final repository = MemoryAppStateRepository(initialState: initialState);
    container = ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ExerciseController', () {
    test('search returns exercises sorted by useCount descending', () {
      final controller = container.read(exerciseControllerProvider);
      final results = controller.search('');
      expect(results.map((e) => e.id).toList(), ['ex3', 'ex1', 'ex2']);
    });

    test('search breaks useCount ties by lastUsedAt descending', () {
      // Override with two exercises having the same useCount
      final repo = MemoryAppStateRepository(
        initialState: AppState(
          exercises: [
            Exercise(
              id: 'a',
              name: 'A',
              primaryMuscles: ['Chest'],
              equipment: [],
              instructions: '',
              archived: false,
              useCount: 5,
              lastUsedAt: DateTime(2026, 1, 1),
            ),
            Exercise(
              id: 'b',
              name: 'B',
              primaryMuscles: ['Back'],
              equipment: [],
              instructions: '',
              archived: false,
              useCount: 5,
              lastUsedAt: DateTime(2026, 4, 1),
            ),
          ],
          routines: [],
          sessions: [],
        ),
      );
      final c = ProviderContainer(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(repo),
          initialAppStateProvider.overrideWithValue(repo.state),
        ],
      );
      addTearDown(c.dispose);

      final results = c.read(exerciseControllerProvider).search('');
      expect(results.map((e) => e.id).toList(), ['b', 'a']);
    });

    test('recordUsage increments useCount and sets lastUsedAt', () {
      final controller = container.read(exerciseControllerProvider);
      controller.recordUsage('ex2');
      final state = container.read(appStateControllerProvider);
      final updated = state.exerciseById('ex2')!;
      expect(updated.useCount, 6);
      expect(updated.lastUsedAt, isNotNull);
    });
  });
}
