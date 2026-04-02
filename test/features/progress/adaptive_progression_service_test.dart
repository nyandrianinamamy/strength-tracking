import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/progress/adaptive_progression_service.dart';

void main() {
  const service = AdaptiveProgressionService();

  final squat = Exercise(
    id: 'squat',
    name: 'Barbell Back Squat',
    primaryMuscles: const ['Quadriceps', 'Glutes'],
    equipment: const ['Barbell'],
    instructions: '',
    archived: false,
  );
  final curl = Exercise(
    id: 'curl',
    name: 'Dumbbell Curl',
    primaryMuscles: const ['Biceps'],
    equipment: const ['Dumbbell'],
    instructions: '',
    archived: false,
  );
  final treadmill = Exercise(
    id: 'treadmill',
    name: 'Treadmill',
    primaryMuscles: const ['Quadriceps'],
    equipment: const ['Machine'],
    instructions: '',
    archived: false,
    exerciseType: 'timed',
  );

  const squatPrescription = RoutineExercise(
    exerciseId: 'squat',
    targetSets: 3,
    targetReps: 5,
    restSeconds: 120,
    order: 0,
  );
  const curlPrescription = RoutineExercise(
    exerciseId: 'curl',
    targetSets: 3,
    targetReps: 10,
    restSeconds: 60,
    order: 0,
  );

  test('increases after perfect performance with moderate RPE', () {
    final state = _stateWithSession(
      exercise: squat,
      rpe: 8.0,
      reps: const [5, 5, 5],
      weightKg: 100,
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: squat,
      prescription: squatPrescription,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.direction, ProgressionDirection.up);
    expect(suggestion.suggestedWeightKg, 105);
  });

  test('holds after perfect performance when RPE is high', () {
    final state = _stateWithSession(
      exercise: squat,
      rpe: 9.2,
      reps: const [5, 5, 5],
      weightKg: 100,
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: squat,
      prescription: squatPrescription,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.direction, ProgressionDirection.hold);
    expect(suggestion.suggestedWeightKg, 100);
  });

  test('prefers per-set RPE over session RPE for successful sets', () {
    final state = _stateWithSession(
      exercise: squat,
      rpe: 9.2,
      reps: const [5, 5, 5],
      weightKg: 100,
      perSetRpes: const [8.0, 8.0, 8.0],
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: squat,
      prescription: squatPrescription,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.direction, ProgressionDirection.up);
    expect(suggestion.suggestedWeightKg, 105);
  });

  test('holds on mixed reps', () {
    final state = _stateWithSession(
      exercise: curl,
      rpe: 8.0,
      reps: const [10, 10, 9],
      weightKg: 14,
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: curl,
      prescription: curlPrescription,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.direction, ProgressionDirection.hold);
    expect(suggestion.suggestedWeightKg, 14);
  });

  test('decreases on clear misses with very high RPE', () {
    final state = _stateWithSession(
      exercise: curl,
      rpe: 9.6,
      reps: const [7, 8, 8],
      weightKg: 14,
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: curl,
      prescription: curlPrescription,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.direction, ProgressionDirection.down);
    expect(suggestion.suggestedWeightKg, 12.75);
  });

  test('prefers per-set RPE over session RPE for hard missed sets', () {
    final state = _stateWithSession(
      exercise: curl,
      rpe: 8.0,
      reps: const [7, 8, 8],
      weightKg: 14,
      perSetRpes: const [9.6, 9.7, 9.5],
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: curl,
      prescription: curlPrescription,
    );

    expect(suggestion, isNotNull);
    expect(suggestion!.direction, ProgressionDirection.down);
    expect(suggestion.suggestedWeightKg, 12.75);
  });

  test('returns no suggestion with no history', () {
    const state = AppState(
      exercises: [],
      routines: [],
      routineGroups: [],
      sessions: [],
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: squat,
      prescription: squatPrescription,
    );

    expect(suggestion, isNull);
  });

  test('returns no suggestion for timed exercises', () {
    final state = _stateWithSession(
      exercise: treadmill,
      rpe: null,
      reps: const [0],
      weightKg: 0,
      durationSeconds: 600,
    );

    final suggestion = service.suggestionForExercise(
      state: state,
      exercise: treadmill,
      prescription: const RoutineExercise(
        exerciseId: 'treadmill',
        targetSets: 1,
        targetReps: 0,
        restSeconds: 0,
        order: 0,
        targetDurationSeconds: 600,
      ),
    );

    expect(suggestion, isNull);
  });
}

AppState _stateWithSession({
  required Exercise exercise,
  required double? rpe,
  required List<int> reps,
  required double weightKg,
  int durationSeconds = 0,
  List<double?>? perSetRpes,
}) {
  final startedAt = DateTime(2026, 3, 1, 8);
  final sets = <CompletedSet>[];
  for (var index = 0; index < reps.length; index++) {
    sets.add(
      CompletedSet(
        exerciseId: exercise.id,
        setNumber: index + 1,
        weightKg: weightKg,
        reps: reps[index],
        completedAt: startedAt.add(Duration(minutes: index + 1)),
        note: '',
        durationSeconds: durationSeconds,
        rpe: perSetRpes?[index],
      ),
    );
  }

  return AppState(
    exercises: [exercise],
    routines: const [],
    routineGroups: const [],
    sessions: [
      WorkoutSession(
        id: 'session_1',
        routineId: 'routine_1',
        status: WorkoutSessionStatus.completed,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 45)),
        lastActivityAt: startedAt.add(const Duration(minutes: 45)),
        currentExerciseIndex: 0,
        completedSets: sets,
        sessionNote: '',
        rpe: rpe,
      ),
    ],
  );
}
