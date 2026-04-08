import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';

final workoutControllerProvider = Provider<WorkoutController>(
  WorkoutController.new,
);

class WorkoutController {
  WorkoutController(this._ref);

  final Ref _ref;

  WorkoutSession? resumeActive() =>
      _ref.read(appStateControllerProvider).activeSession;

  /// Returns the session-scoped exercise list if overrides exist,
  /// otherwise the base routine's exercises.
  List<RoutineExercise> effectiveExercises() {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return [];
    final routine = state.routineById(session.routineId);
    if (routine == null) return [];
    return session.exerciseOverrides ?? routine.exercises;
  }

  WorkoutSession? logSet({
    required double weightKg,
    required int reps,
    String note = '',
    double? rpe,
  }) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) {
      return null;
    }

    final routine = state.routineById(session.routineId);
    if (routine == null) return null;

    final exercises = session.exerciseOverrides ?? routine.exercises;
    if (exercises.isEmpty) return null;

    final currentExercise =
        exercises[session.currentExerciseIndex.clamp(
          0,
          exercises.length - 1,
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
      rpe: rpe,
    );

    var nextExerciseIndex = session.currentExerciseIndex;
    if (existingSets + 1 >= currentExercise.targetSets &&
        session.currentExerciseIndex < exercises.length - 1) {
      nextExerciseIndex += 1;
    }

    final updatedSession = session.copyWith(
      lastActivityAt: nextSet.completedAt,
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
    if (routine == null) return null;

    final exercises = session.exerciseOverrides ?? routine.exercises;
    if (exercises.isEmpty) return null;

    final currentExercise =
        exercises[session.currentExerciseIndex.clamp(
          0,
          exercises.length - 1,
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
        session.currentExerciseIndex < exercises.length - 1) {
      nextExerciseIndex += 1;
    }

    final updatedSession = session.copyWith(
      lastActivityAt: nextSet.completedAt,
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

    _persistSession(
      session.copyWith(
        lastActivityAt: DateTime.now(),
        completedSets: renumbered,
      ),
    );
  }

  void updateSet(
    String exerciseId,
    int setNumber, {
    double? weightKg,
    int? reps,
    int? durationSeconds,
    double? rpe,
    bool clearRpe = false,
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
          rpe: rpe,
          clearRpe: clearRpe,
        );
      }
      return s;
    }).toList();

    _persistSession(
      session.copyWith(
        lastActivityAt: DateTime.now(),
        completedSets: updatedSets,
      ),
    );
  }

  WorkoutSession? skipExercise() {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) {
      return null;
    }

    final routine = state.routineById(session.routineId);
    if (routine == null) return null;

    final exercises = session.exerciseOverrides ?? routine.exercises;
    if (exercises.isEmpty) return null;

    final nextIndex = (session.currentExerciseIndex + 1).clamp(
      0,
      exercises.length - 1,
    );
    final updatedSession = session.copyWith(
      lastActivityAt: DateTime.now(),
      currentExerciseIndex: nextIndex,
    );
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
    if (routine == null) return null;

    final exercises = session.exerciseOverrides ?? routine.exercises;
    if (exercises.isEmpty) return null;

    final clampedIndex = index.clamp(0, exercises.length - 1);
    if (clampedIndex == session.currentExerciseIndex) {
      return session;
    }

    final updatedSession = session.copyWith(
      lastActivityAt: DateTime.now(),
      currentExerciseIndex: clampedIndex,
    );
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
      lastActivityAt: DateTime.now(),
      rpe: rpe ?? session.rpe ?? 8.0,
    );

    unawaited(_syncTrainingEngine(updatedSession));
    _persistSession(updatedSession);
    _ref
        .read(routineGroupControllerProvider)
        .markRoutineCompleted(updatedSession.routineId);
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
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void deleteSession(String sessionId) {
    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (state) => state.copyWith(
            sessions: state.sessions.where((s) => s.id != sessionId).toList(),
          ),
        );
  }

  void updateSessionNote(String note) {
    final session = _ref.read(appStateControllerProvider).activeSession;
    if (session == null) {
      return;
    }

    _persistSession(
      session.copyWith(
        lastActivityAt: DateTime.now(),
        sessionNote: note,
      ),
    );
  }

  void updateRpe(String sessionId, double rpe) {
    final session = _ref
        .read(appStateControllerProvider)
        .sessionById(sessionId);
    if (session == null) {
      return;
    }

    _persistSession(
      session.copyWith(
        lastActivityAt: DateTime.now(),
        rpe: rpe,
      ),
    );
  }

  void swapExercise(int exerciseIndex, String newExerciseId) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    final routine = state.routineById(session.routineId);
    if (routine == null) return;

    // Snapshot routine exercises into overrides on first edit
    final exercises = List.of(session.exerciseOverrides ?? routine.exercises);
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) return;

    exercises[exerciseIndex] = exercises[exerciseIndex].copyWith(
      exerciseId: newExerciseId,
    );

    _persistSession(session.copyWith(
      exerciseOverrides: exercises,
      lastActivityAt: DateTime.now(),
    ));
  }

  void addExercise(String exerciseId) {
    final state = _ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    final routine = state.routineById(session.routineId);
    if (routine == null) return;

    final exercise = state.exerciseById(exerciseId);
    final isTimed = exercise?.exerciseType == 'timed';

    final exercises = List.of(session.exerciseOverrides ?? routine.exercises);

    final newRoutineExercise = RoutineExercise(
      exerciseId: exerciseId,
      targetSets: isTimed ? 1 : 3,
      targetReps: isTimed ? 0 : 8,
      targetDurationSeconds: isTimed ? 60 : 60,
      restSeconds: isTimed ? 0 : 90,
      order: exercises.length,
    );

    exercises.add(newRoutineExercise);

    _persistSession(session.copyWith(
      exerciseOverrides: exercises,
      lastActivityAt: DateTime.now(),
    ));
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

  Future<void> _syncTrainingEngine(WorkoutSession session) async {
    if (session.completedSets.isEmpty) {
      return;
    }

    try {
      final adapter = _ref.read(trainingEngineAdapterProvider);
      final engineSession = adapter.toEngineSession(session);
      if (engineSession == null) {
        return;
      }
      await _ref
          .read(trainingEngineControllerProvider)
          .ingestSession(engineSession);
    } catch (error) {
      debugPrint('Failed to sync completed workout into training engine: $error');
    }
  }
}
