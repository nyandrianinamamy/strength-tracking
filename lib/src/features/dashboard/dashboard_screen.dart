import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/debug_surface.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_card.dart';
import 'package:strength_training_tracker/src/features/dashboard/training_readiness_card.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

String? _displayCategory(AppLocalizations l10n, String? raw) {
  if (raw == null) return null;
  final key = Routine.normalizeCategory(raw);
  return switch (key) {
    'strength' => l10n.strength,
    'hypertrophy' => l10n.hypertrophy,
    'mobility' => l10n.mobility,
    _ => l10n.strength,
  };
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final snapshotAsync = ref.watch(dashboardSnapshotProvider);
    return snapshotAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (snapshot) {
        final nextRoutine = snapshot.nextRoutine;
        final activeSession = snapshot.activeSession;
        final activeGroup = state.activeRoutineGroup;
        final activeSessionIsStale = snapshot.activeSessionIsStale;
        final colorScheme = Theme.of(context).colorScheme;
        final appColors = context.appColors;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            // Step 1: Profile header
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.person, color: colorScheme.primary),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: appColors.subtleText),
                        ),
                        Text(
                          userName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
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
                          ? l10n.vsLastWeek('+${snapshot.workoutDelta}')
                          : l10n.vsLastWeek('${snapshot.workoutDelta}'),
                      icon: Icons.local_fire_department_rounded,
                      badge: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              snapshot.workoutDelta >= 0
                                  ? '+${snapshot.workoutDelta}'
                                  : '${snapshot.workoutDelta}',
                              style: TextStyle(
                                color: colorScheme.primary,
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
                      detail: l10n.estimated1rmTracked,
                      icon: Icons.workspace_premium_rounded,
                      onTap: () => context.go('/progress'),
                      badge: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.newBadge,
                          style: TextStyle(
                            color: colorScheme.onPrimary,
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
            PageSection(
              title: l10n.muscleFatigue,
              action: shouldShowTrainingEngineDebug()
                  ? TextButton.icon(
                      onPressed: () => context.push('/debug/training-engine'),
                      icon: const Icon(Icons.science_outlined),
                      label: Text(l10n.engineDebug),
                    )
                  : null,
              child: const MuscleHeatmapCard(),
            ),
            const SizedBox(height: 20),
            const TrainingReadinessCard(),
            const SizedBox(height: 28),

            // Step 3: Next Workout card
            PageSection(
              title: activeSession != null
                  ? l10n.activeWorkout
                  : l10n.nextWorkout,
              child: Card(
                color: appColors.ink,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (activeSession != null
                                ? activeSessionIsStale
                                      ? l10n.workoutPaused
                                      : l10n.sessionInProgress
                                : snapshot.nextRoutineGroupName ??
                                      _displayCategory(
                                        l10n,
                                        nextRoutine?.category,
                                      ) ??
                                      l10n.readyToTrain)
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activeSession != null
                            ? state
                                      .routineById(activeSession.routineId)
                                      ?.name ??
                                  l10n.workoutLabel
                            : nextRoutine?.name ?? l10n.noRoutineAvailable,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: colorScheme.onPrimary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activeSession != null
                                  ? activeSessionIsStale
                                        ? snapshot.activeSessionIdleLabel ??
                                              l10n.workoutPaused
                                        : l10n.nExercisesRemaining(
                                            state
                                                    .routineById(
                                                      activeSession.routineId,
                                                    )
                                                    ?.exercises
                                                    .length ??
                                                0,
                                          )
                                  : nextRoutine == null
                                  ? l10n.createRoutineToStart
                                  : '${nextRoutine.estimatedDurationMin} min \u2022 ${nextRoutine.exercises.length} exercises',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onPrimary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (activeSession == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          snapshot.nextRoutineReason,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
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
                                    ? l10n.reviewSession
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
                            foregroundColor: colorScheme.onPrimary,
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
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
                          label: Text(l10n.skipForNow),
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
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              workout.routineName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
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
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.54,
                                    ),
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
                sessions: snapshot.calendarSessions,
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
                    useRootNavigator: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
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
                                  color: appColors.border,
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
                                  ?.copyWith(color: appColors.subtleText),
                            ),
                            const SizedBox(height: 16),
                            ...dayWorkouts.map((workout) {
                              final routine = state.routineById(
                                workout.routineId,
                              );
                              final duration =
                                  (workout.endedAt ?? workout.startedAt)
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
                                    context.push(
                                      '/workout/${workout.id}/summary',
                                    );
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.fitness_center_rounded,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    routine?.name ?? l10n.workoutLabel,
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
              trailing: TextButton(
                onPressed: () => context.go('/progress'),
                child: Text(l10n.viewAll),
              ),
              child: snapshot.recentPrs.isEmpty
                  ? EmptyStateCard(
                      title: l10n.noPrsYet,
                      body: l10n.prsWillAppear,
                    )
                  : Column(
                      children: snapshot.recentPrs.map((record) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => context.go('/progress'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                Icons.workspace_premium_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              record.exerciseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              AppFormatters.monthDay(record.achievedAt),
                            ),
                            trailing: record.isTimed
                                ? Text(
                                    AppFormatters.duration(
                                      Duration(seconds: record.durationSeconds),
                                    ),
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
                                        '${l10n.estimated1rm} ${AppFormatters.weight(record.estimatedOneRepMax, state.preferredUnit)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.primary,
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
      },
    );
  }
}
