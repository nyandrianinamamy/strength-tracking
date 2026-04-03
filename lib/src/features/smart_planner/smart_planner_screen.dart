// lib/src/features/smart_planner/smart_planner_screen.dart
import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/features/smart_planner/planner_registry_adapter.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_controller.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/day_picker.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/goal_duration_step.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/plan_preview.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/preference_step.dart';

class SmartPlannerScreen extends ConsumerWidget {
  const SmartPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerState = ref.watch(smartPlannerControllerProvider);
    final notifier = ref.read(smartPlannerControllerProvider.notifier);
    final appState = ref.watch(appStateControllerProvider);
    final appStateController = ref.read(appStateControllerProvider.notifier);
    final exercises = appState.exercises;

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
              builder: (ctx) {
                if (alternatives.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No alternatives available.'),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final alt in alternatives)
                      ListTile(
                        title: Text(alt.name),
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
                );
              },
            );
          },
          onRegenerate: () => notifier.generatePlan(exercises),
          onAdopt: () {
            final l10n = AppLocalizations.of(context)!;
            notifier.adopt(appStateController, category: l10n.strength);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              notifier.reset();
              context.pop();
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Stepper(
        currentStep: currentStep,
        onStepTapped: (step) {
          // Only allow tapping completed steps
          if (step < currentStep) {
            notifier.setWizardStep(step);
          }
        },
        controlsBuilder: (context, details) {
          final isStepZero = currentStep == 0;
          final nextEnabled = !isStepZero || daysSelected;

          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                FilledButton(
                  onPressed: nextEnabled ? goNext : null,
                  child: Text(isLastStep ? 'Generate' : 'Next'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: goBack,
                  child: Text(currentStep == 0 ? 'Cancel' : 'Back'),
                ),
                if (isLastStep) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => notifier.generatePlan(exercises),
                    child: const Text('Skip'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Training Days'),
            isActive: currentStep >= 0,
            state: currentStep > 0 ? StepState.complete : StepState.indexed,
            content: DayPicker(
              selectedDays: plannerState.selectedDays,
              onDayToggled: notifier.toggleDay,
              splitLabel: plannerState.detectedSplit?.name,
            ),
          ),
          Step(
            title: const Text('Goal & Duration'),
            isActive: currentStep >= 1,
            state: currentStep > 1 ? StepState.complete : StepState.indexed,
            content: GoalDurationStep(
              goal: plannerState.goal,
              durationMinutes: plannerState.maxDurationMinutes,
              onGoalChanged: notifier.setGoal,
              onDurationChanged: notifier.setMaxDuration,
            ),
          ),
          Step(
            title: const Text('Preferences'),
            subtitle: const Text('Optional'),
            isActive: currentStep >= 2,
            state: StepState.indexed,
            content: PreferenceStep(
              exercises: exercises,
              preferredIds: plannerState.preferredExercises,
              excludedIds: plannerState.excludedExercises,
              onPreferredChanged: notifier.setPreferredExercises,
              onExcludedChanged: notifier.setExcludedExercises,
            ),
          ),
        ],
      ),
    );
  }
}
