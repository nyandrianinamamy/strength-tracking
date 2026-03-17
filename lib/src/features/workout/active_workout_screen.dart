import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _setNoteController = TextEditingController();
  final _sessionNoteController = TextEditingController();
  late final Timer _ticker;
  String? _lastExerciseId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _weightController.dispose();
    _repsController.dispose();
    _setNoteController.dispose();
    _sessionNoteController.dispose();
    super.dispose();
  }

  void _showCommentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Comment'),
          content: TextField(
            controller: _setNoteController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Optional cue or RPE note for this set',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateControllerProvider);
    final session = state.activeSession;
    final controller = ref.read(workoutControllerProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Workout')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyStateCard(
                title: 'No active session',
                body:
                    'Start a routine from the dashboard or library to begin logging sets.',
              ),
            ),
          ),
        ),
      );
    }

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentPrescription =
        routine.exercises[session.currentExerciseIndex.clamp(
          0,
          routine.exercises.length - 1,
        )];
    final currentExercise = state.exerciseById(currentPrescription.exerciseId);
    final currentSets = session.completedSets
        .where((set) => set.exerciseId == currentPrescription.exerciseId)
        .toList();
    final previousPerformance =
        state.completedSessions
            .where((item) => item.id != session.id)
            .expand((item) => item.completedSets)
            .where((set) => set.exerciseId == currentPrescription.exerciseId)
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    if (_lastExerciseId != currentPrescription.exerciseId) {
      _lastExerciseId = currentPrescription.exerciseId;
      final lastSet = currentSets.isNotEmpty
          ? currentSets.last
          : previousPerformance.isNotEmpty
          ? previousPerformance.first
          : null;
      _weightController.text = lastSet == null
          ? ''
          : AppFormatters.decimal(lastSet.weightKg);
      _repsController.text =
          lastSet?.reps.toString() ?? '${currentPrescription.targetReps}';
      _setNoteController.clear();
    }

    if (_sessionNoteController.text != session.sessionNote) {
      _sessionNoteController.text = session.sessionNote;
      _sessionNoteController.selection = TextSelection.fromPosition(
        TextPosition(offset: _sessionNoteController.text.length),
      );
    }

    final lastSetForExercise = currentSets.isNotEmpty ? currentSets.last : null;
    final remainingRest = lastSetForExercise == null
        ? 0
        : currentPrescription.restSeconds -
              DateTime.now()
                  .difference(lastSetForExercise.completedAt)
                  .inSeconds;

    // Find the highest weight in previous performance for PB badge
    final highestPrevWeight = previousPerformance.isEmpty
        ? 0.0
        : previousPerformance
              .map((s) => s.weightKg)
              .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Discard session',
          onPressed: () {
            controller.discardDraft();
            context.go('/');
          },
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          currentExercise?.name ?? 'Exercise',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    session.currentExerciseIndex < routine.exercises.length - 1
                    ? () => controller.skipExercise()
                    : null,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Skip'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final completed = controller.completeSession();
                  if (completed != null) {
                    context.go('/workout/${completed.id}/summary');
                  }
                },
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Finish'),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // Set badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'SET ${currentSets.length + 1} OF ${currentPrescription.targetSets}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Rest timer
          Center(
            child: DigitalTimer(
              remaining: Duration(
                seconds: remainingRest.clamp(0, 999),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3-column input grid: weight, reps, log button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'WEIGHT (KG)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slateInactive,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _weightController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'REPS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slateInactive,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _repsController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      final weight = double.tryParse(
                        _weightController.text.replaceAll(',', '.'),
                      );
                      final reps = int.tryParse(_repsController.text);
                      if (weight == null || reps == null || reps <= 0) {
                        return;
                      }

                      controller.logSet(
                        weightKg: weight,
                        reps: reps,
                        note: _setNoteController.text.trim(),
                      );
                      _setNoteController.clear();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('LOG'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Add comment button (dashed style)
          GestureDetector(
            onTap: () => _showCommentDialog(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: _setNoteController.text.trim().isNotEmpty
                        ? AppTheme.primary
                        : AppTheme.slateInactive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _setNoteController.text.trim().isNotEmpty
                        ? 'COMMENT ADDED'
                        : 'ADD COMMENT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _setNoteController.text.trim().isNotEmpty
                              ? AppTheme.primary
                              : AppTheme.slateInactive,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Current session sets
          PageSection(
            title: 'Current Session Sets',
            child: currentSets.isEmpty
                ? const EmptyStateCard(
                    title: 'Nothing logged yet',
                    body:
                        'Your sets for the current exercise will appear here.',
                  )
                : Column(
                    children: currentSets.map((set) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            'Set ${set.setNumber}: ${AppFormatters.decimal(set.weightKg)} kg x ${set.reps}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(AppFormatters.time(set.completedAt)),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Previous performance with PB badges
          PageSection(
            title: 'Previous Performance',
            child: previousPerformance.isEmpty
                ? const EmptyStateCard(
                    title: 'No history for this movement yet',
                    body:
                        'Once you repeat the exercise, prior sets will show here.',
                  )
                : Column(
                    children: previousPerformance.take(4).map((set) {
                      final isPb = set.weightKg == highestPrevWeight &&
                          highestPrevWeight > 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                '${AppFormatters.decimal(set.weightKg)} kg x ${set.reps}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              if (isPb) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'PB',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            AppFormatters.weekdayMonthDay(set.completedAt),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
