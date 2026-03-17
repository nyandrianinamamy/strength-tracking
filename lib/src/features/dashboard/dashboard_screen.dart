import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateControllerProvider);
    final snapshot = ref.read(progressServiceProvider).dashboardSnapshot(state);
    final nextRoutine = snapshot.nextRoutine;
    final activeSession = snapshot.activeSession;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'Train with intent.',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          activeSession != null
              ? 'Your current session is still open. Jump back in and keep the momentum.'
              : 'Log your work, protect the streak, and let the app surface the progress.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 420;
            return GridView.count(
              crossAxisCount: isWide ? 2 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isWide ? 1.35 : 2.2,
              children: [
                MetricCard(
                  label: 'Workouts',
                  value: '${snapshot.totalWorkouts}',
                  detail: snapshot.workoutDelta >= 0
                      ? '+${snapshot.workoutDelta} vs last week'
                      : '${snapshot.workoutDelta} vs last week',
                  icon: Icons.local_fire_department_rounded,
                ),
                MetricCard(
                  label: 'Recent PRs',
                  value: '${snapshot.personalRecordCount}',
                  detail: 'Estimated 1RM tracked automatically',
                  icon: Icons.workspace_premium_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        PageSection(
          title: activeSession != null ? 'Active Workout' : 'Next Workout',
          child: Card(
            color: const Color(0xFF111827),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeSession != null
                        ? 'Session in progress'
                        : nextRoutine?.category ?? 'Ready to train',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF8FB9FF),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activeSession != null
                        ? state.routineById(activeSession.routineId)?.name ??
                              'Workout'
                        : nextRoutine?.name ?? 'No routine available',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activeSession != null
                        ? '${state.routineById(activeSession.routineId)?.exercises.length ?? 0} exercises remaining in your live session.'
                        : nextRoutine == null
                        ? 'Create a routine to start training.'
                        : '${nextRoutine.estimatedDurationMin} min • ${nextRoutine.exercises.length} exercises',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF257BF4),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () {
                      if (activeSession != null) {
                        context.go('/workout/active');
                        return;
                      }

                      if (nextRoutine == null) {
                        context.push('/routine/new');
                        return;
                      }

                      ref
                          .read(routineControllerProvider)
                          .startSession(nextRoutine.id);
                      context.go('/workout/active');
                    },
                    icon: Icon(
                      activeSession != null
                          ? Icons.play_arrow_rounded
                          : Icons.fitness_center_rounded,
                    ),
                    label: Text(
                      activeSession != null
                          ? 'Resume Session'
                          : 'Start Session',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        PageSection(
          title: 'Recent Workouts',
          action: TextButton(
            onPressed: () => context.go('/progress'),
            child: const Text('View Progress'),
          ),
          child: snapshot.recentWorkouts.isEmpty
              ? const EmptyStateCard(
                  title: 'No completed workouts yet',
                  body:
                      'Start a routine and your recent sessions will appear here.',
                )
              : Column(
                  children: snapshot.recentWorkouts.map((workout) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => context.push(
                          '/workout/${workout.sessionId}/summary',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF257BF4,
                          ).withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            color: Color(0xFF257BF4),
                          ),
                        ),
                        title: Text(
                          workout.routineName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${AppFormatters.weekdayMonthDay(workout.date)} • ${AppFormatters.duration(workout.duration)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${AppFormatters.decimal(workout.totalVolumeKg)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Volume',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 28),
        PageSection(
          title: 'Workout Frequency',
          child: WorkoutFrequencyCalendar(frequency: snapshot.monthFrequency),
        ),
        const SizedBox(height: 28),
        PageSection(
          title: 'Recent PRs',
          child: snapshot.recentPrs.isEmpty
              ? const EmptyStateCard(
                  title: 'No PRs detected yet',
                  body:
                      'Your strongest sets will surface here as soon as you complete a session.',
                )
              : Column(
                  children: snapshot.recentPrs.map((record) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x14257BF4),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFF257BF4),
                          ),
                        ),
                        title: Text(
                          record.exerciseName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          AppFormatters.monthDay(record.achievedAt),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${AppFormatters.decimal(record.weightKg)} kg x ${record.reps}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '1RM ${AppFormatters.decimal(record.estimatedOneRepMax)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF257BF4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
