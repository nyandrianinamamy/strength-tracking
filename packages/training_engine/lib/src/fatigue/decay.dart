import 'dart:math';
import '../models/enums.dart';
import '../models/fatigue_impulse.dart';
import 'muscle_registry.dart';

// ---------------------------------------------------------------------------
// Core decay function
// ---------------------------------------------------------------------------

/// Returns the remaining fatigue after [hoursElapsed] using exponential decay.
///
/// F(t) = magnitude × exp(-hoursElapsed / tau)
double decayedFatigue({
  required double magnitude,
  required double hoursElapsed,
  required double tau,
}) {
  return magnitude * exp(-hoursElapsed / tau);
}

// ---------------------------------------------------------------------------
// Age recovery modifier
// ---------------------------------------------------------------------------

/// Returns a multiplier applied to the decay constant (tau) so that older
/// athletes recover more slowly.
///
/// age ≤ 30 → 1.00
/// age ≤ 40 → 1.10
/// age ≤ 50 → 1.25
/// else     → 1.40
double ageRecoveryModifier(int age) {
  if (age <= 30) return 1.0;
  if (age <= 40) return 1.10;
  if (age <= 50) return 1.25;
  return 1.40;
}

// ---------------------------------------------------------------------------
// Current fatigue for a single muscle
// ---------------------------------------------------------------------------

/// Sums the decayed contributions from all [impulses] for [muscleId] at [now].
///
/// Uses [defaultMuscles] to look up tau; falls back to moderate tau for
/// unknown muscles. Multiplies tau by [ageRecoveryModifier] when [age] is
/// provided (older tau = slower recovery = higher residual fatigue).
/// Result is clamped to [0, 100].
double currentFatigue(
  String muscleId,
  List<FatigueImpulse> impulses,
  DateTime now, {
  int? age,
}) {
  final muscleDef = defaultMuscles[muscleId];
  double tau = muscleDef?.decayConstant ?? decayConstantForSize(MuscleSize.moderate);

  if (age != null) {
    tau = tau * ageRecoveryModifier(age);
  }

  double total = 0.0;
  for (final impulse in impulses) {
    if (impulse.muscleId != muscleId) continue;
    final hoursElapsed = now.difference(impulse.timestamp).inMicroseconds / 3600000000.0;
    total += decayedFatigue(
      magnitude: impulse.magnitude,
      hoursElapsed: hoursElapsed,
      tau: tau,
    );
  }

  return total.clamp(0.0, 100.0);
}

// ---------------------------------------------------------------------------
// FatigueStatus
// ---------------------------------------------------------------------------

/// Fatigue status for a single muscle.
class FatigueStatus {
  /// Fatigue level 0–100.
  final double level;

  /// Hue for UI colouring: 120 × (1 − level/100).
  /// Green (120) when fully recovered, red (0) when maximally fatigued.
  final double hue;

  /// Estimated time until level drops below 5 (i.e. "ready").
  /// Returns [Duration.zero] when already below 5.
  final Duration estimatedFullRecovery;

  /// Phase based on level:
  /// acute (>60), recovering (5–60), ready (<5)
  final RecoveryPhase phase;

  FatigueStatus({
    required double level,
    double? tau,
  }) : level = level.clamp(0.0, 100.0),
       hue = 120.0 * (1.0 - level.clamp(0.0, 100.0) / 100.0),
       phase = _phaseFor(level),
       estimatedFullRecovery = _estimateRecovery(level, tau ?? decayConstantForSize(MuscleSize.large));

  static RecoveryPhase _phaseFor(double level) {
    if (level > 60) return RecoveryPhase.acute;
    if (level >= 5) return RecoveryPhase.recovering;
    return RecoveryPhase.ready;
  }

  /// Time until F(t) = level × exp(-t/tau) < 5
  /// Solve: t = -tau × ln(5 / level)
  static Duration _estimateRecovery(double level, double tau) {
    if (level < 5.0) return Duration.zero;
    final hours = -tau * log(5.0 / level);
    if (hours <= 0) return Duration.zero;
    return Duration(minutes: (hours * 60).round());
  }
}

// ---------------------------------------------------------------------------
// Full fatigue map
// ---------------------------------------------------------------------------

/// Returns a [FatigueStatus] for every muscle present in [impulseLog].
///
/// [impulseLog] maps muscleId -> list of impulses.
Map<String, FatigueStatus> fullFatigueMap(
  Map<String, List<FatigueImpulse>> impulseLog,
  DateTime now, {
  int? age,
}) {
  final result = <String, FatigueStatus>{};
  for (final entry in impulseLog.entries) {
    final muscleId = entry.key;
    final impulses = entry.value;
    final muscleDef = defaultMuscles[muscleId];
    double tau = muscleDef?.decayConstant ?? decayConstantForSize(MuscleSize.moderate);
    if (age != null) {
      tau = tau * ageRecoveryModifier(age);
    }
    final level = currentFatigue(muscleId, impulses, now, age: age);
    result[muscleId] = FatigueStatus(level: level, tau: tau);
  }
  return result;
}

// ---------------------------------------------------------------------------
// Prune old impulses
// ---------------------------------------------------------------------------

/// Removes impulses older than 7 days from [now].
List<FatigueImpulse> pruneOldImpulses(
  List<FatigueImpulse> impulses,
  DateTime now,
) {
  final cutoff = now.subtract(const Duration(days: 7));
  return impulses.where((i) => !i.timestamp.isBefore(cutoff)).toList();
}
