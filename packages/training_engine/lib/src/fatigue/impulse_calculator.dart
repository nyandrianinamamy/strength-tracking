import 'dart:math';

import '../models/engine_exercise.dart';
import '../models/enums.dart';
import '../models/fatigue_impulse.dart';
import '../models/logged_set.dart';

/// Normalization factor calibrated so that 4 sets × 10 reps @ RPE 8
/// at ~75% e1RM yields F0 ~75-85 for the primary muscle.
/// Derivation: 4×10×75×0.8 / (100 × 30) × 100 = 2400/3000 × 100 = 80
const double _normalizationFactor = 30.0;

/// Base constant for isometric fatigue formula.
const double _isometricBaseConstant = 32.0;

/// Base constant for cardio local fatigue formula.
const double _cardioBaseConstant = 180.0;

/// Time constant for cardio exponential decay (minutes).
const double _cardioTimeConstant = 35.0;

/// Per-set duration cap for isometric formula (minutes).
const double _isometricMaxMinutesPerSet = 5.0;

/// Default cap for exercises that haven't been configured.
const double _defaultIsometricCap = 85.0;

/// Clamps [value] to [min..max].
double _clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Calculates effective RPE factor for isometric holds.
/// Formula: ((rpe - 4) / 6) ^ 1.25
/// RPE 5 -> 0.17, RPE 7 -> 0.63, RPE 10 -> 1.0
double _isometricEffortFactor(double rpe) {
  final clampedRpe = _clamp(rpe, 5.0, 10.0);
  final normalized = (clampedRpe - 4.0) / 6.0;
  return pow(normalized, 1.25).toDouble();
}

/// Calculates effort factor for cardio (quadratic scaling).
/// Formula: (effort / 10) ^ 2
double _cardioEffortFactor(double effort) {
  final clampedEffort = _clamp(effort, 0.0, 10.0);
  return pow(clampedEffort / 10.0, 2.0).toDouble();
}

/// Calculates training stress for a strength set.
/// Formula: weightKg × reps × (rpe / 10)
double _strengthStress(LoggedSet set, double strengthRpe) {
  return set.weightKg * set.reps * (strengthRpe / 10.0);
}

/// Calculates local fatigue impulse for an isometric hold.
/// Formula: 32 × sqrt(min(durationMin, 5)) × ((rpe-4)/6)^1.25 × coefficient
/// Then clamped by exercise.localFatigueCap.
List<FatigueImpulse> _calculateIsometricImpulses({
  required List<LoggedSet> sets,
  required EngineExercise exercise,
  required DateTime sessionEndedAt,
  double? overrideCap,
}) {
  final Map<String, double> accum = {};
  for (final activation in exercise.muscleMap) {
    accum[activation.muscleId] = 0.0;
  }

  for (final set in sets) {
    final durationMin = set.durationSeconds / 60.0;
    final effectiveMin = min(durationMin, _isometricMaxMinutesPerSet);
    // Use localRpe if available, otherwise strengthRpe, otherwise default
    final rpe = set.localRpe ?? set.strengthRpe ?? exercise.defaultLocalRpe;
    final effortFactor = _isometricEffortFactor(rpe);

    final setBase = _isometricBaseConstant * sqrt(effectiveMin) * effortFactor;

    for (final activation in exercise.muscleMap) {
      accum[activation.muscleId] =
          accum[activation.muscleId]! + setBase * activation.coefficient;
    }
  }

  final cap = overrideCap ?? exercise.localFatigueCap;
  final result = <FatigueImpulse>[];
  for (final activation in exercise.muscleMap) {
    final f0 = _clamp(accum[activation.muscleId]!, 0.0, cap);
    result.add(
      FatigueImpulse(
        muscleId: activation.muscleId,
        magnitude: f0,
        timestamp: sessionEndedAt,
      ),
    );
  }
  return result;
}

