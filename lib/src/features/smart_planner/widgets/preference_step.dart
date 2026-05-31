import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';

const _blue600 = Color(0xFF2563EB);
const _blue50 = Color(0xFFEFF6FF);
const _red500 = Color(0xFFEF4444);
const _red50 = Color(0xFFFEF2F2);
const _slate600 = Color(0xFF475569);
const _slate200 = Color(0xFFE2E8F0);
const _slate50 = Color(0xFFF8FAFC);

/// A widget that shows two multi-select lists: preferred exercises and
/// excluded exercises. Selecting an exercise in one list automatically
/// removes it from the other (mutual exclusion).
class PreferenceStep extends StatelessWidget {
  const PreferenceStep({
    super.key,
    required this.exercises,
    required this.preferredIds,
    required this.excludedIds,
    required this.onPreferredChanged,
    required this.onExcludedChanged,
  });

  final List<Exercise> exercises;
  final List<String> preferredIds;
  final List<String> excludedIds;
  final ValueChanged<List<String>> onPreferredChanged;
  final ValueChanged<List<String>> onExcludedChanged;

  void _togglePreferred(String id) {
    final updated = List<String>.from(preferredIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
      // Mutual exclusion: remove from excluded
      final updatedExcluded = List<String>.from(excludedIds)..remove(id);
      onExcludedChanged(updatedExcluded);
    }
    onPreferredChanged(updated);
  }

  void _toggleExcluded(String id) {
    final updated = List<String>.from(excludedIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
      // Mutual exclusion: remove from preferred
      final updatedPreferred = List<String>.from(preferredIds)..remove(id);
      onPreferredChanged(updatedPreferred);
    }
    onExcludedChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Preferred exercises ──────────────────────────────────────────
        // Section header — text matches test expectation ("Preferred Exercises")
        _SectionHeader(label: l10n.preferredExercises, color: _blue600),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.exercisesPrioritised,
            style: const TextStyle(fontSize: 12, color: _slate600),
          ),
        ),
        Material(
          color: _slate50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _slate200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final exercise in exercises)
                CheckboxListTile(
                  key: ValueKey('preferred_${exercise.id}'),
                  title: Text(exercise.name),
                  value: preferredIds.contains(exercise.id),
                  onChanged: (_) => _togglePreferred(exercise.id),
                  activeColor: _blue600,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  tileColor: preferredIds.contains(exercise.id)
                      ? _blue50
                      : Colors.transparent,
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Excluded exercises ───────────────────────────────────────────
        _SectionHeader(label: l10n.excludedExercises, color: _red500),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.exercisesNeverAppear,
            style: const TextStyle(fontSize: 12, color: _slate600),
          ),
        ),
        Material(
          color: _slate50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _slate200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final exercise in exercises)
                CheckboxListTile(
                  key: ValueKey('excluded_${exercise.id}'),
                  title: Text(exercise.name),
                  value: excludedIds.contains(exercise.id),
                  onChanged: (_) => _toggleExcluded(exercise.id),
                  activeColor: _red500,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  tileColor: excludedIds.contains(exercise.id)
                      ? _red50
                      : Colors.transparent,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
    );
  }
}
