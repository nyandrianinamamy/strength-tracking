import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

final routineControllerProvider = Provider<RoutineController>(
  RoutineController.new,
);

class RoutineController {
  RoutineController(this._ref);

  final Ref _ref;

  Routine create({
    required String name,
    required String category,
    required List<RoutineExercise> exercises,
    required int estimatedDurationMin,
  }) {
    final routine = Routine(
      id: 'routine_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      category: category,
      exercises: exercises,
      estimatedDurationMin: estimatedDurationMin,
      archived: false,
    );

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (state) => state.copyWith(routines: [...state.routines, routine]),
        );

    return routine;
  }

  Routine update({
    required String routineId,
    required String name,
    required String category,
    required List<RoutineExercise> exercises,
    required int estimatedDurationMin,
  }) {
    final state = _ref.read(appStateControllerProvider);
    final routine = state.routineById(routineId)!;
    final updated = routine.copyWith(
      name: name.trim(),
      category: category,
      exercises: exercises,
      estimatedDurationMin: estimatedDurationMin,
    );

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(
            routines: currentState.routines
                .map((item) => item.id == routineId ? updated : item)
                .toList(),
          ),
        );

    return updated;
  }

  void archive(String routineId) {
    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (state) => state.copyWith(
            routines: state.routines
                .map(
                  (routine) => routine.id == routineId
                      ? routine.copyWith(archived: true)
                      : routine,
                )
                .toList(),
          ),
        );
  }

  WorkoutSession startSession(String routineId) {
    final state = _ref.read(appStateControllerProvider);
    final active = state.activeSession;
    if (active != null) {
      return active;
    }

    final session = WorkoutSession(
      id: 'session_${DateTime.now().microsecondsSinceEpoch}',
      routineId: routineId,
      status: WorkoutSessionStatus.active,
      startedAt: DateTime.now(),
      endedAt: null,
      currentExerciseIndex: 0,
      completedSets: const [],
      sessionNote: '',
      rpe: null,
    );

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(
            sessions: [...currentState.sessions, session],
          ),
        );

    return session;
  }
}
