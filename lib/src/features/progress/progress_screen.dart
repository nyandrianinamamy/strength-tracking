import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  'Performance Lab',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Lifts'),
                    Tab(text: 'Volume'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                              label: 'Workout Days',
                              value: snapshot.averageWorkoutDaysPerWeek
                                  .toStringAsFixed(1),
                              detail: 'Per week average',
                              icon: Icons.calendar_month_rounded,
                            ),
                            MetricCard(
                              label: 'Active Streak',
                              value: '${snapshot.activeStreakDays} days',
                              detail: 'Contiguous training streak',
                              icon: Icons.bolt_rounded,
                            ),
                          ],
                        ),
                    const SizedBox(height: 28),
                    PageSection(
                      title: 'Personal Records',
                      child: Column(
                        children: snapshot.personalRecords.take(6).map((
                          record,
                        ) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                record.exerciseName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${AppFormatters.weight(record.weightKg, state.preferredUnit)} x ${record.reps} • ${AppFormatters.monthDay(record.achievedAt)}',
                              ),
                              trailing: Text(
                                AppFormatters.decimal(
                                  record.estimatedOneRepMax,
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF257BF4),
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    PageSection(
                      title: 'Weekly Volume',
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
        color: const Color(0xFFF4F8FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
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
      return const EmptyStateCard(
        title: 'No volume data yet',
        body: 'Complete workouts to populate the weekly volume chart.',
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
                            color: const Color(0xFF257BF4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.monthDay(point.weekStart),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
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