/// Calculates local fatigue impulse for cardio exercise.
/// Formula: 180 × cardioLocalMultiplier × (effort/10)^2 × (1 - exp(-minutes/35)) × coefficient
/// Then clamped by exercise.localFatigueCap (typically 55-65 for cardio).
List<FatigueImpulse> _calculateCardioImpulses({
  required List<LoggedSet> sets,
  required EngineExercise exercise,
  required DateTime sessionEndedAt,
}) {
  // Aggregate total duration and effort-weighted effort
  double totalMinutes = 0.0;
  double weightedEffort = 0.0;

  for (final set in sets) {
    final minutes = set.durationSeconds / 60.0;
    totalMinutes += minutes;
    final effort =
        set.effortRpe ??
        (set.strengthRpe != null
            ? set.strengthRpe!
            : exercise.defaultEffortRpe);
    weightedEffort += effort * minutes;
  }

  // Use average effort weighted by duration
  final avgEffort = totalMinutes > 0
      ? weightedEffort / totalMinutes
      : exercise.defaultEffortRpe;

  final effortFactor = _cardioEffortFactor(avgEffort);
  final timeFactor = 1.0 - exp(-totalMinutes / _cardioTimeConstant);
  final multiplier = exercise.cardioLocalMultiplier;

  final baseImpulse =
      _cardioBaseConstant * multiplier * effortFactor * timeFactor;

  final cap = exercise.localFatigueCap;
  final result = <FatigueImpulse>[];
  for (final activation in exercise.muscleMap) {
    final f0 = _clamp(baseImpulse * activation.coefficient, 0.0, cap);
    result.add(
      FatigueImpulse(
        muscleId: activation.muscleId,
        magnitude: f0,
        timestamp: sessionEndedAt,
      ),
    );
  }
  return result;
}

/// Calculates fatigue impulses for strength volume exercises.
/// Uses the classic formula: stress / (e1rm × normalization) × 100
List<FatigueImpulse> _calculateStrengthImpulses({
  required List<LoggedSet> sets,
  required EngineExercise exercise,
  required double e1rm,
  required DateTime sessionEndedAt,
}) {
  final Map<String, double> accum = {};
  for (final activation in exercise.muscleMap) {
    accum[activation.muscleId] = 0.0;
  }

  for (final set in sets) {
    final strengthRpe = set.strengthRpe ?? set.rpe;
    final setStress = _strengthStress(set, strengthRpe);
    for (final activation in exercise.muscleMap) {
      accum[activation.muscleId] =
          accum[activation.muscleId]! + setStress * activation.coefficient;
    }
  }

  final cap = exercise.localFatigueCap;
  final result = <FatigueImpulse>[];
  for (final activation in exercise.muscleMap) {
    final totalStress = accum[activation.muscleId]!;
    final f0 = _clamp(
      (totalStress / (e1rm * _normalizationFactor)) * 100.0,
      0.0,
      cap,
    );
    result.add(
      FatigueImpulse(
        muscleId: activation.muscleId,
        magnitude: f0,
        timestamp: sessionEndedAt,
      ),
    );
  }
  return result;
}

/// Returns an empty list for exercises that produce no local fatigue.
List<FatigueImpulse> _calculateNoImpulses({
  required EngineExercise exercise,
  required DateTime sessionEndedAt,
}) {
  return [];
}

/// Legacy helper: calculates training stress for a set.
/// For strength: weight × reps × (rpe/10)
/// For timed: uses appropriate formula based on context.
///
/// Note: This is kept for backward compatibility. New code should use
/// the appropriate specific calculation method.
double trainingStressForSet(LoggedSet set) {
  if (set.hasStrengthLoad && set.strengthRpe != null) {
    return _strengthStress(set, set.strengthRpe!);
  }
  // Legacy fallback for old code that doesn't distinguish exercise types
  if (set.hasStrengthLoad) {
    return set.weightKg * set.reps * (set.rpe / 10.0);
  }
  if (set.hasTimedLoad) {
    // For legacy compatibility, use a simple duration-based stress
    // This is approximate and new code should use the specific formulas
    final durationMin = set.durationSeconds / 60.0;
    final effort = set.effortRpe ?? set.localRpe ?? 7.0;
    final effortFactor = effort >= 5.0
        ? _isometricEffortFactor(effort)
        : (effort / 10.0);
    return durationMin * 60.0 * effortFactor; // Approximate stress units
  }
  return 0.0;
}

