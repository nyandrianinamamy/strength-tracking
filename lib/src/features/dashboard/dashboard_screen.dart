import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/auth/account_section.dart';
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
        // Step 1: Profile header
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.person,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (context) {
                final userName = state.userName.isEmpty ? 'Athlete' : state.userName;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.slateInactive,
                          ),
                    ),
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            Stack(
              children: [
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => const AccountSection(),
                    );
                  },
                  icon: const Icon(Icons.notifications_none),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Step 2: Stats grid with MetricCard + badge
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: constraints.maxWidth >= 420 ? 1.35 : 1.1,
              children: [
                MetricCard(
                  label: 'Workouts',
                  value: '${snapshot.totalWorkouts}',
                  detail: snapshot.workoutDelta >= 0
                      ? '+${snapshot.workoutDelta} vs last week'
                      : '${snapshot.workoutDelta} vs last week',
                  icon: Icons.local_fire_department_rounded,
                  badge: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          snapshot.workoutDelta >= 0
                              ? '+${snapshot.workoutDelta}'
                              : '${snapshot.workoutDelta}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                MetricCard(
                  label: 'Recent PRs',
                  value: '${snapshot.personalRecordCount}',
                  detail: 'Estimated 1RM tracked automatically',
                  icon: Icons.workspace_premium_rounded,
                  badge: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Step 3: Next Workout card
        PageSection(
          title: activeSession != null ? 'Active Workout' : 'Next Workout',
          child: Card(
            color: const Color(0xFF0F172A),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (activeSession != null
                            ? 'Session in progress'
                            : nextRoutine?.category ?? 'Ready to train')
                        .toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF8FB9FF),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
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
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          activeSession != null
                              ? '${state.routineById(activeSession.routineId)?.exercises.length ?? 0} exercises remaining'
                              : nextRoutine == null
                                  ? 'Create a routine to start training.'
                                  : '${nextRoutine.estimatedDurationMin} min \u2022 ${nextRoutine.exercises.length} exercises',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
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
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      activeSession != null
                          ? 'RESUME SESSION'
                          : 'START SESSION',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Step 4: Recent Workouts
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
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: Text(
                          workout.routineName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${AppFormatters.weekdayMonthDay(workout.date)} \u2022 ${AppFormatters.duration(workout.duration)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.weight(workout.totalVolumeKg, state.preferredUnit),
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

        // Step 5: Workout Frequency
        PageSection(
          title: 'Workout Frequency',
          child: WorkoutFrequencyCalendar(
            frequency: snapshot.monthFrequency,
            onDateTap: (date, count) {
              // Find workouts on this date
              final dayWorkouts = state.completedSessions.where((session) {
                final sessionDate = session.endedAt ?? session.startedAt;
                return sessionDate.year == date.year &&
                    sessionDate.month == date.month &&
                    sessionDate.day == date.day;
              }).toList();

              if (dayWorkouts.isEmpty) return;

              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppFormatters.weekdayMonthDay(date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dayWorkouts.length} workout${dayWorkouts.length > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.slateInactive,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...dayWorkouts.map((workout) {
                          final routine = state.routineById(workout.routineId);
                          final duration = (workout.endedAt ?? workout.startedAt)
                              .difference(workout.startedAt);
                          final volume = workout.completedSets.fold<double>(
                            0,
                            (sum, set) => sum + (set.weightKg * set.reps),
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/workout/${workout.id}/summary');
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.fitness_center_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                              title: Text(
                                routine?.name ?? 'Workout',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                '${AppFormatters.duration(duration)} \u2022 ${workout.completedSets.length} sets',
                              ),
                              trailing: Text(
                                AppFormatters.weight(volume, state.preferredUnit),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),

        // Step 6: Recent PRs
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
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppTheme.primary,
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
                              '${AppFormatters.weight(record.weightKg, state.preferredUnit)} x ${record.reps}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '1RM ${AppFormatters.decimal(record.estimatedOneRepMax)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.primary,
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
