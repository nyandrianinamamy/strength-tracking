import 'acwr/acwr_classifier.dart' as acwr_lib;
import 'acwr/ewma.dart' as ewma_lib;
import 'e1rm/composite_estimator.dart' as e1rm_lib;
import 'e1rm/formulas.dart' as formula_lib;
import 'e1rm/strength_baseline.dart' as baseline_lib;
import 'fatigue/decay.dart' as fatigue_lib;
import 'fatigue/impulse_calculator.dart' as impulse_lib;
import 'fatigue/muscle_normalizer.dart';
import 'models/daily_load.dart';
import 'models/e1rm_estimate.dart';
import 'models/engine_exercise.dart';
import 'models/engine_session.dart';
import 'models/enums.dart';
import 'models/fatigue_impulse.dart';
import 'models/hrv_record.dart';
import 'models/logged_set.dart';
import 'models/muscle_activation.dart';
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

const _e1rmTieRelativeTolerance = 0.01;
const _recommendationSynergistCoefficientThreshold = 0.5;
const _recommendationSynergistMaterialGap = 10.0;

class _E1rmCandidate {
  final LoggedSet set;
  final double value;
  final double rMax;
  final double confidence;

  const _E1rmCandidate({
    required this.set,
    required this.value,
    required this.rMax,
    required this.confidence,
  });
}

_E1rmCandidate _e1rmCandidateFor(LoggedSet set) {
  final rm = formula_lib.rMax(set.reps, set.rpe);
  return _E1rmCandidate(
    set: set,
    value: e1rm_lib.compositeE1rm(
      weight: set.weightKg,
      reps: set.reps,
      rpe: set.rpe,
    ),
    rMax: rm,
    confidence: e1rm_lib.estimateConfidence(rm),
  );
}

bool _isBetterE1rmCandidate(_E1rmCandidate candidate, _E1rmCandidate best) {
  final maxMagnitude = candidate.value.abs() > best.value.abs()
      ? candidate.value.abs()
      : best.value.abs();
  final tolerance = maxMagnitude * _e1rmTieRelativeTolerance;
  final valueDifference = candidate.value - best.value;
  if (valueDifference.abs() > tolerance) {
    return valueDifference > 0;
  }
  if (candidate.confidence != best.confidence) {
    return candidate.confidence > best.confidence;
  }
  if (candidate.set.weightKg != best.set.weightKg) {
    return candidate.set.weightKg > best.set.weightKg;
  }
  if (candidate.set.reps != best.set.reps) {
    return candidate.set.reps > best.set.reps;
  }
  return false;
}

