import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
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
    final restDisplay = remainingRest > 0
        ? '00:${remainingRest.toString().padLeft(2, '0')}'
        : 'Ready';

    final sessionElapsed = DateTime.now().difference(session.startedAt);
    final upcoming = routine.exercises
        .skip(session.currentExerciseIndex + 1)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          IconButton(
            tooltip: 'Discard session',
            onPressed: () {
              controller.discardDraft();
              context.go('/');
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ],
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
          Card(
            color: const Color(0xFF111827),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set ${currentSets.length + 1} of ${currentPrescription.targetSets}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF8FB9FF),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentExercise?.name ?? 'Exercise',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${currentPrescription.targetSets} sets • ${currentPrescription.targetReps} reps • ${currentPrescription.restSeconds}s rest',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderValue(
                          label: 'Elapsed',
                          value: AppFormatters.duration(sessionElapsed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeaderValue(
                          label: 'Rest Timer',
                          value: restDisplay,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _setNoteController,
            decoration: const InputDecoration(
              labelText: 'Set Note',
              hintText: 'Optional cue or RPE note for this set',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
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
            label: const Text('Log Set'),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _sessionNoteController,
            maxLines: 3,
            onChanged: controller.updateSessionNote,
            decoration: const InputDecoration(
              labelText: 'Session Notes',
              hintText: 'How does the workout feel overall?',
            ),
          ),
          const SizedBox(height: 24),
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            '${AppFormatters.decimal(set.weightKg)} kg x ${set.reps}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            AppFormatters.weekdayMonthDay(set.completedAt),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          PageSection(
            title: 'Up Next',
            child: upcoming.isEmpty
                ? const EmptyStateCard(
                    title: 'Final movement',
                    body:
                        'Finish the remaining sets here, then complete the workout summary.',
                  )
                : Column(
                    children: upcoming.map((item) {
                      final exercise = state.exerciseById(item.exerciseId);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            exercise?.name ?? 'Exercise',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${item.targetSets} sets • ${item.targetReps} reps • ${item.restSeconds}s rest',
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

class _HeaderValue extends StatelessWidget {
  const _HeaderValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
