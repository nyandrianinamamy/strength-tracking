import '../models/engine_exercise.dart';
import '../models/fatigue_impulse.dart';
import '../models/logged_set.dart';

/// Normalization factor calibrated so that 4 sets × 10 reps @ RPE 8
/// at ~75% e1RM yields F0 ~75-85 for the primary muscle.
/// Derivation: 4×10×75×0.8 / (100 × 30) × 100 = 2400/3000 × 100 = 80
const double _normalizationFactor = 30.0;

/// Clamps [value] to [min..max].
double _clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Calculates fatigue impulses for each muscle in [exercise.muscleMap] after
/// a training session described by [sets].
///
/// Steps:
/// 1. For each set: setStress = weightKg × reps × (rpe / 10)
/// 2. Accumulate per muscle:  accum[muscleId] += setStress × coefficient
/// 3. Normalize: F0 = clamp((accum / (e1rm × normFactor)) × 100, 0, 100)
/// 4. Emit one [FatigueImpulse] per muscle timestamped at [sessionEndedAt]
List<FatigueImpulse> calculateImpulses({
  required List<LoggedSet> sets,
  required EngineExercise exercise,
  required double e1rm,
  required DateTime sessionEndedAt,
}) {
  // Accumulate raw stress per muscle
  final Map<String, double> accum = {};
  for (final activation in exercise.muscleMap) {
    accum[activation.muscleId] = 0.0;
  }

  for (final set in sets) {
    final setStress = set.weightKg * set.reps * (set.rpe / 10.0);
    for (final activation in exercise.muscleMap) {
      accum[activation.muscleId] =
          accum[activation.muscleId]! + setStress * activation.coefficient;
    }
  }

  // Convert to impulses
  final result = <FatigueImpulse>[];
  for (final activation in exercise.muscleMap) {
    final totalStress = accum[activation.muscleId]!;
    final f0 = _clamp(
      (totalStress / (e1rm * _normalizationFactor)) * 100.0,
      0.0,
      100.0,
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
