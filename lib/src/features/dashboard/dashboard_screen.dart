import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/auth/account_section.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_card.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final snapshot = ref.read(progressServiceProvider).dashboardSnapshot(state);
    final nextRoutine = snapshot.nextRoutine;
    final activeSession = snapshot.activeSession;
    final activeGroup = state.activeRoutineGroup;
    final activeSessionIsStale = snapshot.activeSessionIsStale;

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
                child: const Icon(Icons.person, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (context) {
                final userName = state.userName.isEmpty
                    ? l10n.athlete
                    : state.userName;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.welcomeBack,
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
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.7,
                        minChildSize: 0.4,
                        maxChildSize: 0.9,
                        expand: false,
                        builder: (_, _) => const AccountSection(),
                      ),
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
                  label: l10n.workouts,
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
                  label: l10n.recentPrs,
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
                    child: Text(
                      l10n.newBadge,
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
        const SizedBox(height: 20),
        const PageSection(title: 'Muscle Fatigue', child: MuscleHeatmapCard()),
        const SizedBox(height: 28),

        // Step 3: Next Workout card
        PageSection(
          title: activeSession != null ? l10n.activeWorkout : l10n.nextWorkout,
          child: Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A45)
                : const Color(0xFF0F172A),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (activeSession != null
                            ? activeSessionIsStale
                                  ? 'Workout paused'
                                  : l10n.sessionInProgress
                            : snapshot.nextRoutineGroupName ??
                                  nextRoutine?.category ??
                                  l10n.readyToTrain)
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
                        : nextRoutine?.name ?? l10n.noRoutineAvailable,
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
                              ? activeSessionIsStale
                                    ? snapshot.activeSessionIdleLabel ??
                                          'Paused'
                                    : '${state.routineById(activeSession.routineId)?.exercises.length ?? 0} exercises remaining'
                              : nextRoutine == null
                              ? l10n.createRoutineToStart
                              : '${nextRoutine.estimatedDurationMin} min \u2022 ${nextRoutine.exercises.length} exercises',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  if (activeSession == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      snapshot.nextRoutineReason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBBD0FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                          ? activeSessionIsStale
                                ? 'Review session'
                                : l10n.resumeSession
                          : l10n.startSession,
                    ),
                  ),
                  if (activeSession == null &&
                      activeGroup != null &&
                      snapshot.canSkipNextRoutine) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF8FB9FF)),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: nextRoutine == null
                          ? null
                          : () {
                              ref
                                  .read(routineGroupControllerProvider)
                                  .skipNextInGroup(activeGroup.id);
                            },
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Skip for now'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Step 4: Recent Workouts
        PageSection(
          title: l10n.recentWorkouts,
          action: TextButton(
            onPressed: () => context.go('/progress'),
            child: Text(l10n.viewProgress),
          ),
          child: snapshot.recentWorkouts.isEmpty
              ? EmptyStateCard(
                  title: l10n.noCompletedWorkouts,
                  body: l10n.startRoutinePrompt,
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
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.1,
                          ),
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
                              AppFormatters.weight(
                                workout.totalVolumeKg,
                                state.preferredUnit,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.volume,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.54),
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
          title: l10n.workoutFrequency,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dayWorkouts.length} workout${dayWorkouts.length > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.slateInactive),
                        ),
                        const SizedBox(height: 16),
                        ...dayWorkouts.map((workout) {
                          final routine = state.routineById(workout.routineId);
                          final duration =
                              (workout.endedAt ?? workout.startedAt).difference(
                                workout.startedAt,
                              );
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
                                backgroundColor: AppTheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                child: const Icon(
                                  Icons.fitness_center_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                              title: Text(
                                routine?.name ?? 'Workout',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${AppFormatters.duration(duration)} \u2022 ${workout.completedSets.length} sets',
                              ),
                              trailing: Text(
                                AppFormatters.weight(
                                  volume,
                                  state.preferredUnit,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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
          title: l10n.recentPrsTitle,
          child: snapshot.recentPrs.isEmpty
              ? EmptyStateCard(title: l10n.noPrsYet, body: l10n.prsWillAppear)
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
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.1,
                          ),
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
                        trailing: record.isTimed
                            ? Text(
                                AppFormatters.duration(Duration(seconds: record.durationSeconds)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Column(
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
