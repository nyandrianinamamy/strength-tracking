import 'acwr/acwr_classifier.dart' as acwr_lib;
import 'acwr/ewma.dart' as ewma_lib;
import 'e1rm/composite_estimator.dart' as e1rm_lib;
import 'e1rm/formulas.dart' as formula_lib;
import 'e1rm/strength_baseline.dart' as baseline_lib;
import 'fatigue/decay.dart' as fatigue_lib;
import 'fatigue/impulse_calculator.dart' as impulse_lib;
import 'models/daily_load.dart';
import 'models/e1rm_estimate.dart';
import 'models/engine_session.dart';
import 'models/enums.dart';
import 'models/fatigue_impulse.dart';
import 'models/hrv_record.dart';
import 'models/logged_set.dart';
import 'models/sleep_record.dart';
import 'models/training_state.dart';
import 'models/user_profile.dart';
import 'planner/fatigue_substitution.dart' as sub_lib;
import 'planner/missed_session.dart' as missed_lib;
import 'planner/session_generator.dart';
import 'progression/performance_delta.dart';
import 'progression/recommendation.dart' as rec_lib;
import 'readiness/composite_readiness.dart' as readiness_lib;
import 'readiness/hrv_scorer.dart' as hrv_lib;
import 'readiness/sleep_scorer.dart' as sleep_lib;
import 'registry/exercise_registry.dart';

/// Single entry-point that wires all training subsystems together.
///
/// The engine holds a [TrainingState] which accumulates data across
/// ingested sessions, sleep records, and HRV records. It exposes a
/// clean API for querying current status and generating plans.
class TrainingEngine {
  final ExerciseRegistry registry;
  TrainingState _state;

  TrainingEngine({required this.registry, required UserProfile profile})
      : _state = TrainingState.initial(profile);

  // ---------------------------------------------------------------------------
  // Ingestion
  // ---------------------------------------------------------------------------