bool _isHighCoefficientSynergist(MuscleActivation activation) {
  return activation.role == MuscleRole.synergist &&
      activation.coefficient >= _recommendationSynergistCoefficientThreshold;
}

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
    if (_state.ingestedSessionIds.contains(session.id)) {
      return;
    }

    // Group sets by exerciseId
    final setsByExercise = <String, List<LoggedSet>>{};
    for (final set in session.sets) {
      setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    final newE1rmHistory = Map<String, List<E1rmEstimate>>.from(
      _state.e1rmHistory,
    );
    final newFatigueLog = Map<String, List<FatigueImpulse>>.from(
      _state.fatigueLog,
    );
    final newLastTopSets = Map<String, LoggedSet>.from(_state.lastTopSets);

    for (final entry in setsByExercise.entries) {
      final exerciseId = entry.key;
      final sets = entry.value;
      final strengthSets = sets.where((set) => set.hasStrengthLoad).toList();

      _E1rmCandidate? bestE1rmCandidate;
      if (strengthSets.isNotEmpty) {
        // Find the heaviest strength set (by weight, then reps as tiebreaker)
        final topSet = strengthSets.reduce((a, b) {
          if (a.weightKg != b.weightKg) return a.weightKg > b.weightKg ? a : b;
          return a.reps >= b.reps ? a : b;
        });

        // Update lastTopSets only for strength sets.
        newLastTopSets[exerciseId] = topSet;

        bestE1rmCandidate = strengthSets.map(_e1rmCandidateFor).reduce((
          best,
          candidate,
        ) {
          return _isBetterE1rmCandidate(candidate, best) ? candidate : best;
        });

        final estimate = E1rmEstimate(
          exerciseId: exerciseId,
          value: bestE1rmCandidate.value,
          rMax: bestE1rmCandidate.rMax,
          confidence: bestE1rmCandidate.confidence,
          estimatedAt: session.endedAt,
          fromEstimatedRpe: bestE1rmCandidate.set.rpeEstimated,
        );

        final history = List<E1rmEstimate>.from(
          newE1rmHistory[exerciseId] ?? [],
        )..add(estimate);
        // Trim to most recent 20 estimates
        newE1rmHistory[exerciseId] = history.length > 20
            ? history.sublist(history.length - 20)
            : history;
      }

      // Look up exercise for fatigue impulse calculation
      final exercise = registry.lookup(exerciseId);
      if (exercise != null) {
        final e1rmForFatigue =
            bestE1rmCandidate?.value ??
            currentE1rm(exerciseId, session.endedAt)!;
        final impulses = impulse_lib.calculateImpulses(
          sets: sets,
          exercise: exercise,
          e1rm: e1rmForFatigue,
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
      newFatigueLog[muscleId] = fatigue_lib.pruneOldImpulses(
        newFatigueLog[muscleId]!,
        now,
      );
    }

    // Compute daily load channels. Keep volumeLoad as the legacy kg-rep-ish
    // display value, while ACWR uses overallLoadPoints.
    double volumeLoad = 0.0;
    double strengthLoadPoints = 0.0;
    double metabolicLoadPoints = 0.0;
    double isometricLoadPoints = 0.0;
    for (final set in session.sets) {
      final exercise = registry.lookup(set.exerciseId);
      if (set.hasStrengthLoad) {
        final volume = set.weightKg * set.reps;
        volumeLoad += volume;
        strengthLoadPoints += volume;
        continue;
      }

      if (exercise == null) {
        volumeLoad += impulse_lib.trainingStressForSet(set);
        continue;
      }
      switch (exercise.localFatigueKind) {
        case LocalFatigueKind.cardioAerobicLocal:
          volumeLoad += impulse_lib.trainingStressForSet(set);
          metabolicLoadPoints += impulse_lib.calculateMetabolicLoad(
            sets: [set],
            metabolicMultiplier: exercise.metabolicMultiplier,
            defaultEffortRpe: exercise.defaultEffortRpe,
          );
          break;
        case LocalFatigueKind.isometricHold:
          volumeLoad += impulse_lib.trainingStressForSet(set);
          isometricLoadPoints += impulse_lib.calculateIsometricLoad(
            sets: [set],
            defaultLocalRpe: exercise.defaultLocalRpe,
          );
          break;
        case LocalFatigueKind.strengthVolume:
          if (set.hasTimedLoad) {
            volumeLoad += impulse_lib.trainingStressForSet(set);
            isometricLoadPoints += impulse_lib.calculateIsometricLoad(
              sets: [set],
              defaultLocalRpe: exercise.defaultLocalRpe,
            );
          }
          break;
        case LocalFatigueKind.none:
          break;
      }
    }

    // Aggregate and trim local-calendar-day loads (keep 35 days).
    final newDailyLoad = DailyLoad.fromComponents(
      date: ewma_lib.localCalendarDay(session.endedAt),
      volumeLoad: volumeLoad,
      strengthLoadPoints: strengthLoadPoints,
      metabolicLoadPoints: metabolicLoadPoints,
      isometricLoadPoints: isometricLoadPoints,
    );
    final cutoff = ewma_lib
        .localCalendarDay(now)
        .subtract(const Duration(days: 35));
    final trimmedDailyLoads = ewma_lib.aggregateDailyLoads([
      ..._state.dailyLoads,
      newDailyLoad,
    ], cutoff: cutoff);

    // Recompute EWMA from sorted daily aggregates so out-of-order history and
    // same-day multi-session ingestion produce deterministic ACWR state.
    final newAcwrState = ewma_lib.recomputeEwmaFromDailyLoads(
      trimmedDailyLoads,
    );

    _state = _state.copyWith(
      e1rmHistory: newE1rmHistory,
      fatigueLog: newFatigueLog,
      dailyLoads: trimmedDailyLoads,
      acwrState: newAcwrState,
      lastTopSets: newLastTopSets,
      lastUpdated: DateTime.now(),
      sessionsIngested: _state.sessionsIngested + 1,
      ingestedSessionIds: {..._state.ingestedSessionIds, session.id},
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
    _state = _state.copyWith(hrvHistory: trimmed, lastUpdated: DateTime.now());
  }

  /// Re-fetches HealthKit data if the last fetch is older than [threshold].
  ///
  /// Uses callback functions to decouple from the Flutter-layer HealthKit
  /// data source, keeping the engine package pure Dart.
  Future<void> refreshHealthKitIfStale({
    required Future<List<SleepRecord>> Function() fetchSleep,
    required Future<List<HrvRecord>> Function() fetchHrv,
    Duration threshold = const Duration(hours: 1),
  }) async {
    final lastFetch = _state.lastHealthKitFetch;
    final now = DateTime.now();
    if (lastFetch != null && now.difference(lastFetch) < threshold) {
      return; // Still fresh
    }

    // Replace non-empty fresh data to avoid duplicates. Empty fetches are
    // treated as attempted refreshes without erasing previously fetched data.
    final sleepRecords = await fetchSleep();
    if (sleepRecords.isNotEmpty) {
      _state = _state.copyWith(sleepHistory: sleepRecords);
    }

    final hrvRecords = await fetchHrv();
    if (hrvRecords.isNotEmpty) {
      _state = _state.copyWith(hrvHistory: hrvRecords);
    }
    _state = _state.copyWith(lastHealthKitFetch: now);
  }

  /// Marks the current time as the last HealthKit fetch.
  void stampHealthKitFetch() {
    _state = _state.copyWith(lastHealthKitFetch: DateTime.now());
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

  /// Returns a fatigue map that includes both persisted fatigue AND the
  /// projected contribution from [previewSets], without mutating engine state.
  ///
  /// Used for live heatmap updates during an active workout.
  Map<String, fatigue_lib.FatigueStatus> previewFatigueWithSets(
    List<LoggedSet> previewSets, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();

    if (previewSets.isEmpty) {
      return fullFatigueMap(now);
    }

    // Group preview sets by exercise
    final setsByExercise = <String, List<LoggedSet>>{};
    for (final set in previewSets) {
      setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    // Build temporary impulses from preview sets
    final previewImpulses = <String, List<FatigueImpulse>>{};
    for (final entry in setsByExercise.entries) {
      final exercise = registry.lookup(entry.key);
      if (exercise == null) continue;

      // currentE1rm always returns a value (falls back to baseline estimate)
      final e1rm = currentE1rm(entry.key)!;
      final impulses = impulse_lib.calculateImpulses(
        sets: entry.value,
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: now,
      );
      for (final impulse in impulses) {
        previewImpulses.putIfAbsent(impulse.muscleId, () => []).add(impulse);
      }
    }

    // Merge persisted fatigue log with preview impulses
    final mergedLog = <String, List<FatigueImpulse>>{};
    for (final entry in _state.fatigueLog.entries) {
      mergedLog[entry.key] = List.of(entry.value);
    }
    for (final entry in previewImpulses.entries) {
      mergedLog.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }

    return fatigue_lib.fullFatigueMap(mergedLog, now, age: _state.profile.age);
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
    final sleepDetails = sleep_lib.scoreSleepDetailed(_state.sleepHistory, now);
    final hrvDetails = hrv_lib.scoreHrvDetailed(_state.hrvHistory, now);
    return readiness_lib.computeReadiness(
      acwr: acwr,
      sleepDetails: sleepDetails,
      hrvDetails: hrvDetails,
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
    final targets =
        overrides ??
        (exercise != null
            ? TargetParams.defaultFor(exercise.movement)
            : const TargetParams(
                targetRepsLow: 8,
                targetRepsHigh: 12,
                targetRpe: 8.0,
              ));

    // Current e1RM
    final e1rm = currentE1rm(exerciseId, now);

    // Fatigue input for safety gates.
    double recommendationFatigue = 0.0;
    if (exercise != null) {
      recommendationFatigue = _recommendationFatigue(exercise, now);
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
      primaryMuscleFatigue: recommendationFatigue,
      acwrZone: acwrZone,
      readinessScore: readiness.score,
    );
  }

  double _recommendationFatigue(EngineExercise exercise, DateTime at) {
    var primaryMax = 0.0;
    for (final activation in exercise.muscleMap) {
      if (activation.role == MuscleRole.primary) {
        final fatigue = currentFatigue(activation.muscleId, at);
        if (fatigue > primaryMax) {
          primaryMax = fatigue;
        }
      }
    }

    var highSynergistMax = 0.0;
    for (final activation in exercise.muscleMap) {
      if (_isHighCoefficientSynergist(activation)) {
        final fatigue = currentFatigue(activation.muscleId, at);
        if (fatigue > highSynergistMax) {
          highSynergistMax = fatigue;
        }
      }
    }

    if (highSynergistMax > primaryMax + _recommendationSynergistMaterialGap) {
      return highSynergistMax;
    }
    return primaryMax;
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
        entry.key,
        entry.value,
        now,
        age: _state.profile.age,
      );
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

  void _migrateStaleMuscleIds() {
    final log = _state.fatigueLog;
    final migrated = <String, List<FatigueImpulse>>{};
    var changed = false;
    for (final entry in log.entries) {
      final canonical = MuscleNormalizer.normalize(entry.key);
      if (canonical != entry.key) changed = true;
      migrated[canonical] = [...migrated[canonical] ?? [], ...entry.value];
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
      final fallbackRpe = _isSupportedStrengthRpe(session.sessionRpe)
          ? session.sessionRpe!
          : 8.0;

      final backfilledSets = session.sets.map((set) {
        if (set.rpeEstimated) {
          return LoggedSet(
            exerciseId: set.exerciseId,
            weightKg: set.weightKg,
            reps: set.reps,
            rpe: fallbackRpe,
            completedAt: set.completedAt,
            rpeEstimated: true,
            durationSeconds: set.durationSeconds,
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

bool _isSupportedStrengthRpe(double? rpe) {
  return rpe != null &&
      rpe >= formula_lib.minStrengthRpe &&
      rpe <= formula_lib.maxStrengthRpe;
}
