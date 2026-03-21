import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class RoutineGroupsScreen extends ConsumerWidget {
  const RoutineGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateControllerProvider);
    final groups = [...state.routineGroups]
      ..sort((a, b) {
        final aIsActive = state.activeRoutineGroupId == a.id ? 0 : 1;
        final bIsActive = state.activeRoutineGroupId == b.id ? 0 : 1;
        if (aIsActive != bIsActive) {
          return aIsActive.compareTo(bIsActive);
        }
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Groups'),
        actions: [
          IconButton(
            onPressed: () => context.push('/routine-groups/new'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New group',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'Build ordered splits like PPL or Upper/Lower and choose which one drives the dashboard recommendation.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.slateInactive),
          ),
          const SizedBox(height: 18),
          if (groups.isEmpty)
            EmptyStateCard(
              title: 'No routine groups yet',
              body: 'Create a group to turn Next Workout into a real sequence.',
              dashed: true,
              icon: Icons.view_carousel_rounded,
              action: FilledButton.icon(
                onPressed: () => context.push('/routine-groups/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Group'),
              ),
            )
          else
            ...groups.map((group) {
              final normalized = ref
                  .read(routineGroupControllerProvider)
                  .normalizeGroup(state, group);
              final routineNames = normalized.routineIds
                  .map((id) => state.routineById(id)?.name)
                  .whereType<String>()
                  .toList();
              final pendingNames = normalized.pendingRoutineIds
                  .map((id) => state.routineById(id)?.name)
                  .whereType<String>()
                  .toList();

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  onTap: () => context.push('/routine-groups/${group.id}/edit'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (state.activeRoutineGroupId == group.id)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${routineNames.length} routines',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.slateInactive),
                        ),
                        if (routineNames.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: routineNames.map((name) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (pendingNames.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Current cycle: ${pendingNames.join(' → ')}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.slateInactive),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
