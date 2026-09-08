// lib/src/features/smart_planner/widgets/day_picker.dart
import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final days = [
      (l10n.dayMon, 1),
      (l10n.dayTue, 2),
      (l10n.dayWed, 3),
      (l10n.dayThu, 4),
      (l10n.dayFri, 5),
      (l10n.daySat, 6),
      (l10n.daySun, 0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in days)
              _DayChip(
                label: label,
                value: value,
                selected: selectedDays.contains(value),
                onTap: () => onDayToggled(value),
              ),
          ],
        ),
        if (splitLabel != null) ...[
          const SizedBox(height: 12),
          Text(
            splitLabel!,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// A custom styled day chip that wraps [FilterChip] but with Figma-matched
/// colors: selected = blue-50 bg + blue-700 text + blue-200 border,
/// unselected = slate-50 bg + slate-600 text.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: selected,
      checkmarkColor: const Color(0xFF1D4ED8),
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(
        color: selected ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