/// Detects whether a set is likely an isometric/timed exercise vs strength.
/// Used for backward compatibility with unconfigured exercises.
bool _isTimedSet(List<LoggedSet> sets) {
  if (sets.isEmpty) return false;
  // If majority of sets have no strength load but have duration, treat as timed
  final timedCount = sets
      .where((s) => !s.hasStrengthLoad && s.hasTimedLoad)
      .length;
  return timedCount > sets.length / 2;
}

/// Calculates fatigue impulses for each muscle in [exercise.muscleMap] after
/// a training session described by [sets].
///
/// The calculation method is determined by [exercise.localFatigueKind]:
/// - [LocalFatigueKind.strengthVolume]: Uses weight × reps × RPE formula normalized by e1RM.
///   Requires a valid e1RM value.
/// - [LocalFatigueKind.isometricHold]: Uses duration-based formula without e1RM.
///   Formula: 32 × sqrt(min(duration, 5min)) × ((rpe-4)/6)^1.25 × coefficient
/// - [LocalFatigueKind.cardioAerobicLocal]: Uses cardio formula without e1RM.
///   Formula: 180 × multiplier × (effort/10)^2 × (1-exp(-minutes/35)) × coefficient
/// - [LocalFatigueKind.none]: Returns empty list (no local fatigue).
///
/// Backward compatibility: If exercise has [LocalFatigueKind.strengthVolume] (default)
/// but the sets have no strength load and are timed, falls back to isometric calculation.
///
/// In all cases, impulses are clamped to [exercise.localFatigueCap].
List<FatigueImpulse> calculateImpulses({
  required List<LoggedSet> sets,
  required EngineExercise exercise,
  required double e1rm,
  required DateTime sessionEndedAt,
}) {
  // Backward compatibility: if exercise defaults to strengthVolume but sets
  // are clearly timed/isometric (no weight/reps), fall back to isometric formula
  final effectiveKind =
      (exercise.localFatigueKind == LocalFatigueKind.strengthVolume &&
          _isTimedSet(sets))
      ? LocalFatigueKind.isometricHold
      : exercise.localFatigueKind;

  switch (effectiveKind) {
    case LocalFatigueKind.strengthVolume:
      return _calculateStrengthImpulses(
        sets: sets,
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEndedAt,
      );
    case LocalFatigueKind.isometricHold:
      return _calculateIsometricImpulses(
        sets: sets,
        exercise: exercise,
        sessionEndedAt: sessionEndedAt,
        // Use a reasonable cap for exercises that haven't been configured yet
        overrideCap: exercise.localFatigueCap == 100.0
            ? _defaultIsometricCap
            : exercise.localFatigueCap,
      );
    case LocalFatigueKind.cardioAerobicLocal:
      return _calculateCardioImpulses(
        sets: sets,
        exercise: exercise,
        sessionEndedAt: sessionEndedAt,
      );
    case LocalFatigueKind.none:
      return _calculateNoImpulses(
        exercise: exercise,
        sessionEndedAt: sessionEndedAt,
      );
  }
}

/// Calculates metabolic load points for cardio exercises.
/// Formula: minutes × effort × metabolicMultiplier
/// Used for daily load tracking (systemic fatigue, not local muscle fatigue).
double calculateMetabolicLoad({
  required List<LoggedSet> sets,
  required double metabolicMultiplier,
  required double defaultEffortRpe,
}) {
  double totalLoad = 0.0;
  for (final set in sets) {
    final minutes = set.durationSeconds / 60.0;
    final effort = set.effortRpe ?? defaultEffortRpe;
    totalLoad += minutes * effort * metabolicMultiplier;
  }
  return totalLoad;
}

/// Calculates isometric load points.
/// Formula: minutes × localRpe × 0.5
/// Used for daily load tracking (secondary to the local fatigue impulse).
double calculateIsometricLoad({
  required List<LoggedSet> sets,
  required double defaultLocalRpe,
}) {
  double totalLoad = 0.0;
  for (final set in sets) {
    final minutes = set.durationSeconds / 60.0;
    final rpe = set.localRpe ?? defaultLocalRpe;
    totalLoad += minutes * rpe * 0.5;
  }
  return totalLoad;
}
