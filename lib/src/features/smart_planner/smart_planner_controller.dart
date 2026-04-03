// lib/src/features/smart_planner/smart_planner_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/smart_planner/planner_registry_adapter.dart';
import 'package:training_engine/training_engine.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class SmartPlannerState {
  const SmartPlannerState({
    this.selectedDays = const [],
    this.goal = HypertrophyGoal.hypertrophy,
    this.maxDurationMinutes = 60,
    this.preferredExercises = const [],
    this.excludedExercises = const [],
    this.generatedPlan,
    this.wizardStep = 0,
    this.editedExerciseKeys = const {},
  });

  /// ISO weekday list (1 = Monday … 7 = Sunday). Values are 0-based if
  /// the planner convention uses 0 = Monday; the controller accepts whatever
  /// the caller uses – it just stores and forwards them to the engine.
  final List<int> selectedDays;

  final HypertrophyGoal goal;

  /// Maximum session duration in minutes.
  final int maxDurationMinutes;

  final List<String> preferredExercises;
  final List<String> excludedExercises;

  final WeeklyPlan? generatedPlan;

  /// Current step in the wizard (0-indexed).
  final int wizardStep;

  /// Keys of exercises that the user manually edited, encoded as
  /// "<sessionIndex>-<exerciseIndex>".
  final Set<String> editedExerciseKeys;

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  /// Returns the [SplitType] that would be chosen for the current selection,
  /// or null when no days are selected.
  SplitType? get detectedSplit {
    if (selectedDays.isEmpty) return null;
    return selectSplit(selectedDays);
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  SmartPlannerState copyWith({
    List<int>? selectedDays,
    HypertrophyGoal? goal,
    int? maxDurationMinutes,
    List<String>? preferredExercises,
    List<String>? excludedExercises,
    WeeklyPlan? generatedPlan,
    bool clearGeneratedPlan = false,
    int? wizardStep,
    Set<String>? editedExerciseKeys,
  }) {
    return SmartPlannerState(
      selectedDays: selectedDays ?? this.selectedDays,
      goal: goal ?? this.goal,
      maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      preferredExercises: preferredExercises ?? this.preferredExercises,
      excludedExercises: excludedExercises ?? this.excludedExercises,
      generatedPlan:
          clearGeneratedPlan ? null : generatedPlan ?? this.generatedPlan,
      wizardStep: wizardStep ?? this.wizardStep,
      editedExerciseKeys: editedExerciseKeys ?? this.editedExerciseKeys,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final smartPlannerControllerProvider =
    NotifierProvider<SmartPlannerController, SmartPlannerState>(
      SmartPlannerController.new,
    );

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class SmartPlannerController extends Notifier<SmartPlannerState> {
  @override
  SmartPlannerState build() => const SmartPlannerState();

  // ── Wizard config mutations ───────────────────────────────────────────────

  void toggleDay(int day) {
    final current = List<int>.from(state.selectedDays);
    if (current.contains(day)) {
      current.remove(day);
    } else {
      current.add(day);
    }
    state = state.copyWith(selectedDays: current);
  }

  void setGoal(HypertrophyGoal goal) {
    state = state.copyWith(goal: goal);
  }

  void setMaxDuration(int minutes) {
    state = state.copyWith(maxDurationMinutes: minutes);
  }

  void setPreferredExercises(List<String> ids) {
    state = state.copyWith(preferredExercises: ids);
  }

  void setExcludedExercises(List<String> ids) {
    state = state.copyWith(excludedExercises: ids);
  }

  void setWizardStep(int step) {
    state = state.copyWith(wizardStep: step);
  }

  // ── Plan generation ───────────────────────────────────────────────────────

  void generatePlan(List<Exercise> appExercises) {
    final registry = PlannerRegistryAdapter.buildRegistry(appExercises);

    final config = PlannerConfig(
      availableDays: state.selectedDays,
      maxSessionDuration: Duration(minutes: state.maxDurationMinutes),
      goal: state.goal,
      preferredExercises: state.preferredExercises,
      excludedExercises: state.excludedExercises,
    );

    final rawPlan = generateWeeklyPlan(config, registry);

    // Apply time-bounding per session
    final maxDuration = Duration(minutes: state.maxDurationMinutes);
    final boundedSessions = rawPlan.sessions.map((session) {
      final bounded = boundSessionToTime(session, maxDuration);
      return bounded.session;
    }).toList();

    final plan = WeeklyPlan(
      sessions: boundedSessions,
      splitType: rawPlan.splitType,
      weekStart: rawPlan.weekStart,
    );

    state = state.copyWith(
      generatedPlan: plan,
      editedExerciseKeys: {},
    );
  }

  // ── Inline editing ────────────────────────────────────────────────────────

  void updateExercise({
    required int sessionIndex,
    required int exerciseIndex,
    String? exerciseId,
    int? targetSets,
    int? targetReps,
    int? restSeconds,
  }) {
    final plan = state.generatedPlan;
    if (plan == null) return;
    if (sessionIndex >= plan.sessions.length) return;

    final session = plan.sessions[sessionIndex];
    if (exerciseIndex >= session.exercises.length) return;

    final original = session.exercises[exerciseIndex];
    final updated = original.copyWith(
      exerciseId: exerciseId,
      targetSets: targetSets,
      targetReps: targetReps,
      restSeconds: restSeconds,
    );

    final newExercises = List<PlannedExercise>.from(session.exercises);
    newExercises[exerciseIndex] = updated;

    final newDuration = estimateSessionDuration(newExercises);
    final newSession = session.copyWith(
      exercises: newExercises,
      estimatedDuration: newDuration,
    );

    final newSessions = List<PlannedSession>.from(plan.sessions);
    newSessions[sessionIndex] = newSession;

    final newPlan = WeeklyPlan(
      sessions: newSessions,
      splitType: plan.splitType,
      weekStart: plan.weekStart,
    );

    final key = '$sessionIndex-$exerciseIndex';
    state = state.copyWith(
      generatedPlan: newPlan,
      editedExerciseKeys: {...state.editedExerciseKeys, key},
    );
  }

  void removeExercise({
    required int sessionIndex,
    required int exerciseIndex,
  }) {
    final plan = state.generatedPlan;
    if (plan == null) return;
    if (sessionIndex >= plan.sessions.length) return;

    final session = plan.sessions[sessionIndex];
    if (exerciseIndex >= session.exercises.length) return;

    final newExercises = List<PlannedExercise>.from(session.exercises)
      ..removeAt(exerciseIndex);

    final newDuration = estimateSessionDuration(newExercises);
    final newSession = session.copyWith(
      exercises: newExercises,
      estimatedDuration: newDuration,
    );

    final newSessions = List<PlannedSession>.from(plan.sessions);
    newSessions[sessionIndex] = newSession;

    final newPlan = WeeklyPlan(
      sessions: newSessions,
      splitType: plan.splitType,
      weekStart: plan.weekStart,
    );

    state = state.copyWith(generatedPlan: newPlan);
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    state = const SmartPlannerState();
  }
}
