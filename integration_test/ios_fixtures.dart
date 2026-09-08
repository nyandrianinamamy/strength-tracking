import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine_group.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

// Native UI fixtures; all mutations after mount go through visible controls.
AppState e2eRichState({
  String userName = 'FlowUser',
  String preferredUnit = 'kg',
  bool includeActiveSession = false,
  bool staleActiveSession = false,
  String activeRoutineId = 'e2e_push_routine',
  bool includeCompletedSessions = true,
}) {
  final now = DateTime.now();
  final exercises = [
    const Exercise(
      id: 'e2e_strength_press',
      name: 'Flow Bench Press',
      primaryMuscles: ['Chest'],
      secondaryMuscles: ['Triceps', 'Deltoids'],
      equipment: ['Barbell', 'Bench'],
      instructions: 'Press with control.',
      archived: false,
    ),
    const Exercise(
      id: 'e2e_strength_row',
      name: 'Flow Cable Row',
      primaryMuscles: ['Upper Back'],
      secondaryMuscles: ['Biceps'],
      equipment: ['Cable Machine'],
      instructions: 'Pull elbows behind ribs.',
      archived: false,
    ),
    const Exercise(
      id: 'e2e_timed_plank',
      name: 'Flow Plank Hold',
      primaryMuscles: ['Abs'],
      equipment: [],
      instructions: 'Brace and breathe.',
      archived: false,
      exerciseType: 'timed',
    ),
    const Exercise(
      id: 'e2e_archived_curl',
      name: 'Flow Archived Curl',
      primaryMuscles: ['Biceps'],
      equipment: ['Dumbbells'],
      instructions: 'Archived fixture.',
      archived: true,
    ),
  ];
  final routines = [
    const Routine(
      id: 'e2e_push_routine',
      name: 'Flow Push Strength',
      category: 'strength',
      estimatedDurationMin: 24,
      archived: false,
      exercises: [
        RoutineExercise(
          exerciseId: 'e2e_strength_press',
          targetSets: 3,
          targetReps: 5,
          restSeconds: 90,
          order: 0,
        ),
        RoutineExercise(
          exerciseId: 'e2e_strength_row',
          targetSets: 2,
          targetReps: 8,
          restSeconds: 60,
          order: 1,
        ),
      ],
    ),
    const Routine(
      id: 'e2e_timed_routine',
      name: 'Flow Core Timer',
      category: 'mobility',
      estimatedDurationMin: 8,
      archived: false,
      exercises: [
        RoutineExercise(
          exerciseId: 'e2e_timed_plank',
          targetSets: 1,
          targetReps: 0,
          targetDurationSeconds: 60,
          restSeconds: 0,
          order: 0,
        ),
      ],
    ),
    const Routine(
      id: 'e2e_archived_routine',
      name: 'Flow Archived Routine',
      category: 'strength',
      estimatedDurationMin: 12,
      archived: true,
      exercises: [
        RoutineExercise(
          exerciseId: 'e2e_strength_press',
          targetSets: 1,
          targetReps: 5,
          restSeconds: 60,
          order: 0,
        ),
      ],
    ),
  ];
  final completed = WorkoutSession(
    id: 'e2e_completed_strength',
    routineId: 'e2e_push_routine',
    status: WorkoutSessionStatus.completed,
    startedAt: now.subtract(const Duration(days: 2, minutes: 45)),
    endedAt: now.subtract(const Duration(days: 2)),
    lastActivityAt: now.subtract(const Duration(days: 2)),
    currentExerciseIndex: 1,
    completedSets: [
      CompletedSet(
        exerciseId: 'e2e_strength_press',
        setNumber: 1,
        weightKg: 80,
        reps: 5,
        rpe: 8,
        note: 'Solid',
        completedAt: now.subtract(const Duration(days: 2, minutes: 30)),
      ),
      CompletedSet(
        exerciseId: 'e2e_strength_row',
        setNumber: 1,
        weightKg: 60,
        reps: 8,
        rpe: 7,
        note: '',
        completedAt: now.subtract(const Duration(days: 2, minutes: 20)),
      ),
    ],
    sessionNote: 'Fixture session',
    rpe: 8,
  );
  final timedCompleted = WorkoutSession(
    id: 'e2e_completed_timed',
    routineId: 'e2e_timed_routine',
    status: WorkoutSessionStatus.completed,
    startedAt: now.subtract(const Duration(days: 1, minutes: 15)),
    endedAt: now.subtract(const Duration(days: 1)),
    lastActivityAt: now.subtract(const Duration(days: 1)),
    currentExerciseIndex: 0,
    completedSets: [
      CompletedSet(
        exerciseId: 'e2e_timed_plank',
        setNumber: 1,
        weightKg: 0,
        reps: 0,
        durationSeconds: 120,
        note: '',
        completedAt: now.subtract(const Duration(days: 1, minutes: 5)),
      ),
    ],
    sessionNote: '',
    rpe: 6,
  );
  final active = WorkoutSession(
    id: 'e2e_active_session',
    routineId: activeRoutineId,
    status: WorkoutSessionStatus.active,
    startedAt: now.subtract(const Duration(hours: 2)),
    endedAt: null,
    lastActivityAt: staleActiveSession
        ? now.subtract(const Duration(hours: 2))
        : now.subtract(const Duration(minutes: 5)),
    currentExerciseIndex: 0,
    completedSets: const [],
    sessionNote: '',
    rpe: null,
  );
  return AppState(
    userName: userName,
    preferredUnit: preferredUnit,
    sex: 'female',
    age: 31,
    weight: 68,
    fitnessGoal: 'strength',
    exercises: exercises,
    routines: routines,
    routineGroups: const [
      RoutineGroup(
        id: 'e2e_group',
        name: 'Flow Weekly Rotation',
        routineIds: ['e2e_push_routine', 'e2e_timed_routine'],
        pendingRoutineIds: ['e2e_push_routine', 'e2e_timed_routine'],
      ),
    ],
    activeRoutineGroupId: 'e2e_group',
    sessions: [
      if (includeCompletedSessions) completed,
      if (includeCompletedSessions) timedCompleted,
      if (includeActiveSession) active,
    ],
  );
}
