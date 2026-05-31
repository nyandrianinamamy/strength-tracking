import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';

void main() {
  final service = ProgressService();

  AppState progressStateWithSets({
    String exerciseId = 'barbell_back_squat',
    String exerciseName = 'Barbell Back Squat',
    String exerciseType = 'strength',
    List<CompletedSet>? sets,
  }) {
    final completedAt = DateTime.utc(2026, 5, 1, 18);
    return AppState(
      exercises: [
        Exercise(
          id: exerciseId,
          name: exerciseName,
          primaryMuscles: const ['Quadriceps'],
          secondaryMuscles: const [],
          equipment: const ['Barbell'],
          instructions: '',
          exerciseType: exerciseType,
          archived: false,
        ),
      ],
      routines: const [],
      sessions: [
        WorkoutSession(
          id: 'completed-session',
          routineId: 'routine-1',
          status: WorkoutSessionStatus.completed,
          startedAt: completedAt.subtract(const Duration(hours: 1)),
          endedAt: completedAt,
          lastActivityAt: completedAt,
          currentExerciseIndex: 0,
          completedSets:
              sets ??
              [
                CompletedSet(
                  exerciseId: exerciseId,
                  setNumber: 1,
                  weightKg: 100,
                  reps: 5,
                  rpe: 8,
                  completedAt: completedAt,
                  note: '',
                ),
              ],
          sessionNote: '',
          rpe: 8,
        ),
      ],
    );
  }

  WorkoutSession completedSessionOn(String id, DateTime endedAt) {
    return WorkoutSession(
      id: id,
      routineId: 'routine-1',
      status: WorkoutSessionStatus.completed,
      startedAt: endedAt.subtract(const Duration(hours: 1)),
      endedAt: endedAt,
      lastActivityAt: endedAt,
      currentExerciseIndex: 0,
      completedSets: const [],
      sessionNote: '',
      rpe: null,
    );
  }

  test('dashboard snapshot exposes recent workouts and a next routine', () {
    final state = DemoSeedData.initialState();
    final snapshot = service.dashboardSnapshot(
      state,
      currentE1rmsByExercise: const {},
    );

    expect(snapshot.totalWorkouts, greaterThan(0));
    expect(snapshot.nextRoutine, isNotNull);
    expect(snapshot.nextRoutine?.id, 'push_day');
    expect(snapshot.nextRoutineGroupName, 'Push / Pull / Legs');
    expect(snapshot.recentWorkouts, isNotEmpty);
    expect(snapshot.calendarSessions, isNotEmpty);
  });

  test('dashboard snapshot follows the active routine group queue', () {
    final seeded = DemoSeedData.initialState();
    final group = seeded
        .routineGroupById('ppl_split')!
        .copyWith(pendingRoutineIds: const ['leg_day', 'pull_day']);
    final state = seeded.copyWith(
      routineGroups: [group],
      activeRoutineGroupId: group.id,
    );

    final snapshot = service.dashboardSnapshot(
      state,
      currentE1rmsByExercise: const {},
    );

    expect(snapshot.nextRoutine?.id, 'leg_day');
    expect(snapshot.nextRoutineGroupName, 'Push / Pull / Legs');
    expect(snapshot.canSkipNextRoutine, isTrue);
    expect(snapshot.nextRoutineReason, contains('2 workouts left'));
  });

  test(
    'progress snapshot computes consistency, volume, and personal records',
    () {
      final state = DemoSeedData.initialState();
      final snapshot = service.progressSnapshot(
        state,
        currentE1rmsByExercise: const {
          'barbell_bench_press': 100,
          'barbell_back_squat': 120,
        },
      );

      expect(snapshot.averageWorkoutDaysPerWeek, greaterThan(0));
      expect(snapshot.personalRecords, isNotEmpty);
      expect(snapshot.weeklyVolume, isNotEmpty);
      expect(snapshot.topLifts.first.estimatedOneRepMax, greaterThan(0));
    },
  );

  test(
    'weekly consistency counts workout days and lets current week finish',
    () {
      final now = DateTime.utc(2026, 5, 20, 12);
      final state = AppState(
        exercises: const [],
        routines: const [],
        weeklyTrainingTargetDays: 2,
        sessions: [
          completedSessionOn(
            'current-duplicate-a',
            DateTime.utc(2026, 5, 18, 18),
          ),
          completedSessionOn(
            'current-duplicate-b',
            DateTime.utc(2026, 5, 18, 20),
          ),
          completedSessionOn('last-week-a', DateTime.utc(2026, 5, 11, 18)),
          completedSessionOn('last-week-b', DateTime.utc(2026, 5, 13, 18)),
          completedSessionOn('two-weeks-a', DateTime.utc(2026, 5, 4, 18)),
          completedSessionOn('two-weeks-b', DateTime.utc(2026, 5, 6, 18)),
        ],
      );

      final snapshot = service.progressSnapshot(
        state,
        currentE1rmsByExercise: const {},
        now: now,
      );

      expect(snapshot.weeklyTrainingTargetDays, 2);
      expect(snapshot.currentWeekWorkoutDays, 1);
      expect(snapshot.weeksOnTrack, 2);

      final onTrackThisWeek = service.progressSnapshot(
        state.copyWith(
          sessions: [
            ...state.sessions,
            completedSessionOn(
              'current-second-day',
              DateTime.utc(2026, 5, 19, 18),
            ),
          ],
        ),
        currentE1rmsByExercise: const {},
        now: now,
      );

      expect(onTrackThisWeek.currentWeekWorkoutDays, 2);
      expect(onTrackThisWeek.weeksOnTrack, 3);
    },
  );

  test('progress strength e1RM values come from engine current e1RM', () {
    final state = progressStateWithSets();
    const engineRollingE1rm = 321.0;

    final snapshot = service.progressSnapshot(
      state,
      currentE1rmsByExercise: const {'barbell_back_squat': engineRollingE1rm},
    );

    expect(
      snapshot.personalRecords.single.estimatedOneRepMax,
      engineRollingE1rm,
    );
    expect(snapshot.topLifts.single.estimatedOneRepMax, engineRollingE1rm);
  });

  test('timed progress records keep duration and no strength e1RM', () {
    final state = progressStateWithSets(
      exerciseId: 'plank',
      exerciseName: 'Plank',
      exerciseType: 'timed',
      sets: [
        CompletedSet(
          exerciseId: 'plank',
          setNumber: 1,
          weightKg: 0,
          reps: 0,
          durationSeconds: 120,
          completedAt: DateTime.utc(2026, 5, 1, 18),
          note: '',
        ),
      ],
    );

    final snapshot = service.progressSnapshot(
      state,
      currentE1rmsByExercise: const {},
    );

    expect(snapshot.personalRecords.single.isTimed, isTrue);
    expect(snapshot.personalRecords.single.durationSeconds, 120);
    expect(snapshot.personalRecords.single.estimatedOneRepMax, 0);
    expect(snapshot.topLifts.single.isTimed, isTrue);
    expect(snapshot.topLifts.single.durationSeconds, 120);
  });

  test('session PRs detect new performance inside a completed workout', () {
    final state = DemoSeedData.initialState();
    final prs = service.sessionPrs(state, 'session_leg_2');

    expect(prs, isNotEmpty);
    expect(
      prs.any((record) => record.exerciseId == 'barbell_back_squat'),
      isTrue,
    );
  });

  test('dashboard snapshot marks an active session as stale', () {
    final state = DemoSeedData.initialState().copyWith(
      sessions: [
        WorkoutSession(
          id: 'session_stale',
          routineId: 'push_day',
          status: WorkoutSessionStatus.active,
          startedAt: DateTime.now().subtract(const Duration(hours: 3)),
          endedAt: null,
          lastActivityAt: DateTime.now().subtract(const Duration(hours: 2)),
          currentExerciseIndex: 0,
          completedSets: const [],
          sessionNote: '',
          rpe: null,
        ),
      ],
    );

    final snapshot = service.dashboardSnapshot(
      state,
      currentE1rmsByExercise: const {},
    );

    expect(snapshot.activeSessionIsStale, isTrue);
    expect(snapshot.activeSessionIdleLabel, contains('idle'));
  });
}
