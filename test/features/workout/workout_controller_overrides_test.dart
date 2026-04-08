import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppState _makeState({
  String routineId = 'test_routine',
  String exerciseId = 'squat',
  String exerciseId2 = 'deadlift',
}) {
  return AppState(
    exercises: [
      const Exercise(
        id: 'squat',
        name: 'Squat',
        primaryMuscles: ['quads'],
        secondaryMuscles: [],
        archived: false,
        exerciseType: 'strength',
        equipment: ['barbell'],
        instructions: '',
      ),
      const Exercise(
        id: 'deadlift',
        name: 'Deadlift',
        primaryMuscles: ['hamstrings'],
        secondaryMuscles: [],
        archived: false,
        exerciseType: 'strength',
        equipment: ['barbell'],
        instructions: '',
      ),
      const Exercise(
        id: 'bench_press',
        name: 'Bench Press',
        primaryMuscles: ['chest'],
        secondaryMuscles: [],
        archived: false,
        exerciseType: 'strength',
        equipment: ['barbell'],
        instructions: '',
      ),
    ],
    routines: [
      Routine(
        id: routineId,
        name: 'Test Routine',
        category: 'Strength',
        estimatedDurationMin: 60,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: exerciseId,
            targetSets: 3,
            targetReps: 5,
            restSeconds: 90,
            order: 0,
          ),
        ],
      ),
    ],
    sessions: [],
    routineGroups: [],
    preferredUnit: 'kg',
    activeRoutineGroupId: null,
  );
}

ProviderContainer _makeContainer(AppState initialState) {
  final repository = MemoryAppStateRepository(initialState: initialState);
  final container = ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(repository),
      initialAppStateProvider.overrideWithValue(repository.state),
    ],
  );
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WorkoutController session overrides', () {
    test('addExercise writes to session overrides, not base routine', () {
      final initialState = _makeState();
      final container = _makeContainer(initialState);
      addTearDown(container.dispose);

      // Start a session
      container.read(routineControllerProvider).startSession('test_routine');

      // Verify base routine has 1 exercise
      final stateBefore = container.read(appStateControllerProvider);
      final routineBefore = stateBefore.routineById('test_routine')!;
      expect(routineBefore.exercises.length, 1);

      // Act: add a new exercise
      container.read(workoutControllerProvider).addExercise('bench_press');

      // Assert: session.exerciseOverrides has 2 entries
      final stateAfter = container.read(appStateControllerProvider);
      final session = stateAfter.activeSession!;
      expect(session.exerciseOverrides, isNotNull);
      expect(session.exerciseOverrides!.length, 2);
      expect(session.exerciseOverrides![1].exerciseId, 'bench_press');

      // Assert: base routine.exercises still has 1 entry (unchanged)
      final routineAfter = stateAfter.routineById('test_routine')!;
      expect(routineAfter.exercises.length, 1);
      expect(routineAfter.exercises[0].exerciseId, 'squat');
    });

    test('swapExercise writes to session overrides, not base routine', () {
      final initialState = _makeState();
      final container = _makeContainer(initialState);
      addTearDown(container.dispose);

      // Start a session
      container.read(routineControllerProvider).startSession('test_routine');

      // Verify base routine has squat at index 0
      final stateBefore = container.read(appStateControllerProvider);
      final routineBefore = stateBefore.routineById('test_routine')!;
      expect(routineBefore.exercises[0].exerciseId, 'squat');

      // Act: swap index 0 to deadlift
      container.read(workoutControllerProvider).swapExercise(0, 'deadlift');

      // Assert: session.exerciseOverrides[0].exerciseId == deadlift
      final stateAfter = container.read(appStateControllerProvider);
      final session = stateAfter.activeSession!;
      expect(session.exerciseOverrides, isNotNull);
      expect(session.exerciseOverrides![0].exerciseId, 'deadlift');

      // Assert: base routine.exercises[0].exerciseId == squat (unchanged)
      final routineAfter = stateAfter.routineById('test_routine')!;
      expect(routineAfter.exercises[0].exerciseId, 'squat');
    });

    test('effectiveExercises returns overrides when present', () {
      final initialState = _makeState();
      final container = _makeContainer(initialState);
      addTearDown(container.dispose);

      container.read(routineControllerProvider).startSession('test_routine');
      container.read(workoutControllerProvider).addExercise('bench_press');

      final effective =
          container.read(workoutControllerProvider).effectiveExercises();
      expect(effective.length, 2);
      expect(effective[0].exerciseId, 'squat');
      expect(effective[1].exerciseId, 'bench_press');
    });

    test('effectiveExercises returns base routine when no overrides', () {
      final initialState = _makeState();
      final container = _makeContainer(initialState);
      addTearDown(container.dispose);

      container.read(routineControllerProvider).startSession('test_routine');

      final effective =
          container.read(workoutControllerProvider).effectiveExercises();
      expect(effective.length, 1);
      expect(effective[0].exerciseId, 'squat');
    });

    test('swapExercise preserves other exercises in overrides', () {
      // Start with a routine that has 2 exercises, then swap the second one
      final initialState = AppState(
        exercises: [
          const Exercise(
            id: 'squat',
            name: 'Squat',
            primaryMuscles: ['quads'],
            secondaryMuscles: [],
            archived: false,
            exerciseType: 'strength',
            equipment: ['barbell'],
            instructions: '',
          ),
          const Exercise(
            id: 'deadlift',
            name: 'Deadlift',
            primaryMuscles: ['hamstrings'],
            secondaryMuscles: [],
            archived: false,
            exerciseType: 'strength',
            equipment: ['barbell'],
            instructions: '',
          ),
          const Exercise(
            id: 'bench_press',
            name: 'Bench Press',
            primaryMuscles: ['chest'],
            secondaryMuscles: [],
            archived: false,
            exerciseType: 'strength',
            equipment: ['barbell'],
            instructions: '',
          ),
        ],
        routines: [
          const Routine(
            id: 'test_routine',
            name: 'Test Routine',
            category: 'Strength',
            estimatedDurationMin: 60,
            archived: false,
            exercises: [
              RoutineExercise(
                exerciseId: 'squat',
                targetSets: 3,
                targetReps: 5,
                restSeconds: 90,
                order: 0,
              ),
              RoutineExercise(
                exerciseId: 'deadlift',
                targetSets: 3,
                targetReps: 5,
                restSeconds: 90,
                order: 1,
              ),
            ],
          ),
        ],
        sessions: [],
        routineGroups: [],
        preferredUnit: 'kg',
        activeRoutineGroupId: null,
      );

      final container = _makeContainer(initialState);
      addTearDown(container.dispose);

      container.read(routineControllerProvider).startSession('test_routine');

      // Swap index 1 (deadlift) to bench_press
      container.read(workoutControllerProvider).swapExercise(1, 'bench_press');

      final stateAfter = container.read(appStateControllerProvider);
      final session = stateAfter.activeSession!;

      // Overrides should have 2 entries
      expect(session.exerciseOverrides!.length, 2);
      // First entry unchanged
      expect(session.exerciseOverrides![0].exerciseId, 'squat');
      // Second entry swapped
      expect(session.exerciseOverrides![1].exerciseId, 'bench_press');

      // Base routine unchanged
      final routineAfter = stateAfter.routineById('test_routine')!;
      expect(routineAfter.exercises[1].exerciseId, 'deadlift');
    });
  });
}
