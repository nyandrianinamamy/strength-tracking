import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';

void main() {
  ProviderContainer buildContainer({AppState? initialState}) {
    final repository = MemoryAppStateRepository(
      initialState: initialState ?? DemoSeedData.initialState(),
    );

    return ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
      ],
    );
  }

  test('starting, logging, and completing a workout updates app state', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final routines = container.read(appStateControllerProvider).routines;
    final routine = routines.firstWhere((item) => item.id == 'push_day');

    final started = container
        .read(routineControllerProvider)
        .startSession(routine.id);
    expect(started.routineId, routine.id);
    expect(
      container.read(appStateControllerProvider).activeSession?.id,
      started.id,
    );

    final updated = container
        .read(workoutControllerProvider)
        .logSet(weightKg: 100, reps: 6);
    expect(updated, isNotNull);
    expect(updated!.completedSets, hasLength(1));

    final completed = container
        .read(workoutControllerProvider)
        .completeSession(rpe: 8.5);
    expect(completed, isNotNull);
    expect(completed!.status.name, 'completed');
    expect(container.read(appStateControllerProvider).activeSession, isNull);
    expect(
      container
          .read(appStateControllerProvider)
          .completedSessions
          .any((session) => session.id == completed.id),
      isTrue,
    );
  });

  test('archiving a routine preserves completed workout history', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final initialCompletedCount = container
        .read(appStateControllerProvider)
        .completedSessions
        .length;

    container.read(routineControllerProvider).archive('push_day');

    final state = container.read(appStateControllerProvider);
    expect(state.routineById('push_day')?.archived, isTrue);
    expect(state.completedSessions.length, initialCompletedCount);
    expect(
      state.completedSessions.any((session) => session.routineId == 'push_day'),
      isTrue,
    );
  });

  test('archiving a routine removes it from all routine groups', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final groupBefore = container
        .read(appStateControllerProvider)
        .routineGroupById('ppl_split');
    expect(groupBefore!.routineIds, contains('push_day'));

    container.read(routineControllerProvider).archive('push_day');

    final groupAfter = container
        .read(appStateControllerProvider)
        .routineGroupById('ppl_split');
    expect(groupAfter!.routineIds, isNot(contains('push_day')));
  });

  test(
    'skipping a grouped routine advances the queue until it is completed',
    () {
      final container = buildContainer();
      addTearDown(container.dispose);

      container
          .read(routineGroupControllerProvider)
          .skipNextInGroup('ppl_split');

      var group = container
          .read(appStateControllerProvider)
          .routineGroupById('ppl_split');
      expect(group, isNotNull);
      expect(group!.pendingRoutineIds, ['pull_day', 'leg_day', 'push_day']);

      container.read(routineControllerProvider).startSession('pull_day');
      container.read(workoutControllerProvider).completeSession(rpe: 8.0);

      group = container
          .read(appStateControllerProvider)
          .routineGroupById('ppl_split');
      expect(group, isNotNull);
      expect(group!.pendingRoutineIds, ['leg_day', 'push_day']);
    },
  );
}
