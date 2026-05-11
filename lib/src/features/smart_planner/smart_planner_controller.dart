// lib/src/features/smart_planner/smart_planner_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine_group.dart';
import 'package:strength_training_tracker/src/features/smart_planner/planner_registry_adapter.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:training_engine/training_engine.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class SmartPlannerState {
  const SmartPlannerState({
    this.selectedDays = const {},
    this.goal = HypertrophyGoal.hypertrophy,
    this.maxDurationMinutes = 60,
    this.preferredExercises = const [],
    this.excludedExercises = const [],
    this.generatedPlan,
    this.wizardStep = 0,
    this.editedExerciseKeys = const {},
  });

  /// Selected training days. Values follow the engine convention
  /// (0 = Sunday, 1 = Monday, etc.).
  final Set<int> selectedDays;

  final HypertrophyGoal goal;

  /// Maximum session duration in minutes.
  final int maxDurationMinutes;

  final List<String> preferredExercises;
  final List<String> excludedExercises;

  final WeeklyPlan? generatedPlan;

  /// Current step in the wizard (0-indexed).
  final int wizardStep;

  /// Keys of exercises that the user manually edited, encoded as
  /// `<sessionIndex>:<exerciseIndex>`.
  final Set<String> editedExerciseKeys;

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  /// Returns the [SplitType] that would be chosen for the current selection,
  /// or null when no days are selected.
  SplitType? get detectedSplit {
    if (selectedDays.isEmpty) return null;
    return selectSplit(selectedDays.toList());
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  SmartPlannerState copyWith({
    Set<int>? selectedDays,
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
      generatedPlan: clearGeneratedPlan
          ? null
          : generatedPlan ?? this.generatedPlan,
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
    final days = Set<int>.from(state.selectedDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    state = state.copyWith(selectedDays: days);
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

  Future<void> generatePlan(List<Exercise> appExercises) async {
    final registry = PlannerRegistryAdapter.buildRegistry(appExercises);
    final engineContext = await _readPlannerEngineContext();

    final config = PlannerConfig(
      availableDays: state.selectedDays.toList(),
      maxSessionDuration: Duration(minutes: state.maxDurationMinutes),
      goal: state.goal,
      preferredExercises: state.preferredExercises,
      excludedExercises: state.excludedExercises,
      engineContext: engineContext,
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
      engineContextApplied: rawPlan.engineContextApplied,
    );

    state = state.copyWith(generatedPlan: plan, editedExerciseKeys: {});
  }

  Future<PlannerEngineContext?> _readPlannerEngineContext() async {
    final engine = await ref.read(trainingEngineProvider.future);
    return PlannerRegistryAdapter.buildEngineContext(engine);
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

    final key = '$sessionIndex:$exerciseIndex';
    state = state.copyWith(
      generatedPlan: newPlan,
      editedExerciseKeys: {...state.editedExerciseKeys, key},
    );
  }

  void removeExercise({required int sessionIndex, required int exerciseIndex}) {
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

  // ── Adoption ──────────────────────────────────────────────────────────────

  void adopt(AppStateController appStateController) {
    final plan = state.generatedPlan;
    if (plan == null) return;

    const uuid = Uuid();

    // Map from SplitType to human-readable label (for group name only)
    final splitLabel = switch (plan.splitType) {
      SplitType.fullBody => 'Full Body',
      SplitType.upperLower => 'Upper/Lower',
      SplitType.pushPullLegs => 'Push/Pull/Legs',
    };

    // Day name abbreviations (0 = Sun, 1 = Mon, …, 6 = Sat)
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    // Focus name for routine name
    String focusLabel(SessionFocus focus) => switch (focus) {
      SessionFocus.fullBody => 'Full Body',
      SessionFocus.push => 'Push',
      SessionFocus.pull => 'Pull',
      SessionFocus.legs => 'Legs',
      SessionFocus.upper => 'Upper',
      SessionFocus.lower => 'Lower',
    };

    // Collect all exercise IDs used in the plan
    final usedExerciseIds = <String>{};
    for (final session in plan.sessions) {
      for (final ex in session.exercises) {
        usedExerciseIds.add(ex.exerciseId);
      }
    }

    // Find exercise IDs that don't exist in AppState and create Exercise
    // records from the engine registry so downstream screens can resolve them.
    final currentState = appStateController.state;
    final existingIds = currentState.exercises.map((e) => e.id).toSet();
    final missingIds = usedExerciseIds.difference(existingIds);
    final newExercises = <Exercise>[];

    if (missingIds.isNotEmpty) {
      final registry = PlannerRegistryAdapter.buildRegistry(
        currentState.exercises,
      );
      for (final id in missingIds) {
        final engineEx = registry.lookup(id);
        if (engineEx == null) continue;

        final primaryMuscles = engineEx.muscleMap
            .where((m) => m.role == MuscleRole.primary)
            .map((m) => m.muscleId)
            .toList();
        final secondaryMuscles = engineEx.muscleMap
            .where((m) => m.role != MuscleRole.primary)
            .map((m) => m.muscleId)
            .toList();

        newExercises.add(
          Exercise(
            id: engineEx.id,
            name: engineEx.name,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            equipment: [engineEx.equipment.name],
            instructions: '',
            archived: false,
          ),
        );
      }
    }

    // Build Routines from PlannedSessions
    final routines = plan.sessions.map((session) {
      final id = uuid.v4();
      final dayName = dayNames[session.dayOfWeek % 7];
      final name = '${focusLabel(session.focus)} — $dayName';

      final exercises = [
        for (int i = 0; i < session.exercises.length; i++)
          RoutineExercise(
            exerciseId: session.exercises[i].exerciseId,
            targetSets: session.exercises[i].targetSets,
            targetReps: session.exercises[i].targetReps,
            restSeconds: session.exercises[i].restSeconds,
            order: i,
            plannerMetadata: _plannerMetadataFor(session.exercises[i]),
          ),
      ];

      return Routine(
        id: id,
        name: name,
        category: 'strength',
        exercises: exercises,
        estimatedDurationMin: session.estimatedDuration.inMinutes,
        archived: false,
      );
    }).toList();

    // Build RoutineGroup
    final routineIds = routines.map((r) => r.id).toList();
    final weekStart = plan.weekStart;
    final groupName =
        '$splitLabel — Week of ${_monthName(weekStart.month)} ${weekStart.day}';

    final group = RoutineGroup(
      id: uuid.v4(),
      name: groupName,
      routineIds: routineIds,
      pendingRoutineIds: routineIds,
    );

    // Persist via AppStateController
    appStateController.updateState((current) {
      return current.copyWith(
        exercises: [...current.exercises, ...newExercises],
        routines: [...current.routines, ...routines],
        routineGroups: [...current.routineGroups, group],
        activeRoutineGroupId: group.id,
      );
    });
  }

  Map<String, dynamic> _plannerMetadataFor(PlannedExercise exercise) {
    return {
      'source': 'smart_planner',
      'engineContextApplied': exercise.engineContextApplied,
      'fatiguedMuscles': exercise.fatiguedMuscles,
      'adaptationReasons': exercise.adaptationReasons,
      if (exercise.engineReadinessScore != null)
        'readinessScore': exercise.engineReadinessScore,
      'sessionsIngested': exercise.engineSessionsIngested,
    };
  }

  static String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    state = const SmartPlannerState();
  }
}
