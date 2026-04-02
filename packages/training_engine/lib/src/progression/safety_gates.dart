import '../models/enums.dart';

enum GateReason { muscleFatigue, acwrCaution, acwrDanger, lowReadiness }

enum GateAction { deload, maintain, reduceLoad, suggestAlternative }

class GateResult {
  final bool passed;
  final GateReason? reason;
  final GateAction? action;
  final double modifier; // 1.0 = no dampening, 0.5 = half increment

  const GateResult.clear()
      : passed = true,
        reason = null,
        action = null,
        modifier = 1.0;

  const GateResult.blocked({
    required GateReason reason,
    required GateAction action,
    double modifier = 0.0,
  })  : passed = false,
        reason = reason,
        action = action,
        modifier = modifier;

  const GateResult.dampened({required double modifier})
      : passed = true,
        reason = null,
        action = null,
        modifier = modifier;

  // Private named constructor for internal use
  const GateResult._({
    required this.passed,
    required this.reason,
    required this.action,
    required this.modifier,
  });
}

/// Checks safety gates sequentially and returns the first failing gate.
///
/// Gates (in order):
/// 1. Muscle fatigue > 60
/// 2. ACWR danger / caution
/// 3. Readiness < 70
///
/// Null values for [acwrZone] and [readinessScore] skip their respective gates.
GateResult checkSafetyGates({
  required double primaryMuscleFatigue, // 0–100
  AcwrZone? acwrZone, // null = skip gate
  double? readinessScore, // 0–100, null = skip gate
}) {
  // Gate 1: Muscle fatigue
  if (primaryMuscleFatigue > 60) {
    if (primaryMuscleFatigue > 80) {
      final mod = 1 - (primaryMuscleFatigue - 60) / 100;
      return GateResult._(
        passed: false,
        reason: GateReason.muscleFatigue,
        action: GateAction.suggestAlternative,
        modifier: mod,
      );
    } else {
      return const GateResult._(
        passed: false,
        reason: GateReason.muscleFatigue,
        action: GateAction.reduceLoad,
        modifier: 0.0,
      );
    }
  }

  // Gate 2: ACWR zone
  if (acwrZone != null) {
    if (acwrZone == AcwrZone.danger) {
      return const GateResult._(
        passed: false,
        reason: GateReason.acwrDanger,
        action: GateAction.deload,
        modifier: 0.0,
      );
    } else if (acwrZone == AcwrZone.caution) {
      return const GateResult._(
        passed: false,
        reason: GateReason.acwrCaution,
        action: GateAction.maintain,
        modifier: 0.0,
      );
    }
  }

  // Gate 3: Readiness score
  if (readinessScore != null) {
    if (readinessScore < 30) {
      return const GateResult._(
        passed: false,
        reason: GateReason.lowReadiness,
        action: GateAction.reduceLoad,
        modifier: 0.0,
      );
    } else if (readinessScore < 50) {
      return const GateResult._(
        passed: false,
        reason: GateReason.lowReadiness,
        action: GateAction.maintain,
        modifier: 0.0,
      );
    } else if (readinessScore < 70) {
      return const GateResult.dampened(modifier: 0.5);
    }
  }

  return const GateResult.clear();
}
