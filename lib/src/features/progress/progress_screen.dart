import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final snapshot = ref
        .read(progressServiceProvider)
        .progressSnapshot(state);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.performanceLab,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                TabBar(
                  tabs: [
                    Tab(text: l10n.overview),
                    Tab(text: l10n.lifts),
                    Tab(text: l10n.volumeTab),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                          children: [
                            MetricCard(
                              label: l10n.workoutDays,
                              value: snapshot.averageWorkoutDaysPerWeek
                                  .toStringAsFixed(1),
                              detail: l10n.perWeekAverage,
                              icon: Icons.calendar_month_rounded,
                            ),
                            MetricCard(
                              label: l10n.activeStreak,
                              value: '${snapshot.activeStreakDays} days',
                              detail: l10n.contiguousStreak,
                              icon: Icons.bolt_rounded,
                            ),
                          ],
                        ),
                    const SizedBox(height: 28),
                    PageSection(
                      title: l10n.personalRecords,
                      child: Column(
                        children: snapshot.personalRecords.map((
                          record,
                        ) {
                          final subtitle = record.isTimed
                              ? '${AppFormatters.duration(Duration(seconds: record.durationSeconds))} • ${AppFormatters.monthDay(record.achievedAt)}'
                              : '${AppFormatters.weight(record.weightKg, state.preferredUnit)} x ${record.reps} • ${AppFormatters.monthDay(record.achievedAt)}';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                record.exerciseName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(subtitle),
                              trailing: record.isTimed
                                  ? null
                                  : Text(
                                      AppFormatters.weight(
                                        record.estimatedOneRepMax,
                                        state.preferredUnit,
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: snapshot.topLifts.map((lift) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lift.exerciseName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (lift.isTimed)
                                  _LiftChip(
                                    label: 'Best Time',
                                    value: AppFormatters.duration(Duration(seconds: lift.durationSeconds)),
                                  )
                                else ...[
                                  _LiftChip(
                                    label: 'Best Set',
                                    value:
                                        '${AppFormatters.weight(lift.bestSetWeightKg, state.preferredUnit)} x ${lift.reps}',
                                  ),
                                  _LiftChip(
                                    label: 'Estimated 1RM',
                                    value:
                                        AppFormatters.weight(lift.estimatedOneRepMax, state.preferredUnit),
                                  ),
                                ],
                                _LiftChip(
                                  label: 'Achieved',
                                  value: AppFormatters.monthDay(
                                    lift.achievedAt,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    PageSection(
                      title: l10n.weeklyVolume,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: _VolumeBars(points: snapshot.weeklyVolume),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    PageSection(
                      title: 'Volume Data',
                      child: Column(
                        children: snapshot.weeklyVolume.reversed.take(6).map((
                          point,
                        ) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                'Week of ${AppFormatters.monthDay(point.weekStart)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              trailing: Text(
                                AppFormatters.weight(point.totalVolumeKg, state.preferredUnit),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiftChip extends StatelessWidget {
  const _LiftChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.appColors.subtleText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _VolumeBars extends StatelessWidget {
  const _VolumeBars({required this.points});

  final List<VolumePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return EmptyStateCard(
        title: l10n.noVolumeData,
        body: l10n.completeWorkoutsPrompt,
      );
    }

    final maxValue = points.fold<double>(
      0,
      (best, point) => math.max(best, point.totalVolumeKg),
    );

    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final heightFactor = maxValue == 0
              ? 0.0
              : point.totalVolumeKg / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.decimal(point.totalVolumeKg),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor,
                        widthFactor: 0.75,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.monthDay(point.weekStart),
                    style: TextStyle(fontSize: 11, color: context.appColors.subtleText),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
