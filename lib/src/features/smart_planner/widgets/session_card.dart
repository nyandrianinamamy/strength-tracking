// lib/src/features/smart_planner/widgets/session_card.dart
import 'package:flutter/material.dart';
import 'package:training_engine/training_engine.dart';

// ---------------------------------------------------------------------------
// Day & focus label helpers
// ---------------------------------------------------------------------------

const List<String> _dayNames = [
  'Sunday',    // 0
  'Monday',    // 1
  'Tuesday',   // 2
  'Wednesday', // 3
  'Thursday',  // 4
  'Friday',    // 5
  'Saturday',  // 6
];

String _focusLabel(SessionFocus focus) {
  switch (focus) {
    case SessionFocus.fullBody:
      return 'Full Body';
    case SessionFocus.push:
      return 'Push';
    case SessionFocus.pull:
      return 'Pull';
    case SessionFocus.legs:
      return 'Legs';
    case SessionFocus.upper:
      return 'Upper';
    case SessionFocus.lower:
      return 'Lower';
  }
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Expandable card that shows a planned training session with inline exercise
/// editing and swipe-to-delete support.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.sessionIndex,
    required this.exerciseNameResolver,
    required this.editedKeys,
    required this.onExerciseUpdated,
    required this.onExerciseRemoved,
    required this.onExerciseSwapRequested,
  });

  final PlannedSession session;
  final int sessionIndex;

  /// Resolves an exercise ID to a human-readable name.
  final String Function(String exerciseId) exerciseNameResolver;

  /// Keys of exercises that have been manually edited (format: "sessionIdx:exerciseIdx").
  final Set<String> editedKeys;

  /// Called when sets or reps are changed via the steppers.
  final void Function({
    required int sessionIndex,
    required int exerciseIndex,
    required int? sets,
    required int? reps,
  }) onExerciseUpdated;

  /// Called when an exercise is dismissed (swipe-to-delete).
  final ValueChanged<int> onExerciseRemoved;

  /// Called when the user taps an exercise row to swap it.
  final ValueChanged<int> onExerciseSwapRequested;

  @override
  Widget build(BuildContext context) {
    final dayName = _dayNames[session.dayOfWeek.clamp(0, 6)];
    final focusStr = _focusLabel(session.focus);
    final durationMin = session.estimatedDuration.inMinutes;
    final count = session.exercises.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text('$dayName \u2014 $focusStr'),
        subtitle: Text('$durationMin min \u2022 $count exercises'),
        children: [
          for (int i = 0; i < session.exercises.length; i++)
            _ExerciseRow(
              exercise: session.exercises[i],
              exerciseIndex: i,
              sessionIndex: sessionIndex,
              name: exerciseNameResolver(session.exercises[i].exerciseId),
              isEdited: editedKeys.contains('$sessionIndex:$i'),
              onUpdated: onExerciseUpdated,
              onRemoved: onExerciseRemoved,
              onSwapRequested: onExerciseSwapRequested,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private: exercise row
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.exerciseIndex,
    required this.sessionIndex,
    required this.name,
    required this.isEdited,
    required this.onUpdated,
    required this.onRemoved,
    required this.onSwapRequested,
  });

  final PlannedExercise exercise;
  final int exerciseIndex;
  final int sessionIndex;
  final String name;
  final bool isEdited;

  final void Function({
    required int sessionIndex,
    required int exerciseIndex,
    required int? sets,
    required int? reps,
  }) onUpdated;

  final ValueChanged<int> onRemoved;
  final ValueChanged<int> onSwapRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <InlineSpan>[
      TextSpan(
        text:
            '${exercise.targetSets}\u00d7${exercise.targetReps}'
            ' @${exercise.targetRpe.toStringAsFixed(1)}'
            ' ${exercise.restSeconds}s rest',
      ),
      if (exercise.isSupersetPair) ...[
        const TextSpan(text: '  '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'SS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ];

    return Dismissible(
      key: ValueKey('exercise_$sessionIndex:$exerciseIndex'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: theme.colorScheme.error,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      onDismissed: (_) => onRemoved(exerciseIndex),
      child: ListTile(
        leading: isEdited
            ? Icon(Icons.edit, size: 18, color: theme.colorScheme.primary)
            : null,
        title: Text(name),
        subtitle: Text.rich(TextSpan(children: subtitleParts)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Stepper(
              value: exercise.targetSets,
              onDecrement: () => onUpdated(
                sessionIndex: sessionIndex,
                exerciseIndex: exerciseIndex,
                sets: (exercise.targetSets - 1).clamp(1, 99),
                reps: null,
              ),
              onIncrement: () => onUpdated(
                sessionIndex: sessionIndex,
                exerciseIndex: exerciseIndex,
                sets: exercise.targetSets + 1,
                reps: null,
              ),
            ),
            const SizedBox(width: 8),
            _Stepper(
              value: exercise.targetReps,
              onDecrement: () => onUpdated(
                sessionIndex: sessionIndex,
                exerciseIndex: exerciseIndex,
                sets: null,
                reps: (exercise.targetReps - 1).clamp(1, 99),
              ),
              onIncrement: () => onUpdated(
                sessionIndex: sessionIndex,
                exerciseIndex: exerciseIndex,
                sets: null,
                reps: exercise.targetReps + 1,
              ),
            ),
          ],
        ),
        onTap: () => onSwapRequested(exerciseIndex),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private: stepper widget
// ---------------------------------------------------------------------------

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onDecrement,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.remove, size: 16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$value',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        InkWell(
          onTap: onIncrement,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.add, size: 16),
          ),
        ),
      ],
    );
  }
}
