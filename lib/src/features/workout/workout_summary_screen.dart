import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final rpe = session.rpe ?? 8.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Complete')),
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
                    border: Border.all(color: AppTheme.primary, width: 4),
                  ),
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 48,
                      color: AppTheme.primary,
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
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'New Personal Record!',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.primary,
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
                  label: 'Volume',
                  value: AppFormatters.weight(totalVolume, state.preferredUnit),
                  subtext: state.preferredUnit.toUpperCase(),
                  showAccent: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Time',
                  value: AppFormatters.duration(duration),
                  subtext: 'DURATION',
                  showAccent: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Exercises',
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
            title: 'PR Highlights',
            child: prs.isEmpty
                ? const EmptyStateCard(
                    title: 'No new PRs this time',
                    body:
                        'The workout still contributes to your volume and lift history.',
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
                            color: Colors.white,
                            border: Border.all(color: AppTheme.border),
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
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Est. 1RM: ${AppFormatters.decimal(pr.estimatedOneRepMax)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.slateInactive),
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
            title: 'Exercise Breakdown',
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
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${sets.length} sets',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
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
                              'Set ${set.setNumber}: ${AppFormatters.weight(set.weightKg, state.preferredUnit)} x ${set.reps}',
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
          const SizedBox(height: 28),

          // RPE section with restyled card
          Card(
            color: AppTheme.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How did it feel?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'RPE ${rpe.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Easy',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.slateInactive,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Expanded(
                        child: Slider(
                          value: rpe,
                          min: 5,
                          max: 10,
                          divisions: 10,
                          onChanged: (value) {
                            ref
                                .read(workoutControllerProvider)
                                .updateRpe(sessionId, value);
                          },
                        ),
                      ),
                      Text(
                        'Hard',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.slateInactive,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  if (session.sessionNote.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      session.sessionNote,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Finish & Go Home'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/progress'),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('View Progress'),
          ),
        ],
      ),
    );
  }
}
