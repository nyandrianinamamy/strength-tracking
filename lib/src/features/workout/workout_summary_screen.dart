import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
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
          Card(
            color: const Color(0xFF111827),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppFormatters.weekdayMonthDay(
                      session.endedAt ?? session.startedAt,
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF8FB9FF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    routine?.name ?? 'Workout',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    prs.isEmpty
                        ? 'Workout logged successfully.'
                        : 'New performance milestones detected.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 420;
              return GridView.count(
                crossAxisCount: isWide ? 3 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: isWide ? 1 : 2.6,
                children: [
                  MetricCard(
                    label: 'Volume',
                    value: '${AppFormatters.decimal(totalVolume)} kg',
                    detail: 'Across all completed sets',
                    icon: Icons.scale_rounded,
                  ),
                  MetricCard(
                    label: 'Time',
                    value: AppFormatters.duration(duration),
                    detail: 'Session duration',
                    icon: Icons.timer_outlined,
                  ),
                  MetricCard(
                    label: 'Exercises',
                    value: '${routine?.exercises.length ?? 0}',
                    detail: '${session.completedSets.length} total sets',
                    icon: Icons.list_alt_rounded,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          PageSection(
            title: 'PR Highlights',
            child: prs.isEmpty
                ? const EmptyStateCard(
                    title: 'No new PRs this time',
                    body:
                        'The workout still contributes to your volume and lift history.',
                  )
                : Column(
                    children: prs.map((record) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          title: Text(
                            record.exerciseName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${AppFormatters.decimal(record.weightKg)} kg x ${record.reps}',
                          ),
                          trailing: Text(
                            '1RM ${AppFormatters.decimal(record.estimatedOneRepMax)}',
                            style: const TextStyle(
                              color: Color(0xFF257BF4),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 28),
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(
                              '${sets.length} sets',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: const Color(0xFF257BF4),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...sets.map((set) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Set ${set.setNumber}: ${AppFormatters.decimal(set.weightKg)} kg x ${set.reps}',
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
          Card(
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
                      color: const Color(0xFF257BF4),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Slider(
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
                  if (session.sessionNote.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      session.sessionNote,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
