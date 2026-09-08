import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';

// ---------------------------------------------------------------------------
// PageSection
// ---------------------------------------------------------------------------

class PageSection extends StatelessWidget {
  const PageSection({
    super.key,
    required this.title,
    this.action,
    this.trailing,
    required this.child,
  });

  final String title;
  final Widget? action;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ?trailing,
            ?action,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// MetricCard
// ---------------------------------------------------------------------------

/// Equal-width summary cards whose height follows their wrapped content.
class MetricCardRow extends StatelessWidget {
  const MetricCardRow({super.key, required this.children});

  final List<MetricCard> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [for (final card in children) Expanded(child: card)],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.badge,
    this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 8),
              if (badge != null)
                badge!
              else
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EmptyStateCard
// ---------------------------------------------------------------------------

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.icon,
    this.dashed = false,
  });

  final String title;
  final String body;
  final Widget? action;
  final IconData? icon;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    if (dashed) {
      return DashedBorderCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(body),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DashedBorderCard
// ---------------------------------------------------------------------------

class DashedBorderCard extends StatelessWidget {
  const DashedBorderCard({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          borderRadius: 16,
          strokeWidth: 1.5,
          dashWidth: 6,
          dashGap: 4,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _createDashedPath(path);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source) {
    final dashedPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        dashedPath.addPath(
          metric.extractPath(distance, end),
          Offset.zero,
        );
        distance += dashWidth + dashGap;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      strokeWidth != oldDelegate.strokeWidth;
}

// ---------------------------------------------------------------------------
// StatCard
// ---------------------------------------------------------------------------

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtext,
    this.showAccent = false,
  });

  final String label;
  final String value;
  final String? subtext;
  final bool showAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (showAccent)
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.54),
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (subtext != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtext!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.54),
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DigitalTimer
// ---------------------------------------------------------------------------

class DigitalTimer extends StatelessWidget {
  const DigitalTimer({super.key, required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isReady = remaining.inSeconds <= 0;
    final minutes = remaining.inMinutes.abs().remainder(60);
    final seconds = remaining.inSeconds.abs().remainder(60);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.restTimer,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
        ),
        const SizedBox(height: 6),
        if (isReady)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Text(
              l10n.ready,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _timerBox(context, minutes.toString().padLeft(2, '0')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _timerBox(context, seconds.toString().padLeft(2, '0')),
            ],
          ),
      ],
    );
  }

  Widget _timerBox(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.border, width: 1.5),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CategoryChips
// ---------------------------------------------------------------------------

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? Theme.of(context).colorScheme.primary : context.appColors.border,
                  ),
                ),
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WorkoutFrequencyCalendar (kept as-is for later polishing)
// ---------------------------------------------------------------------------

class WorkoutFrequencyCalendar extends StatefulWidget {
  const WorkoutFrequencyCalendar({
    super.key,
    required this.sessions,
    this.onDateTap,
  });

  final List<MonthFrequencySession> sessions;
  final void Function(DateTime date, int workoutCount)? onDateTap;

  @override
  State<WorkoutFrequencyCalendar> createState() =>
      _WorkoutFrequencyCalendarState();
}

class _WorkoutFrequencyCalendarState extends State<WorkoutFrequencyCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  MonthFrequency _buildFrequency() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final offset = firstDay.weekday % 7;
    final start = firstDay.subtract(Duration(days: offset));
    final counts = <String, int>{};

    for (final session in widget.sessions) {
      final key = '${session.date.year}-${session.date.month}-${session.date.day}';
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final days = <CalendarDayEntry>[];
    final now = DateTime.now();
    for (var i = 0; i < 42; i++) {
      final date = start.add(Duration(days: i));
      final key = '${date.year}-${date.month}-${date.day}';
      days.add(CalendarDayEntry(
        date: date,
        inMonth: date.month == _month.month,
        workouts: counts[key] ?? 0,
        isToday: date.year == now.year &&
            date.month == now.month &&
            date.day == now.day,
      ));
    }

    return MonthFrequency(month: _month, days: days);
  }

  @override
  Widget build(BuildContext context) {
    const weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final primary = Theme.of(context).colorScheme.primary;
    final frequency = _buildFrequency();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _month = DateTime(_month.year, _month.month - 1);
                  }),
                  child: Icon(Icons.chevron_left, color: primary),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      AppFormatters.monthYear(frequency.month),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _month = DateTime(_month.year, _month.month + 1);
                  }),
                  child: Icon(Icons.chevron_right, color: primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: weekDays
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.54),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: frequency.days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final day = frequency.days[index];
                final intensity = day.workouts.clamp(0, 3);

                Color? background;
                Color foreground =
                    day.inMonth
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha:0.87)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha:0.26);
                BorderSide side = BorderSide.none;

                if (intensity > 0) {
                  background = [
                    primary.withValues(alpha: 0.16),
                    primary.withValues(alpha: 0.38),
                    primary,
                  ][intensity - 1];
                  foreground =
                      intensity == 3 ? Theme.of(context).colorScheme.onPrimary : primary;
                }

                if (day.isToday) {
                  side =
                      BorderSide(color: primary, width: 1.6);
                  foreground =
                      background == null ? primary : foreground;
                }

                return GestureDetector(
                  onTap: day.workouts > 0
                      ? () => widget.onDateTap?.call(day.date, day.workouts)
                      : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.fromBorderSide(side),
                    ),
                    child: Center(
                      child: Text(
                        '${day.date.day}',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: day.workouts > 0 || day.isToday
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
