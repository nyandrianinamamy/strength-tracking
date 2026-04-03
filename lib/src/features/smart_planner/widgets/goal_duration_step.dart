// lib/src/features/smart_planner/widgets/goal_duration_step.dart
import 'package:flutter/material.dart';
import 'package:training_engine/training_engine.dart';

class GoalDurationStep extends StatelessWidget {
  const GoalDurationStep({
    super.key,
    required this.goal,
    required this.durationMinutes,
    required this.onGoalChanged,
    required this.onDurationChanged,
  });

  final HypertrophyGoal goal;
  final int durationMinutes;
  final ValueChanged<HypertrophyGoal> onGoalChanged;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Training Goal', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<HypertrophyGoal>(
          segments: const [
            ButtonSegment(
              value: HypertrophyGoal.hypertrophy,
              label: Text('Hypertrophy'),
            ),
            ButtonSegment(
              value: HypertrophyGoal.strength,
              label: Text('Strength'),
            ),
            ButtonSegment(
              value: HypertrophyGoal.general,
              label: Text('General'),
            ),
          ],
          selected: {goal},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              onGoalChanged(selection.first);
            }
          },
        ),
        const SizedBox(height: 24),
        Text('Max Session Duration', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('$durationMinutes min', style: textTheme.bodyLarge),
        Slider(
          value: durationMinutes.toDouble(),
          min: 30,
          max: 120,
          divisions: 6,
          label: '$durationMinutes min',
          onChanged: (value) => onDurationChanged(value.round()),
        ),
      ],
    );
  }
}
