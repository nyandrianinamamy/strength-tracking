import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

final workoutControllerProvider = Provider<WorkoutController>(
  WorkoutController.new,
);

class WorkoutController {
  WorkoutController(this._ref);

  final Ref _ref;

  WorkoutSession? resumeActive() =>
      _ref.read(appStateControllerProvider).activeSession;

  WorkoutSession? logSet({
    required double weightKg,
    required int reps,
    String note = '',
  }) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) {
      return null;
    }

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) {
      return null;
    }

    final currentExercise =
        routine.exercises[session.currentExerciseIndex.clamp(
          0,
          routine.exercises.length - 1,
        )];
    final existingSets = session.completedSets
        .where((set) => set.exerciseId == currentExercise.exerciseId)
        .length;

    final nextSet = CompletedSet(
      exerciseId: currentExercise.exerciseId,
      setNumber: existingSets + 1,
      weightKg: weightKg,
      reps: reps,
      completedAt: DateTime.now(),
      note: note,
    );

    var nextExerciseIndex = session.currentExerciseIndex;
    if (existingSets + 1 >= currentExercise.targetSets &&
        session.currentExerciseIndex < routine.exercises.length - 1) {
      nextExerciseIndex += 1;
    }

    final updatedSession = session.copyWith(
      currentExerciseIndex: nextExerciseIndex,
      completedSets: [...session.completedSets, nextSet],
    );

    _persistSession(updatedSession);
    return updatedSession;
  }

  WorkoutSession? logTimedSet({
    required int durationSeconds,
    String note = '',
  }) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return null;

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) return null;

    final currentExercise =
        routine.exercises[session.currentExerciseIndex.clamp(
          0,
          routine.exercises.length - 1,
        )];
    final existingSets = session.completedSets
        .where((set) => set.exerciseId == currentExercise.exerciseId)
        .length;

    final nextSet = CompletedSet(
      exerciseId: currentExercise.exerciseId,
      setNumber: existingSets + 1,
      weightKg: 0,
      reps: 0,
      durationSeconds: durationSeconds,
      completedAt: DateTime.now(),
      note: note,
    );

    var nextExerciseIndex = session.currentExerciseIndex;
    if (existingSets + 1 >= currentExercise.targetSets &&
        session.currentExerciseIndex < routine.exercises.length - 1) {
      nextExerciseIndex += 1;
    }

    final updatedSession = session.copyWith(
      currentExerciseIndex: nextExerciseIndex,
      completedSets: [...session.completedSets, nextSet],
    );

    _persistSession(updatedSession);
    return updatedSession;
  }

  void deleteSet(String exerciseId, int setNumber) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    final updatedSets = session.completedSets
        .where((s) => !(s.exerciseId == exerciseId && s.setNumber == setNumber))
        .toList();

    // Renumber remaining sets for this exercise
    int num = 1;
    final renumbered = updatedSets.map((s) {
      if (s.exerciseId == exerciseId) {
        return s.copyWith(setNumber: num++);
      }
      return s;
    }).toList();

    _persistSession(session.copyWith(completedSets: renumbered));
  }

  void updateSet(String exerciseId, int setNumber, {
    double? weightKg,
    int? reps,
    int? durationSeconds,
  }) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    final updatedSets = session.completedSets.map((s) {
      if (s.exerciseId == exerciseId && s.setNumber == setNumber) {
        return s.copyWith(
          weightKg: weightKg ?? s.weightKg,
          reps: reps ?? s.reps,
          durationSeconds: durationSeconds ?? s.durationSeconds,
        );
      }
      return s;
    }).toList();

    _persistSession(session.copyWith(completedSets: updatedSets));
  }

  WorkoutSession? skipExercise() {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) {
      return null;
    }

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) {
      return null;
    }

    final nextIndex = (session.currentExerciseIndex + 1).clamp(
      0,
      routine.exercises.length - 1,
    );
    final updatedSession = session.copyWith(currentExerciseIndex: nextIndex);
    _persistSession(updatedSession);
    return updatedSession;
  }

  WorkoutSession? goToExercise(int index) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) {
      return null;
    }

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) {
      return null;
    }

    final clampedIndex = index.clamp(0, routine.exercises.length - 1);
    if (clampedIndex == session.currentExerciseIndex) {
      return session;
    }

    final updatedSession =
        session.copyWith(currentExerciseIndex: clampedIndex);
    _persistSession(updatedSession);
    return updatedSession;
  }

  WorkoutSession? completeSession({double? rpe}) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) {
      return null;
    }

    final updatedSession = session.copyWith(
      status: WorkoutSessionStatus.completed,
      endedAt: DateTime.now(),
      rpe: rpe ?? session.rpe ?? 8.0,
    );

    _persistSession(updatedSession);
    return updatedSession;
  }

  void discardDraft() {
    final session = _ref.read(appStateControllerProvider).activeSession;
    if (session == null) {
      return;
    }

    _persistSession(
      session.copyWith(
        status: WorkoutSessionStatus.discarded,
        endedAt: DateTime.now(),
      ),
    );
  }

  void deleteSession(String sessionId) {
    _ref.read(appStateControllerProvider.notifier).updateState(
      (state) => state.copyWith(
        sessions: state.sessions
            .where((s) => s.id != sessionId)
            .toList(),
      ),
    );
  }

  void updateSessionNote(String note) {
    final session = _ref.read(appStateControllerProvider).activeSession;
    if (session == null) {
      return;
    }

    _persistSession(session.copyWith(sessionNote: note));
  }

  void updateRpe(String sessionId, double rpe) {
    final session = _ref
        .read(appStateControllerProvider)
        .sessionById(sessionId);
    if (session == null) {
      return;
    }

    _persistSession(session.copyWith(rpe: rpe));
  }

  /// Swaps the exercise at [exerciseIndex] in the active session's routine
  /// with [newExerciseId]. This modifies the routine in-place for the current
  /// session; the user can always swap back or edit the routine later.
  void swapExercise(int exerciseIndex, String newExerciseId) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    final routine = state.routineById(session.routineId);
    if (routine == null) return;

    if (exerciseIndex < 0 || exerciseIndex >= routine.exercises.length) return;

    final updatedExercises = List.of(routine.exercises);
    updatedExercises[exerciseIndex] = updatedExercises[exerciseIndex].copyWith(
      exerciseId: newExerciseId,
    );

    final updatedRoutine = routine.copyWith(exercises: updatedExercises);

    _ref.read(appStateControllerProvider.notifier).updateState(
      (s) => s.copyWith(
        routines: s.routines
            .map((r) => r.id == updatedRoutine.id ? updatedRoutine : r)
            .toList(),
      ),
    );
  }

  void _persistSession(WorkoutSession updatedSession) {
    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (state) => state.copyWith(
            sessions: state.sessions
                .map(
                  (session) => session.id == updatedSession.id
                      ? updatedSession
                      : session,
                )
                .toList(),
          ),
        );
  }
}
