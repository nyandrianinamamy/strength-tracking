import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  String _setSummaryText(
    AppState state,
    CompletedSet set,
  ) {
    final baseText =
        'Set ${set.setNumber}: ${AppFormatters.weight(set.weightKg, state.preferredUnit)} x ${set.reps}';

    if (set.rpe == null) {
      return baseText;
    }

    return '$baseText • RPE ${set.rpe!.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final session = state.sessionById(sessionId);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Summary')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: EmptyStateCard(
              title: 'Summary unavailable',
              body: 'That workout could not be found.',
            ),
          ),
        ),
      );
    }

    final routine = state.routineById(session.routineId);
    final duration = (session.endedAt ?? session.startedAt).difference(
      session.startedAt,
    );
    final totalVolume = session.completedSets.fold<double>(
      0,
      (total, set) => total + (set.weightKg * set.reps),
    );
    final prs = ref.read(progressServiceProvider).sessionPrs(state, sessionId);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workoutComplete),
        actions: [
          IconButton(
            tooltip: l10n.deleteWorkout,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(l10n.deleteWorkout),
                  content: Text(l10n.deleteWorkoutConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        ref.read(workoutControllerProvider).deleteSession(sessionId);
                        context.go('/');
                      },
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // Hero section
          Center(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4),
                  ),
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.workspace_premium,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  routine?.name ?? 'Workout',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (prs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.newPersonalRecord,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats grid using StatCard
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: l10n.volume,
                  value: AppFormatters.decimal(AppFormatters.convertWeight(totalVolume, state.preferredUnit)),
                  subtext: state.preferredUnit.toUpperCase(),
                  showAccent: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: l10n.time,
                  value: AppFormatters.duration(duration),
                  subtext: 'DURATION',
                  showAccent: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: l10n.exercises,
                  value: '${routine?.exercises.length ?? 0}',
                  subtext: 'TOTAL',
                  showAccent: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // PR highlights - horizontal scroll
          PageSection(
            title: l10n.prHighlights,
            child: prs.isEmpty
                ? EmptyStateCard(
                    title: l10n.noNewPrs,
                    body: l10n.prContributes,
                  )
                : SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: prs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final pr = prs[index];
                        return Container(
                          width: 180,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(color: context.appColors.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pr.exerciseName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${AppFormatters.weight(pr.weightKg, state.preferredUnit)} x ${pr.reps}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Est. 1RM: ${AppFormatters.decimal(pr.estimatedOneRepMax)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: context.appColors.subtleText),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 28),

          // Exercise breakdown with set count badge
          PageSection(
            title: l10n.exerciseBreakdown,
            child: Column(
              children: (routine?.exercises ?? const []).map((item) {
                final exercise = state.exerciseById(item.exerciseId);
                final sets = session.completedSets
                    .where((set) => set.exerciseId == item.exerciseId)
                    .toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                exercise?.name ?? 'Exercise',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${sets.length} sets',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...sets.map((set) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _setSummaryText(state, set),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (session.sessionNote.isNotEmpty) ...[
            const SizedBox(height: 28),
            Card(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  session.sessionNote,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.appColors.subtleText),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Action buttons
          FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_rounded),
            label: Text(l10n.finishGoHome),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/progress'),
            icon: const Icon(Icons.insights_rounded),
            label: Text(l10n.viewProgress),
          ),
        ],
      ),
    );
  }
}
