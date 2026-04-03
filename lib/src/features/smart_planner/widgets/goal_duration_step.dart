// lib/src/features/smart_planner/widgets/goal_duration_step.dart
import 'package:flutter/material.dart';
import 'package:training_engine/training_engine.dart';

const _blue600 = Color(0xFF2563EB);
const _slate900 = Color(0xFF0F172A);
const _slate600 = Color(0xFF475569);
const _slate100 = Color(0xFFF1F5F9);
const _slate200 = Color(0xFFE2E8F0);

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Training Goal',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 12),
        _GoalSegmentedButton(
          goal: goal,
          onGoalChanged: onGoalChanged,
        ),
        const SizedBox(height: 28),
        const Text(
          'Max Session Duration',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '$durationMinutes min',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: _blue600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _blue600,
            inactiveTrackColor: _slate200,
            thumbColor: _blue600,
            overlayColor: _blue600.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: durationMinutes.toDouble(),
            min: 30,
            max: 120,
            divisions: 6,
            label: '$durationMinutes min',
            onChanged: (value) => onDurationChanged(value.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '30m',
                style: TextStyle(fontSize: 12, color: _slate600),
              ),
              Text(
                '120m',
                style: TextStyle(fontSize: 12, color: _slate600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom segmented button styled as a slate-100 rounded-xl container with
/// the active option on a white background with a subtle shadow.
class _GoalSegmentedButton extends StatelessWidget {
  const _GoalSegmentedButton({
    required this.goal,
    required this.onGoalChanged,
  });

  final HypertrophyGoal goal;
  final ValueChanged<HypertrophyGoal> onGoalChanged;

  static const _options = [
    (HypertrophyGoal.hypertrophy, 'Hypertrophy'),
    (HypertrophyGoal.strength, 'Strength'),
    (HypertrophyGoal.general, 'General'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (value, label) in _options)
            Expanded(
              child: Semantics(
                selected: goal == value,
                button: true,
                label: label,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onGoalChanged(value),
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: goal == value ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: goal == value
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: goal == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: goal == value ? _slate900 : _slate600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
