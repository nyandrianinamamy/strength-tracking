import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';

void main() {
  final service = ProgressService();

  test('dashboard snapshot exposes recent workouts and a next routine', () {
    final state = DemoSeedData.initialState();
    final snapshot = service.dashboardSnapshot(state);

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

    final snapshot = service.dashboardSnapshot(state);

    expect(snapshot.nextRoutine?.id, 'leg_day');
    expect(snapshot.nextRoutineGroupName, 'Push / Pull / Legs');
    expect(snapshot.canSkipNextRoutine, isTrue);
    expect(snapshot.nextRoutineReason, contains('2 workouts left'));
  });

  test('progress snapshot computes streak, volume, and personal records', () {
    final state = DemoSeedData.initialState();
    final snapshot = service.progressSnapshot(state);

    expect(snapshot.averageWorkoutDaysPerWeek, greaterThan(0));
    expect(snapshot.personalRecords, isNotEmpty);
    expect(snapshot.weeklyVolume, isNotEmpty);
    expect(snapshot.topLifts.first.estimatedOneRepMax, greaterThan(0));
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

    final snapshot = service.dashboardSnapshot(state);

    expect(snapshot.activeSessionIsStale, isTrue);
    expect(snapshot.activeSessionIdleLabel, contains('idle'));
  });
}
