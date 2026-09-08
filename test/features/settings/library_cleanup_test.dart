import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/settings/library_cleanup.dart';

void main() {
  test(
    'clearing the library preserves workout history and referenced definitions',
    () {
      const exercise = Exercise(
        id: 'used',
        name: 'Historical Press',
        primaryMuscles: ['Chest'],
        equipment: [],
        instructions: '',
        archived: false,
      );
      const routine = Routine(
        id: 'routine',
        name: 'Historical Routine',
        category: 'strength',
        estimatedDurationMin: 10,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'used',
            targetSets: 1,
            targetReps: 5,
            restSeconds: 30,
            order: 0,
          ),
        ],
      );
      final session = WorkoutSession(
        id: 'history',
        routineId: 'routine',
        status: WorkoutSessionStatus.completed,
        startedAt: DateTime(2026, 9, 1),
        endedAt: DateTime(2026, 9, 1, 1),
        lastActivityAt: DateTime(2026, 9, 1, 1),
        currentExerciseIndex: 0,
        completedSets: const [],
        sessionNote: '',
        rpe: null,
      );
      final state = AppState(
        exercises: [
          exercise,
          exercise.copyWith(id: 'unused'),
        ],
        routines: [
          routine,
          routine.copyWith(id: 'unused'),
        ],
        sessions: [session],
      );
      final cleared = clearLibraryPreservingHistory(state);
      expect(cleared.sessions, [session]);
      expect(cleared.routines.single.id, 'routine');
      expect(cleared.routines.single.archived, isTrue);
      expect(cleared.exercises.single.id, 'used');
      expect(cleared.exercises.single.archived, isTrue);
    },
  );
}