  /// Ingests a completed [session], updating e1RM estimates, fatigue log,
  /// ACWR EWMA, and the lastTopSets map.
  void ingestSession(EngineSession session) {
    // Group sets by exerciseId
    final setsByExercise = <String, List<LoggedSet>>{};
    for (final set in session.sets) {
      setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    final newE1rmHistory =
        Map<String, List<E1rmEstimate>>.from(_state.e1rmHistory);
    final newFatigueLog =
        Map<String, List<FatigueImpulse>>.from(_state.fatigueLog);
    final newLastTopSets = Map<String, LoggedSet>.from(_state.lastTopSets);

    for (final entry in setsByExercise.entries) {
      final exerciseId = entry.key;
      final sets = entry.value;

      // Find the heaviest set (by weight, then reps as tiebreaker)
      final topSet = sets.reduce((a, b) {
        if (a.weightKg != b.weightKg) return a.weightKg > b.weightKg ? a : b;
        return a.reps >= b.reps ? a : b;
      });

      // Update lastTopSets
      newLastTopSets[exerciseId] = topSet;

      // Compute composite e1RM for the heaviest set
      final rm = formula_lib.rMax(topSet.reps, topSet.rpe);
      final e1rmValue = e1rm_lib.compositeE1rm(
        weight: topSet.weightKg,
        reps: topSet.reps,
        rpe: topSet.rpe,
      );
      final confidence = e1rm_lib.estimateConfidence(rm);

      final estimate = E1rmEstimate(
        exerciseId: exerciseId,
        value: e1rmValue,
        rMax: rm,
        confidence: confidence,
        estimatedAt: session.endedAt,
        fromEstimatedRpe: topSet.rpeEstimated,
      );

      final history = List<E1rmEstimate>.from(
        newE1rmHistory[exerciseId] ?? [],
      )..add(estimate);
      // Trim to most recent 20 estimates
      newE1rmHistory[exerciseId] = history.length > 20
          ? history.sublist(history.length - 20)
          : history;

      // Look up exercise for fatigue impulse calculation
      final exercise = registry.lookup(exerciseId);
      if (exercise != null) {
        final impulses = impulse_lib.calculateImpulses(
          sets: sets,
          exercise: exercise,
          e1rm: e1rmValue,
          sessionEndedAt: session.endedAt,
        );
        for (final impulse in impulses) {
          final muscleLog = List<FatigueImpulse>.from(
            newFatigueLog[impulse.muscleId] ?? [],
          )..add(impulse);
          newFatigueLog[impulse.muscleId] = muscleLog;
        }
      }
    }

    // Prune old fatigue impulses (>7 days)
    final now = session.endedAt;
    for (final muscleId in newFatigueLog.keys.toList()) {
      newFatigueLog[muscleId] =
          fatigue_lib.pruneOldImpulses(newFatigueLog[muscleId]!, now);
    }

    // Compute daily volume load (sum of weight * reps across all sets)
    double volumeLoad = 0.0;
    for (final set in session.sets) {
      volumeLoad += set.weightKg * set.reps;
    }

    // Trim and update daily loads (keep 35 days)
    final newDailyLoad = DailyLoad(date: session.endedAt, volumeLoad: volumeLoad);
    final dailyLoads = List<DailyLoad>.from(_state.dailyLoads)..add(newDailyLoad);
    final cutoff = now.subtract(const Duration(days: 35));
    final trimmedDailyLoads =
        dailyLoads.where((d) => !d.date.isBefore(cutoff)).toList();

    // Update EWMA
    final newAcwrState = ewma_lib.updateEwma(
      previous: _state.acwrState,
      todayLoad: volumeLoad,
      today: session.endedAt,
    );

    _state = _state.copyWith(
      e1rmHistory: newE1rmHistory,
      fatigueLog: newFatigueLog,
      dailyLoads: trimmedDailyLoads,
      acwrState: newAcwrState,
      lastTopSets: newLastTopSets,
      lastUpdated: DateTime.now(),
      sessionsIngested: _state.sessionsIngested + 1,
    );
  }

  /// Appends a [SleepRecord] to the sleep history (trims to 14 days).
  void ingestSleep(SleepRecord record) {
    final history = List<SleepRecord>.from(_state.sleepHistory)..add(record);
    final cutoff = record.date.subtract(const Duration(days: 14));
    final trimmed = history.where((r) => !r.date.isBefore(cutoff)).toList();
    _state = _state.copyWith(
      sleepHistory: trimmed,
      lastUpdated: DateTime.now(),
    );
  }

  /// Appends an [HrvRecord] to the HRV history (trims to 14 days).
  void ingestHrv(HrvRecord record) {
    final history = List<HrvRecord>.from(_state.hrvHistory)..add(record);
    final cutoff = record.date.subtract(const Duration(days: 14));
    final trimmed = history.where((r) => !r.date.isBefore(cutoff)).toList();
    _state = _state.copyWith(
      hrvHistory: trimmed,
      lastUpdated: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns the rolling e1RM for [exerciseId], or the baseline estimate if
  /// no history is available.
  ///
  /// Never returns null — falls back to demographic-based baseline.
  double? currentE1rm(String exerciseId, [DateTime? at]) {
    final now = at ?? DateTime.now();
    final history = _state.e1rmHistory[exerciseId];
    if (history != null && history.isNotEmpty) {
      return e1rm_lib.rollingE1rm(history, now);
    }
    // Fallback to baseline estimate
    final category = baseline_lib.categorizeExercise(exerciseId);
    return baseline_lib.estimateBaselineE1rm(
      category: category,
      sex: _state.profile.sex,
      experience: _state.profile.experience,
      bodyWeightKg: _state.profile.bodyWeightKg,
    );
  }

  /// Returns the current decayed fatigue level (0–100) for [muscleId].
  double currentFatigue(String muscleId, [DateTime? at]) {
    final now = at ?? DateTime.now();
    final impulses = _state.fatigueLog[muscleId] ?? [];
    return fatigue_lib.currentFatigue(
      muscleId,
      impulses,
      now,
      age: _state.profile.age,
    );
  }

  /// Returns a [FatigueStatus] map for every muscle present in the log.
  Map<String, fatigue_lib.FatigueStatus> fullFatigueMap([DateTime? at]) {
    final now = at ?? DateTime.now();
    return fatigue_lib.fullFatigueMap(
      _state.fatigueLog,
      now,
      age: _state.profile.age,
    );
  }

  /// Returns the current ACWR status, or `null` if not enough data.
  acwr_lib.AcwrStatus? currentAcwr() {
    if (_state.acwrState == null) return null;
    return acwr_lib.computeAcwr(_state.acwrState!);
  }

  /// Computes a composite readiness score from all available data sources.
  readiness_lib.ReadinessScore computeReadiness({double? manualSlider}) {
    final now = DateTime.now();
    final acwr = currentAcwr();
    final sleepScore = sleep_lib.scoreSleep(_state.sleepHistory, now);
    final hrvScore = hrv_lib.scoreHrv(_state.hrvHistory, now);
    return readiness_lib.computeReadiness(
      acwr: acwr,
      sleepScore: sleepScore,
      hrvScore: hrvScore,
      manualSlider: manualSlider,
    );
  }

  /// Builds a [LoadRecommendation] for [exerciseId].
  ///
  /// Uses [overrides] to supply custom target params, and [at] for time-based
  /// queries (defaults to now).
  rec_lib.LoadRecommendation recommendLoad(
    String exerciseId, {
    TargetParams? overrides,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();

    // Look up exercise
    final exercise = registry.lookup(exerciseId);
    final equipment = exercise?.equipment ?? EquipmentClass.barbell;

    // Default target params from movement class
    final targets = overrides ??
        (exercise != null
            ? TargetParams.defaultFor(exercise.movement)
            : const TargetParams(
                targetRepsLow: 8,
                targetRepsHigh: 12,
                targetRpe: 8.0,
              ));

    // Current e1RM
    final e1rm = currentE1rm(exerciseId, now);

    // Primary muscle fatigue
    double primaryFatigue = 0.0;
    if (exercise != null) {
      final primaryMuscle = exercise.muscleMap
          .where((m) => m.role == MuscleRole.primary)
          .map((m) => m.muscleId)
          .firstOrNull;
      if (primaryMuscle != null) {
        primaryFatigue = currentFatigue(primaryMuscle, now);
      }
    }

    // ACWR zone
    final acwrZone = currentAcwr()?.zone;

    // Readiness score
    final readiness = computeReadiness();

    // Last top set
    final lastTopSet = _state.lastTopSets[exerciseId];

    // Previous weight
    final previousWeightKg = lastTopSet?.weightKg;

    return rec_lib.buildRecommendation(
      exerciseId: exerciseId,
      equipment: equipment,
      targets: targets,
      e1rm: e1rm,
      previousWeightKg: previousWeightKg,
      lastTopSet: lastTopSet,
      primaryMuscleFatigue: primaryFatigue,
      acwrZone: acwrZone,
      readinessScore: readiness.score,
    );
  }

  // ---------------------------------------------------------------------------
  // Planner
  // ---------------------------------------------------------------------------

  /// Generates a [WeeklyPlan] using the provided [config].
  WeeklyPlan generatePlan(PlannerConfig config) {
    return generateWeeklyPlan(config, registry);
  }

  /// Returns a new plan with missed volume redistributed to remaining sessions.
  WeeklyPlan handleMissedSession(WeeklyPlan plan, int missedDay, DateTime now) {
    return missed_lib.handleMissedSession(plan, missedDay, now);
  }

  /// Adjusts a session by substituting exercises whose secondary muscles are fatigued.
  sub_lib.SubstitutionResult adjustSessionForFatigue(
    PlannedSession session,
    DateTime? at,
  ) {
    final now = at ?? DateTime.now();
    final fatigueMap = <String, double>{};
    for (final entry in _state.fatigueLog.entries) {
      fatigueMap[entry.key] = fatigue_lib.currentFatigue(
        entry.key, entry.value, now, age: _state.profile.age);
    }
    return sub_lib.adjustSessionForFatigue(session, fatigueMap, registry);
  }

  // ---------------------------------------------------------------------------
  // State management
  // ---------------------------------------------------------------------------

  /// Returns the current engine state snapshot.
  TrainingState get state => _state;

  /// Serializes the current state to JSON.
  Map<String, dynamic> serializeState() => _state.toJson();

  /// Restores engine state from a previously serialized JSON snapshot.
  ///
  /// Applies a one-time migration of stale muscle IDs in the fatigue log
  /// to match the canonical vocabulary used by the planner and registry.
  TrainingState restoreState(Map<String, dynamic> json) {
    _state = TrainingState.fromJson(json);
    _migrateStaleMuscleIds();
    return _state;
  }

  static const _muscleIdMigration = <String, String>{
    'back': 'lats',
    'quad': 'quadriceps',
    'glute': 'glutes',
    'hamstring': 'hamstrings',
    'calf': 'calves',
    'rear_delt': 'rear_deltoid',
    'shoulder': 'anterior_deltoid',
  };

  void _migrateStaleMuscleIds() {
    final log = _state.fatigueLog;
    final migrated = <String, List<FatigueImpulse>>{};
    var changed = false;
    for (final entry in log.entries) {
      final newKey = _muscleIdMigration[entry.key];
      if (newKey != null) {
        changed = true;
        migrated[newKey] = [
          ...migrated[newKey] ?? [],
          ...entry.value,
        ];
      } else {
        migrated[entry.key] = [
          ...migrated[entry.key] ?? [],
          ...entry.value,
        ];
      }
    }
    if (changed) {
      _state = _state.copyWith(fatigueLog: migrated);
    }
  }

  /// Ingests a list of legacy sessions in chronological order.
  ///
  /// Sets with [LoggedSet.rpeEstimated] == true have their RPE backfilled from
  /// [EngineSession.sessionRpe] (or defaulted to 8.0).
  void bootstrapFromHistory(List<EngineSession> legacySessions) {
    final sorted = List<EngineSession>.from(legacySessions)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    for (final session in sorted) {
      final fallbackRpe = (session.sessionRpe ?? 8.0).clamp(5.0, 10.0);

      final backfilledSets = session.sets.map((set) {
        if (set.rpeEstimated) {
          return LoggedSet(
            exerciseId: set.exerciseId,
            weightKg: set.weightKg,
            reps: set.reps,
            rpe: fallbackRpe,
            completedAt: set.completedAt,
            rpeEstimated: true,
          );
        }
        return set;
      }).toList();

      final patched = EngineSession(
        id: session.id,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        sets: backfilledSets,
        sessionRpe: session.sessionRpe,
      );
      ingestSession(patched);
    }
  }
}
