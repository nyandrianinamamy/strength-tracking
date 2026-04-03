import 'package:flutter/material.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';

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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Preferred Exercises',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'These exercises will be prioritised in your plan.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final exercise in exercises)
          CheckboxListTile(
            key: ValueKey('preferred_${exercise.id}'),
            title: Text(exercise.name),
            value: preferredIds.contains(exercise.id),
            onChanged: (_) => _togglePreferred(exercise.id),
          ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Excluded Exercises',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'These exercises will never appear in your plan.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final exercise in exercises)
          CheckboxListTile(
            key: ValueKey('excluded_${exercise.id}'),
            title: Text(exercise.name),
            value: excludedIds.contains(exercise.id),
            onChanged: (_) => _toggleExcluded(exercise.id),
          ),
      ],
    );
  }
}
