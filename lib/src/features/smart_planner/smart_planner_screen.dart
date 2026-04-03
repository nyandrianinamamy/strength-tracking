// lib/src/features/smart_planner/smart_planner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/smart_planner/planner_registry_adapter.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_controller.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/day_picker.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/goal_duration_step.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/plan_preview.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/preference_step.dart';
import 'package:training_engine/training_engine.dart';

// Design constants
const _blue600 = Color(0xFF2563EB);
const _slate900 = Color(0xFF0F172A);
const _slate500 = Color(0xFF64748B);
const _slate200 = Color(0xFFE2E8F0);

class SmartPlannerScreen extends ConsumerWidget {
  const SmartPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerState = ref.watch(smartPlannerControllerProvider);
    final notifier = ref.read(smartPlannerControllerProvider.notifier);
    final appState = ref.watch(appStateControllerProvider);
    final appStateController = ref.read(appStateControllerProvider.notifier);
    final List<Exercise> exercises = appState.exercises;

    // ── Preview mode ─────────────────────────────────────────────────────────

    if (plannerState.generatedPlan != null) {
      final plan = plannerState.generatedPlan!;
      final registry = PlannerRegistryAdapter.buildRegistry(exercises);

      String exerciseNameResolver(String id) {
        final byApp = appState.exerciseById(id)?.name;
        if (byApp != null) return byApp;
        final byRegistry = registry.lookup(id)?.name;
        if (byRegistry != null) return byRegistry;
        return id;
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Plan'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => notifier.reset(),
          ),
        ),
        body: PlanPreview(
          plan: plan,
          editedKeys: plannerState.editedExerciseKeys,
          exerciseNameResolver: exerciseNameResolver,
          onExerciseUpdated: ({
            required int sessionIndex,
            required int exerciseIndex,
            required int? sets,
            required int? reps,
          }) {
            notifier.updateExercise(
              sessionIndex: sessionIndex,
              exerciseIndex: exerciseIndex,
              targetSets: sets,
              targetReps: reps,
            );
          },
          onExerciseRemoved: ({
            required int sessionIndex,
            required int exerciseIndex,
          }) {
            notifier.removeExercise(
              sessionIndex: sessionIndex,
              exerciseIndex: exerciseIndex,
            );
          },
          onExerciseSwapRequested: ({
            required int sessionIndex,
            required int exerciseIndex,
          }) {
            final session = plan.sessions[sessionIndex];
            final exerciseId = session.exercises[exerciseIndex].exerciseId;
            final alternatives = registry.substitutesFor(exerciseId);

            showModalBottomSheet<void>(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              builder: (ctx) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _slate200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Swap Exercise',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _slate900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (alternatives.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No alternatives available.'),
                      )
                    else
                      ListView(
                        shrinkWrap: true,
                        children: [
                          for (final alt in alternatives)
                            ListTile(
                              title: Text(
                                alt.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _slate900,
                                ),
                              ),
                              subtitle: Text(
                                alt.equipment.name,
                                style: const TextStyle(color: _slate500),
                              ),
                              onTap: () {
                                notifier.updateExercise(
                                  sessionIndex: sessionIndex,
                                  exerciseIndex: exerciseIndex,
                                  exerciseId: alt.id,
                                );
                                Navigator.of(ctx).pop();
                              },
                            ),
                        ],
                      ),
                    SafeArea(child: const SizedBox(height: 8)),
                  ],
                );
              },
            );
          },
          onRegenerate: () => notifier.generatePlan(exercises),
          onAdopt: () {
            notifier.adopt(appStateController);
            notifier.reset();
            context.go('/routines');
          },
        ),
      );
    }

    // ── Wizard mode ───────────────────────────────────────────────────────────

    final currentStep = plannerState.wizardStep;
    final daysSelected = plannerState.selectedDays.isNotEmpty;
    final isLastStep = currentStep == 2;

    void goNext() {
      if (isLastStep) {
        notifier.generatePlan(exercises);
      } else {
        notifier.setWizardStep(currentStep + 1);
      }
    }

    void goBack() {
      if (currentStep == 0) {
        notifier.reset();
        context.pop();
      } else {
        notifier.setWizardStep(currentStep - 1);
      }
    }

    final nextEnabled = currentStep != 0 || daysSelected;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text(
          'Smart Planner',
          style: TextStyle(
            color: _slate900,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: _slate500),
            onPressed: () {
              notifier.reset();
              context.pop();
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // ── Custom stepper indicator ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: _StepperIndicator(currentStep: currentStep),
          ),

          // ── Step content ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: _buildStepContent(
                context,
                currentStep,
                plannerState,
                notifier,
                exercises,
              ),
            ),
          ),

          // ── Bottom controls ─────────────────────────────────────────────
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: _slate200),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: goBack,
                    child: Text(
                      currentStep == 0 ? 'Cancel' : 'Back',
                      style: const TextStyle(color: _slate500),
                    ),
                  ),
                  const Spacer(),
                  if (isLastStep) ...[
                    TextButton(
                      onPressed: () => notifier.generatePlan(exercises),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: _slate500),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton(
                    onPressed: nextEnabled ? goNext : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue600,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      isLastStep ? 'Generate' : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    int currentStep,
    SmartPlannerState plannerState,
    SmartPlannerController notifier,
    List<Exercise> exercises,
  ) {
    switch (currentStep) {
      case 0:
        return _Step1Content(
          plannerState: plannerState,
          notifier: notifier,
        );
      case 1:
        return _Step2Content(
          plannerState: plannerState,
          notifier: notifier,
        );
      case 2:
        return _Step3Content(
          exercises: exercises,
          plannerState: plannerState,
          notifier: notifier,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Custom stepper indicator
// ---------------------------------------------------------------------------

class _StepperIndicator extends StatelessWidget {
  const _StepperIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          _StepCircle(
            index: i,
            isActive: i == currentStep,
            isCompleted: i < currentStep,
          ),
          if (i < 2)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentStep ? _blue600 : _slate200,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.index,
    required this.isActive,
    required this.isCompleted,
  });

  final int index;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final isFilled = isActive || isCompleted;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? _blue600 : Colors.white,
        border: Border.all(
          color: isFilled ? _blue600 : _slate200,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : _slate500,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Training Days
// ---------------------------------------------------------------------------

String _splitTypeLabel(SplitType split) => switch (split) {
  SplitType.fullBody => 'Full Body',
  SplitType.upperLower => 'Upper/Lower',
  SplitType.pushPullLegs => 'Push/Pull/Legs',
};

class _Step1Content extends StatelessWidget {
  const _Step1Content({required this.plannerState, required this.notifier});

  final SmartPlannerState plannerState;
  final SmartPlannerController notifier;

  @override
  Widget build(BuildContext context) {
    final selectedDays = plannerState.selectedDays;
    final rawSplit = plannerState.detectedSplit;
    final splitLabel = rawSplit != null ? _splitTypeLabel(rawSplit) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Training Days',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Which days can you commit to working out?',
          style: TextStyle(fontSize: 14, color: _slate500),
        ),
        const SizedBox(height: 20),
        DayPicker(
          selectedDays: selectedDays,
          onDayToggled: notifier.toggleDay,
          splitLabel: null, // We render it ourselves below
        ),
        if (splitLabel != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Split',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  splitLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _blue600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${selectedDays.length} days selected',
                  style: const TextStyle(fontSize: 13, color: _slate500),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Goal & Duration
// ---------------------------------------------------------------------------

class _Step2Content extends StatelessWidget {
  const _Step2Content({required this.plannerState, required this.notifier});

  final SmartPlannerState plannerState;
  final SmartPlannerController notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Goal & Duration',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'What are you training for and how long can you work out?',
          style: TextStyle(fontSize: 14, color: _slate500),
        ),
        const SizedBox(height: 24),
        GoalDurationStep(
          goal: plannerState.goal,
          durationMinutes: plannerState.maxDurationMinutes,
          onGoalChanged: notifier.setGoal,
          onDurationChanged: notifier.setMaxDuration,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Preferences
// ---------------------------------------------------------------------------

class _Step3Content extends StatelessWidget {
  const _Step3Content({
    required this.exercises,
    required this.plannerState,
    required this.notifier,
  });

  final List<Exercise> exercises;
  final SmartPlannerState plannerState;
  final SmartPlannerController notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferences',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Optional — customise which exercises appear in your plan.',
          style: TextStyle(fontSize: 14, color: _slate500),
        ),
        const SizedBox(height: 24),
        PreferenceStep(
          exercises: exercises,
          preferredIds: plannerState.preferredExercises,
          excludedIds: plannerState.excludedExercises,
          onPreferredChanged: notifier.setPreferredExercises,
          onExcludedChanged: notifier.setExcludedExercises,
        ),
      ],
    );
  }
}
