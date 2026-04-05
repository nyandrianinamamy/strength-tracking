import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:training_engine/training_engine.dart';

import 'package:strength_training_tracker/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/common_widgets.dart';
import '../training_engine/training_engine_provider.dart';

class TrainingReadinessCard extends ConsumerWidget {
  const TrainingReadinessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineAsync = ref.watch(trainingEngineProvider);

    return engineAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => const EmptyStateCard(
        title: 'Training Readiness',
        body: 'Adaptive guidance is temporarily unavailable.',
      ),
      data: (engine) {
        final readinessAsync = ref.watch(readinessProvider);
        return readinessAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => const EmptyStateCard(
            title: 'Training Readiness',
            body: 'Adaptive guidance is temporarily unavailable.',
          ),
          data: (readiness) {
            if (readiness.tier == ReadinessTier.cold &&
                engine.state.sessionsIngested == 0) {
              return EmptyStateCard(
                title: 'Training Readiness',
                body: AppLocalizations.of(context)!.readinessEmptyCold,
              );
            }
            if (readiness.tier == ReadinessTier.cold) {
              return EmptyStateCard(
                title: 'Training Readiness',
                body: AppLocalizations.of(context)!.readinessEmptyColdNoHealthKit,
              );
            }
            return _ReadinessCard(readiness: readiness, engine: engine);
          },
        );
      },
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness, required this.engine});

  final ReadinessScore readiness;
  final TrainingEngine engine;

  @override
  Widget build(BuildContext context) {
    final score = readiness.score.round().clamp(0, 100);
    final primary = Theme.of(context).colorScheme.primary;
    final subtleText = context.appColors.subtleText;

    final sleepData = _sleepSummary();
    final hrvData = _hrvSummary();
    final fatigueData = _fatigueSummary();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined, size: 14, color: subtleText),
                const SizedBox(width: 4),
                Text(
                  'TRAINING READINESS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: subtleText,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Score row: headline + circular indicator
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headlineForScore(score),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitleForScore(score),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subtleText,
                        ),
                      ),
                      if (readiness.tier != ReadinessTier.full) ...[
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.readinessLimitedData,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: subtleText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CustomPaint(
                    painter: _CircularScorePainter(
                      score: score / 100,
                      trackColor: primary.withValues(alpha: 0.1),
                      progressColor: primary,
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3-column data grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DataColumn(
                      icon: Icons.nightlight_round_outlined,
                      label: 'SLEEP',
                      value: sleepData.value,
                      status: sleepData.status,
                      statusColor: primary,
                      subtleColor: subtleText,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: _DataColumn(
                      icon: Icons.favorite_outline,
                      label: 'HRV',
                      value: hrvData.value,
                      status: hrvData.status,
                      statusColor: primary,
                      subtleColor: subtleText,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: _DataColumn(
                      icon: Icons.bolt_outlined,
                      label: 'FATIGUE',
                      value: fatigueData.value,
                      status: fatigueData.status,
                      statusColor: primary,
                      subtleColor: subtleText,
                    ),
                  ),
                ],
              ),
            ),

            // Last sync footer
            if (engine.state.lastHealthKitFetch != null)
              _SyncFooter(
                lastSync: engine.state.lastHealthKitFetch!,
                subtleText: subtleText,
              ),
          ],
        ),
      ),
    );
  }

  String _headlineForScore(int score) {
    if (score >= 80) return 'Primed to perform';
    if (score >= 60) return 'Good to go';
    if (score >= 40) return 'Recovering';
    return 'Take it lighter';
  }

  String _subtitleForScore(int score) {
    if (score >= 80) return 'Your recovery is optimal today.';
    if (score >= 60) return 'Your recovery is stable today.';
    if (score >= 40) return 'Give your body more time to recover.';
    return 'Consider a deload or rest day.';
  }

  _DataSummary _sleepSummary() {
    final sleep = engine.state.sleepHistory;
    if (sleep.isEmpty) return const _DataSummary(value: '--', status: 'No data');

    final latest = sleep.last;
    final hours = latest.totalSleep.inMinutes ~/ 60;
    final mins = latest.totalSleep.inMinutes % 60;
    final value = '${hours}h ${mins}m';

    final totalMins = latest.totalSleep.inMinutes;
    final status = totalMins >= 420 ? 'Optimal' : totalMins >= 360 ? 'Fair' : 'Low';
    return _DataSummary(value: value, status: status);
  }

  _DataSummary _hrvSummary() {
    final hrv = engine.state.hrvHistory;
    if (hrv.isEmpty) return const _DataSummary(value: '--', status: 'No data');

    final latest = hrv.last;
    final value = '${latest.sdnn.round()} ms';

    final score = readiness.componentScores['hrv'];
    final status = score == null
        ? 'Measured'
        : score >= 70
            ? 'Balanced'
            : score >= 40
                ? 'Fair'
                : 'Low';
    return _DataSummary(value: value, status: status);
  }

  _DataSummary _fatigueSummary() {
    final fatigueMap = engine.fullFatigueMap();
    if (fatigueMap.isEmpty) {
      return const _DataSummary(value: '--', status: 'No data');
    }

    final maxFatigue = fatigueMap.values
        .map((s) => s.level)
        .reduce((a, b) => a > b ? a : b);

    final value = maxFatigue < 20 ? 'Low' : maxFatigue < 50 ? 'Moderate' : 'High';
    final status = maxFatigue < 20
        ? 'Recovered'
        : maxFatigue < 50
            ? 'Recovering'
            : 'Fatigued';
    return _DataSummary(value: value, status: status);
  }
}

class _DataSummary {
  const _DataSummary({required this.value, required this.status});
  final String value;
  final String status;
}

class _DataColumn extends StatelessWidget {
  const _DataColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.statusColor,
    required this.subtleColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String status;
  final Color statusColor;
  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: subtleColor),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: subtleColor,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

class _SyncFooter extends StatefulWidget {
  const _SyncFooter({required this.lastSync, required this.subtleText});

  final DateTime lastSync;
  final Color subtleText;

  @override
  State<_SyncFooter> createState() => _SyncFooterState();
}

class _SyncFooterState extends State<_SyncFooter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _syncLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(widget.lastSync);
    if (diff.inMinutes < 1) return l10n.syncedJustNow;
    if (diff.inMinutes < 60) return l10n.syncedMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.syncedHoursAgo(diff.inHours);
    return l10n.syncedDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync, size: 12, color: widget.subtleText),
          const SizedBox(width: 4),
          Text(
            _syncLabel(context),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: widget.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularScorePainter extends CustomPainter {
  _CircularScorePainter({
    required this.score,
    required this.trackColor,
    required this.progressColor,
  });

  final double score;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - 3;
    const strokeWidth = 6.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * score,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CircularScorePainter oldDelegate) =>
      score != oldDelegate.score ||
      trackColor != oldDelegate.trackColor ||
      progressColor != oldDelegate.progressColor;
}
