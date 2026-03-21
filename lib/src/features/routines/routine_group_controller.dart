import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/routine_group.dart';

final routineGroupControllerProvider = Provider<RoutineGroupController>(
  RoutineGroupController.new,
);

class RoutineGroupController {
  RoutineGroupController(this._ref);

  final Ref _ref;

  RoutineGroup create({
    required String name,
    required List<String> routineIds,
    bool makeActive = false,
  }) {
    final state = _ref.read(appStateControllerProvider);
    final sanitizedRoutineIds = _sanitizeRoutineIds(
      const [],
      state,
      routineIds,
    );
    final group = RoutineGroup(
      id: 'routine_group_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      routineIds: sanitizedRoutineIds,
      pendingRoutineIds: sanitizedRoutineIds,
    );

    final groups = _removeAssignmentsFromOtherGroups(
      state,
      state.routineGroups,
      groupId: group.id,
      routineIds: sanitizedRoutineIds,
    );
    final nextGroups = [...groups, group];
    final nextActiveGroupId = makeActive || state.activeRoutineGroupId == null
        ? group.id
        : state.activeRoutineGroupId;

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(
            routineGroups: nextGroups,
            activeRoutineGroupId: nextActiveGroupId,
          ),
        );

    return group;
  }

  RoutineGroup? update({
    required String groupId,
    required String name,
    required List<String> routineIds,
    bool makeActive = false,
  }) {
    final state = _ref.read(appStateControllerProvider);
    final existing = state.routineGroupById(groupId);
    if (existing == null) {
      return null;
    }

    final sanitizedRoutineIds = _sanitizeRoutineIds(
      state.routineGroups.where((group) => group.id != groupId),
      state,
      routineIds,
    );
    final updated = existing.copyWith(
      name: name.trim(),
      routineIds: sanitizedRoutineIds,
      pendingRoutineIds: _mergePending(
        existing.pendingRoutineIds,
        sanitizedRoutineIds,
      ),
    );

    final groups = _removeAssignmentsFromOtherGroups(
      state,
      state.routineGroups,
      groupId: groupId,
      routineIds: sanitizedRoutineIds,
    ).map((group) => group.id == groupId ? updated : group).toList();

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(
            routineGroups: groups,
            activeRoutineGroupId: makeActive
                ? groupId
                : _validatedActiveGroupId(
                    groups,
                    currentState.activeRoutineGroupId,
                  ),
          ),
        );

    return updated;
  }

  void delete(String groupId) {
    final state = _ref.read(appStateControllerProvider);
    final remainingGroups = state.routineGroups
        .where((group) => group.id != groupId)
        .toList();

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(
            routineGroups: remainingGroups,
            activeRoutineGroupId: _validatedActiveGroupId(
              remainingGroups,
              currentState.activeRoutineGroupId == groupId
                  ? null
                  : currentState.activeRoutineGroupId,
            ),
          ),
        );
  }

  void setActiveGroup(String? groupId) {
    final state = _ref.read(appStateControllerProvider);
    if (groupId != null && state.routineGroupById(groupId) == null) {
      return;
    }

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(
            activeRoutineGroupId: groupId,
            clearActiveRoutineGroupId: groupId == null,
          ),
        );
  }

  void skipNextInGroup(String groupId) {
    final state = _ref.read(appStateControllerProvider);
    final group = state.routineGroupById(groupId);
    if (group == null) {
      return;
    }

    final normalized = normalizeGroup(state, group);
    if (normalized.pendingRoutineIds.length <= 1) {
      return;
    }

    final nextPending = [
      ...normalized.pendingRoutineIds.skip(1),
      normalized.pendingRoutineIds.first,
    ];
    _updateGroup(normalized.copyWith(pendingRoutineIds: nextPending));
  }

  void markRoutineCompleted(String routineId) {
    final state = _ref.read(appStateControllerProvider);
    final updatedGroups = state.routineGroups.map((group) {
      final normalized = normalizeGroup(state, group);
      if (!normalized.routineIds.contains(routineId)) {
        return normalized;
      }

      final nextPending = normalized.pendingRoutineIds
          .where((id) => id != routineId)
          .toList();
      return normalized.copyWith(
        pendingRoutineIds: nextPending.isEmpty
            ? normalized.routineIds
            : nextPending,
      );
    }).toList();

    if (_groupsEqual(updatedGroups, state.routineGroups)) {
      return;
    }

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(routineGroups: updatedGroups),
        );
  }

  List<String> availableRoutineIdsForGroup(String? groupId) {
    final state = _ref.read(appStateControllerProvider);
    final assignedIds = state.routineGroups
        .where((group) => group.id != groupId)
        .expand((group) => group.routineIds)
        .toSet();

    return state.routines
        .where((routine) => !routine.archived)
        .where((routine) => !assignedIds.contains(routine.id))
        .map((routine) => routine.id)
        .toList();
  }

  RoutineGroup normalizeGroup(AppState state, RoutineGroup group) {
    final validRoutineIds = group.routineIds.where((routineId) {
      final routine = state.routineById(routineId);
      return routine != null && !routine.archived;
    }).toList();
    final pendingRoutineIds = group.pendingRoutineIds
        .where(validRoutineIds.contains)
        .toList();

    return group.copyWith(
      routineIds: validRoutineIds,
      pendingRoutineIds: pendingRoutineIds.isEmpty
          ? validRoutineIds
          : pendingRoutineIds,
    );
  }

  void _updateGroup(RoutineGroup updated) {
    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (state) => state.copyWith(
            routineGroups: state.routineGroups
                .map((group) => group.id == updated.id ? updated : group)
                .toList(),
          ),
        );
  }

  List<RoutineGroup> _removeAssignmentsFromOtherGroups(
    AppState state,
    List<RoutineGroup> groups, {
    required String groupId,
    required List<String> routineIds,
  }) {
    return groups.map((group) {
      if (group.id == groupId) {
        return group;
      }

      final nextRoutineIds = group.routineIds
          .where((id) => !routineIds.contains(id))
          .toList();

      return normalizeGroup(
        state,
        group.copyWith(
          routineIds: nextRoutineIds,
          pendingRoutineIds: group.pendingRoutineIds
              .where(nextRoutineIds.contains)
              .toList(),
        ),
      );
    }).toList();
  }

  List<String> _sanitizeRoutineIds(
    Iterable<RoutineGroup> existingGroups,
    AppState state,
    List<String> routineIds,
  ) {
    final seen = <String>{};
    final assignedElsewhere = existingGroups
        .expand((group) => group.routineIds)
        .toSet();

    return routineIds.where((id) {
      if (!seen.add(id)) {
        return false;
      }
      if (assignedElsewhere.contains(id)) {
        return false;
      }
      final routine = state.routineById(id);
      return routine != null && !routine.archived;
    }).toList();
  }

  List<String> _mergePending(
    List<String> currentPending,
    List<String> routineIds,
  ) {
    final pending = currentPending.where(routineIds.contains).toList();
    final seen = pending.toSet();
    for (final routineId in routineIds) {
      if (seen.add(routineId)) {
        pending.add(routineId);
      }
    }
    return pending;
  }

  String? _validatedActiveGroupId(
    List<RoutineGroup> groups,
    String? requestedActiveGroupId,
  ) {
    if (requestedActiveGroupId != null &&
        groups.any((group) => group.id == requestedActiveGroupId)) {
      return requestedActiveGroupId;
    }
    return groups.isEmpty ? null : groups.first.id;
  }

  bool _groupsEqual(List<RoutineGroup> a, List<RoutineGroup> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].name != b[i].name ||
          a[i].routineIds.join('|') != b[i].routineIds.join('|') ||
          a[i].pendingRoutineIds.join('|') !=
              b[i].pendingRoutineIds.join('|')) {
        return false;
      }
    }
    return true;
  }
}
