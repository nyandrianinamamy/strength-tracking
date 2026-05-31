import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/routine_group.dart';

void main() {
  test('app state defaults include training profile preferences', () {
    const state = AppState(exercises: [], routines: [], sessions: []);

    expect(state.experience, 'intermediate');
    expect(state.availableDays, [1, 3, 5]);
    expect(state.maxSessionDurationMinutes, 60);
  });

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

  test('app state json round-trip preserves training profile preferences', () {
    const state = AppState(
      exercises: [],
      routines: [],
      sessions: [],
      experience: 'advanced',
      availableDays: [1, 2, 4, 6],
      maxSessionDurationMinutes: 75,
    );

    final roundTrip = AppState.fromJson(state.toJson());

    expect(roundTrip.experience, 'advanced');
    expect(roundTrip.availableDays, [1, 2, 4, 6]);
    expect(roundTrip.maxSessionDurationMinutes, 75);
  });
}
