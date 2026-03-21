import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

final workoutLiveActivityServiceProvider = Provider<WorkoutLiveActivityService>(
  WorkoutLiveActivityService.new,
);

class WorkoutLiveActivityService {
  WorkoutLiveActivityService(this._ref);

  static const MethodChannel _channel = MethodChannel(
    'com.strengthapp/live_activity',
  );

  final Ref _ref;
  bool _initialized = false;

  void initialize() {
    if (_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    _initialized = true;
    _ref.listen<AppState>(
      appStateControllerProvider,
      (_, next) => unawaited(_syncState(next)),
      fireImmediately: true,
    );
  }

  Future<void> _syncState(AppState state) async {
    final payload = WorkoutLiveActivityPayload.fromState(state);

    try {
      if (payload == null) {
        await _channel.invokeMethod<void>('endWorkout');
      } else {
        await _channel.invokeMethod<void>('syncWorkout', payload.toMap());
      }
    } catch (error) {
      debugPrint('Live Activity sync failed: $error');
    }
  }
}

class WorkoutLiveActivityPayload {
  const WorkoutLiveActivityPayload({
    required this.sessionId,
    required this.routineName,
    required this.currentExerciseName,
    required this.currentExerciseType,
    required this.currentExerciseIndex,
    required this.totalExercises,
    required this.completedSetsText,
    required this.currentExerciseProgressText,
    required this.exerciseDetailText,
    required this.startedAt,
    required this.updatedAt,
    required this.restEndAt,
    required this.restSeconds,
    required this.lastSetAt,
  });

  final String sessionId;
  final String routineName;
  final String currentExerciseName;
  final String currentExerciseType;
  final int currentExerciseIndex;
  final int totalExercises;
  final String completedSetsText;
  final String currentExerciseProgressText;
  final String exerciseDetailText;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? restEndAt;
  final int restSeconds;
  final DateTime? lastSetAt;

  bool get hasActiveRest => restEndAt != null && restEndAt!.isAfter(updatedAt);

  Map<String, Object?> toMap() {
    return {
      'sessionId': sessionId,
      'routineName': routineName,
      'currentExerciseName': currentExerciseName,
      'currentExerciseType': currentExerciseType,
      'currentExerciseIndex': currentExerciseIndex,
      'totalExercises': totalExercises,
      'completedSetsText': completedSetsText,
      'currentExerciseProgressText': currentExerciseProgressText,
      'exerciseDetailText': exerciseDetailText,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'restEndAt': restEndAt?.toUtc().toIso8601String(),
      'restSeconds': restSeconds,
      'lastSetAt': lastSetAt?.toUtc().toIso8601String(),
      'hasActiveRest': hasActiveRest,
    };
  }

  static WorkoutLiveActivityPayload? fromState(AppState state) {
    final session = state.activeSession;
    if (session == null) {
      return null;
    }

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) {
      return null;
    }

    final clampedIndex = session.currentExerciseIndex.clamp(
      0,
      routine.exercises.length - 1,
    );
    final currentRoutineExercise = routine.exercises[clampedIndex];
    final currentExercise = state.exerciseById(
      currentRoutineExercise.exerciseId,
    );
    if (currentExercise == null) {
      return null;
    }

    final currentExerciseSets = session.completedSets
        .where((set) => set.exerciseId == currentRoutineExercise.exerciseId)
        .length;
    final allSets = [...session.completedSets]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final lastSet = allSets.isEmpty ? null : allSets.first;
    final now = DateTime.now();
    final restContext = _buildRestContext(
      routine: routine,
      session: session,
      updatedAt: now,
      lastSet: lastSet,
    );

    return WorkoutLiveActivityPayload(
      sessionId: session.id,
      routineName: routine.name,
      currentExerciseName: currentExercise.name,
      currentExerciseType: currentExercise.exerciseType,
      currentExerciseIndex: clampedIndex + 1,
      totalExercises: routine.exercises.length,
      completedSetsText: '${session.completedSets.length} total sets',
      currentExerciseProgressText:
          '$currentExerciseSets/${currentRoutineExercise.targetSets} sets',
      exerciseDetailText: _exerciseDetailText(
        currentRoutineExercise,
        currentExercise,
      ),
      startedAt: session.startedAt,
      updatedAt: now,
      restEndAt: restContext?.restEndAt,
      restSeconds: restContext?.restSeconds ?? 0,
      lastSetAt: lastSet?.completedAt,
    );
  }

  static _RestContext? _buildRestContext({
    required Routine routine,
    required WorkoutSession session,
    required DateTime updatedAt,
    required CompletedSet? lastSet,
  }) {
    if (lastSet == null) {
      return null;
    }

    RoutineExercise? restExercise;
    for (final item in routine.exercises) {
      if (item.exerciseId == lastSet.exerciseId) {
        restExercise = item;
        break;
      }
    }
    final restSeconds = restExercise?.restSeconds ?? 0;
    if (restSeconds <= 0) {
      return null;
    }

    final restEndAt = lastSet.completedAt.add(Duration(seconds: restSeconds));
    if (!restEndAt.isAfter(updatedAt)) {
      return null;
    }

    return _RestContext(restEndAt: restEndAt, restSeconds: restSeconds);
  }

  static String _exerciseDetailText(
    RoutineExercise routineExercise,
    Exercise exercise,
  ) {
    if (exercise.exerciseType == 'timed') {
      return '${routineExercise.targetDurationSeconds}s intervals';
    }

    return '${routineExercise.targetReps} reps target';
  }
}

class _RestContext {
  const _RestContext({required this.restEndAt, required this.restSeconds});

  final DateTime restEndAt;
  final int restSeconds;
}
