// lib/src/features/smart_planner/widgets/day_picker.dart
import 'package:flutter/material.dart';

/// A 7-day toggle row.
///
/// [selectedDays] uses the same int convention as [SmartPlannerState]:
///   0 = Sunday, 1 = Monday, …, 6 = Saturday (matching [DateTime.weekday]
///   except Sunday is 0 rather than 7).
///
/// [onDayToggled] is called with the day value whenever the user taps a chip.
///
/// [splitLabel] is an optional label shown below the chips (e.g. "Full Body",
/// "Upper/Lower") to indicate the detected training split.
class DayPicker extends StatelessWidget {
  const DayPicker({
    super.key,
    required this.selectedDays,
    required this.onDayToggled,
    this.splitLabel,
  });

  final Set<int> selectedDays;
  final ValueChanged<int> onDayToggled;
  final String? splitLabel;

  // Day labels and their corresponding int values.
  // Order: Mon-Sun so weekdays come first.
  static const List<(String label, int value)> _days = [
    ('Mon', 1),
    ('Tue', 2),
    ('Wed', 3),
    ('Thu', 4),
    ('Fri', 5),
    ('Sat', 6),
    ('Sun', 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final (label, value) in _days)
              FilterChip(
                label: Text(label),
                selected: selectedDays.contains(value),
                onSelected: (_) => onDayToggled(value),
              ),
          ],
        ),
        if (splitLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            splitLabel!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
