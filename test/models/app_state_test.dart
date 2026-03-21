import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/routine_group.dart';

void main() {
  test('app state json round-trip preserves routine groups', () {
    const state = AppState(
      exercises: [],
      routines: [],
      routineGroups: [
        RoutineGroup(
          id: 'group_1',
          name: 'PPL',
          routineIds: ['push', 'pull', 'legs'],
          pendingRoutineIds: ['legs', 'pull'],
        ),
      ],
      sessions: [],
      activeRoutineGroupId: 'group_1',
    );

    final roundTrip = AppState.fromJson(state.toJson());

    expect(roundTrip.activeRoutineGroupId, 'group_1');
    expect(roundTrip.routineGroups, hasLength(1));
    expect(roundTrip.routineGroups.first.pendingRoutineIds, ['legs', 'pull']);
  });
}
