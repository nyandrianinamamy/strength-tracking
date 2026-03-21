import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';

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

  test('skip moves the next routine to the back of the current cycle', () {
    final seeded = DemoSeedData.initialState();
    final group = seeded
        .routineGroupById('ppl_split')!
        .copyWith(pendingRoutineIds: const ['pull_day', 'leg_day']);
    final container = buildContainer(
      initialState: seeded.copyWith(
        routineGroups: [group],
        activeRoutineGroupId: group.id,
      ),
    );
    addTearDown(container.dispose);

    container.read(routineGroupControllerProvider).skipNextInGroup(group.id);

    final updatedGroup = container
        .read(appStateControllerProvider)
        .routineGroupById(group.id)!;
    expect(updatedGroup.pendingRoutineIds, ['leg_day', 'pull_day']);
  });

  test(
    'completing routines advances the cycle and resets after the last one',
    () {
      final seeded = DemoSeedData.initialState();
      final group = seeded
          .routineGroupById('ppl_split')!
          .copyWith(pendingRoutineIds: const ['leg_day', 'pull_day']);
      final container = buildContainer(
        initialState: seeded.copyWith(
          routineGroups: [group],
          activeRoutineGroupId: group.id,
        ),
      );
      addTearDown(container.dispose);

      final controller = container.read(routineGroupControllerProvider);
      controller.markRoutineCompleted('leg_day');
      expect(
        container
            .read(appStateControllerProvider)
            .routineGroupById(group.id)!
            .pendingRoutineIds,
        ['pull_day'],
      );

      controller.markRoutineCompleted('pull_day');
      expect(
        container
            .read(appStateControllerProvider)
            .routineGroupById(group.id)!
            .pendingRoutineIds,
        ['push_day', 'pull_day', 'leg_day'],
      );
    },
  );
}
