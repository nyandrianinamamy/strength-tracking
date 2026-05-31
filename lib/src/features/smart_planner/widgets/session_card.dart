// lib/src/features/smart_planner/widgets/session_card.dart
import 'package:flutter/material.dart';
import 'package:training_engine/training_engine.dart';

const _blue600 = Color(0xFF2563EB);
const _slate900 = Color(0xFF0F172A);
const _slate500 = Color(0xFF64748B);
const _slate200 = Color(0xFFE2E8F0);
const _slate100 = Color(0xFFF1F5F9);
const _slate50 = Color(0xFFF8FAFC);
const _purple600 = Color(0xFF9333EA);
const _purple100 = Color(0xFFF3E8FF);

// ---------------------------------------------------------------------------
// Day & focus label helpers
// ---------------------------------------------------------------------------

const List<String> _dayNames = [
  'Sunday', // 0
  'Monday', // 1
  'Tuesday', // 2
  'Wednesday', // 3
  'Thursday', // 4
  'Friday', // 5
  'Saturday', // 6
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
  })
  onExerciseUpdated;

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x0A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            '$dayName \u2014 $focusStr',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _slate900,
            ),
          ),
          subtitle: Text(
            '$durationMin min \u2022 $count exercises',
            style: const TextStyle(fontSize: 13, color: _slate500),
          ),
          trailing: const Icon(Icons.chevron_right, color: _slate500),
          children: [
            Container(
              color: _slate50,
              child: Column(
                children: [
                  for (int i = 0; i < session.exercises.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: _slate200,
                        indent: 16,
                        endIndent: 16,
                      ),
                    _ExerciseRow(
                      exercise: session.exercises[i],
                      exerciseIndex: i,
                      sessionIndex: sessionIndex,
                      name: exerciseNameResolver(
                        session.exercises[i].exerciseId,
                      ),
                      isEdited: editedKeys.contains('$sessionIndex:$i'),
                      onUpdated: onExerciseUpdated,
                      onRemoved: onExerciseRemoved,
                      onSwapRequested: onExerciseSwapRequested,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
  })
  onUpdated;

  final ValueChanged<int> onRemoved;
  final ValueChanged<int> onSwapRequested;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <InlineSpan>[
      TextSpan(
        text:
            '${exercise.targetSets}\u00d7${exercise.targetReps}'
            ' @${exercise.targetRpe.toStringAsFixed(1)}'
            ' ${exercise.restSeconds}s rest',
        style: const TextStyle(fontSize: 12, color: _slate500),
      ),
      if (exercise.isSupersetPair) ...[
        const TextSpan(text: '  '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _purple100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'SS',
              style: TextStyle(
                color: _purple600,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ];

    return Dismissible(
      key: ValueKey('exercise_$sessionIndex:$exerciseIndex'),
      direction: DismissDirection.endToStart,
      background: const ColoredBox(
        color: Color(0xFFEF4444),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      onDismissed: (_) => onRemoved(exerciseIndex),
      child: InkWell(
        onTap: () => onSwapRequested(exerciseIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading indicator: edit icon if modified, small dot otherwise
              SizedBox(
                width: 20,
                child: isEdited
                    ? const Icon(Icons.edit, size: 16, color: _blue600)
                    : Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(left: 7),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _slate500,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: subtitleParts)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Steppers
              Row(
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
            ],
          ),
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: _slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onDecrement,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.remove, size: 14, color: _slate500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _slate900,
              ),
            ),
          ),
          InkWell(
            onTap: onIncrement,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.add, size: 14, color: _slate500),
            ),
          ),
        ],
      ),
    );
  }
}
