import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  String _query = '';
  String? _category; // null means "All"

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final activeGroup = state.activeRoutineGroup;
    final groupNameByRoutineId = <String, String>{};
    for (final group in state.routineGroups) {
      for (final routineId in group.routineIds) {
        groupNameByRoutineId[routineId] = group.name;
      }
    }
    String displayCategory(String raw) {
      final key = Routine.normalizeCategory(raw);
      return switch (key) {
        'strength' => l10n.strength,
        'hypertrophy' => l10n.hypertrophy,
        'mobility' => l10n.mobility,
        _ => l10n.strength,
      };
    }
    final normalizedCategories = {
      for (final routine in state.routines.where((item) => !item.archived))
        Routine.normalizeCategory(routine.category),
    };
    final categories = <String>[
      l10n.all,
      ...normalizedCategories.map<String>((key) => switch (key) {
        'strength' => l10n.strength,
        'hypertrophy' => l10n.hypertrophy,
        'mobility' => l10n.mobility,
        _ => l10n.strength,
      }),
    ];
    final routines = state.routines.where((routine) {
      if (routine.archived) {
        return false;
      }
      if (_category != null && displayCategory(routine.category) != _category) {
        return false;
      }
      if (_query.isEmpty) {
        return true;
      }
      return routine.name.toLowerCase().contains(_query.toLowerCase());
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.workoutLibrary,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/routine-groups'),
              icon: const Icon(Icons.route_rounded),
              label: const Text('Groups'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.route_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(
              activeGroup?.name ?? 'No active group',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              activeGroup == null
                  ? 'Create a routine group to drive your dashboard sequence.'
                  : '${activeGroup.routineIds.length} routines in rotation',
            ),
            trailing: TextButton(
              onPressed: () => context.push('/routine-groups'),
              child: Text(activeGroup == null ? 'Create' : 'Manage'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: l10n.searchRoutines,
            filled: true,
            fillColor: context.appColors.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        const SizedBox(height: 14),
        CategoryChips(
          options: categories,
          selected: _category ?? l10n.all,
          onSelected: (v) =>
              setState(() => _category = v == l10n.all ? null : v),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.tertiary),
            ),
            title: const Text(
              'Generate Smart Plan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('AI-powered weekly training plan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ref.read(smartPlannerControllerProvider.notifier).reset();
              context.push('/routines/smart-planner');
            },
          ),
        ),
        const SizedBox(height: 14),
        DashedBorderCard(
          onTap: () => context.push('/routine/new'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.createNewRoutine,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.designPlan,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.appColors.subtleText),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (routines.isEmpty)
          EmptyStateCard(
            title: l10n.noRoutinesMatch,
            body: l10n.clearSearchPrompt,
          )
        else
          ...routines.map((routine) {
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/routine/${routine.id}/edit'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          color: context.appColors.subtleText,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${routine.exercises.length} exercises • ${routine.estimatedDurationMin} min',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.appColors.subtleText),
                            ),
                            if (groupNameByRoutineId[routine.id] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    groupNameByRoutineId[routine.id]!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(routineControllerProvider)
                              .startSession(routine.id);
                          context.go('/workout/active');
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
