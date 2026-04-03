// lib/src/features/smart_planner/widgets/plan_preview.dart
import 'package:flutter/material.dart';
import 'package:training_engine/training_engine.dart';

import 'session_card.dart';

// ---------------------------------------------------------------------------
// Split type label helper
// ---------------------------------------------------------------------------

String _splitLabel(SplitType split) {
  switch (split) {
    case SplitType.fullBody:
      return 'Full Body';
    case SplitType.upperLower:
      return 'Upper/Lower';
    case SplitType.pushPullLegs:
      return 'Push/Pull/Legs';
  }
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Displays a generated [WeeklyPlan] as a scrollable list of [SessionCard]s
/// with Regenerate and Adopt Plan action buttons at the bottom.
class PlanPreview extends StatelessWidget {
  const PlanPreview({
    super.key,
    required this.plan,
    required this.editedKeys,
    required this.exerciseNameResolver,
    required this.onExerciseUpdated,
    required this.onExerciseRemoved,
    required this.onExerciseSwapRequested,
    required this.onRegenerate,
    required this.onAdopt,
  });

  final WeeklyPlan plan;

  /// Keys of exercises that have been manually edited (format: "sessionIdx:exerciseIdx").
  final Set<String> editedKeys;

  /// Resolves an exercise ID to a human-readable name.
  final String Function(String exerciseId) exerciseNameResolver;

  /// Called when sets or reps are changed in any session's exercise row.
  final void Function({
    required int sessionIndex,
    required int exerciseIndex,
    required int? sets,
    required int? reps,
  }) onExerciseUpdated;

  /// Called when an exercise is removed in any session.
  final void Function({
    required int sessionIndex,
    required int exerciseIndex,
  }) onExerciseRemoved;

  /// Called when the user requests to swap an exercise in any session.
  final void Function({
    required int sessionIndex,
    required int exerciseIndex,
  }) onExerciseSwapRequested;

  /// Called when the user taps the Regenerate button.
  final VoidCallback onRegenerate;

  /// Called when the user taps the Adopt Plan button.
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionCount = plan.sessions.length;

    return ListView(
      children: [
        // ---------------------------------------------------------------
        // Header
        // ---------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            _splitLabel(plan.splitType),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '$sessionCount sessions per week',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // ---------------------------------------------------------------
        // Session cards
        // ---------------------------------------------------------------
        for (int i = 0; i < plan.sessions.length; i++)
          SessionCard(
            session: plan.sessions[i],
            sessionIndex: i,
            exerciseNameResolver: exerciseNameResolver,
            editedKeys: editedKeys,
            onExerciseUpdated: onExerciseUpdated,
            onExerciseRemoved: (exerciseIndex) => onExerciseRemoved(
              sessionIndex: i,
              exerciseIndex: exerciseIndex,
            ),
            onExerciseSwapRequested: (exerciseIndex) =>
                onExerciseSwapRequested(
              sessionIndex: i,
              exerciseIndex: exerciseIndex,
            ),
          ),

        // ---------------------------------------------------------------
        // Action row
        // ---------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRegenerate,
                  child: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onAdopt,
                  child: const Text('Adopt Plan'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
