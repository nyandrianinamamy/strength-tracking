import '../models/enums.dart';
import '../models/logged_set.dart';
import 'safety_gates.dart';
import 'performance_delta.dart';
import 'load_predictor.dart';
import 'equipment_rounding.dart';

/// A fully resolved load recommendation for a given exercise.
class LoadRecommendation {
  final String exerciseId;
  final double? suggestedWeightKg;
  final TargetParams targets;
  final PerformanceDelta delta;
  final GateResult gateResult;
  final double? e1rm;
  final double? previousWeightKg;
  final String explanation;

  const LoadRecommendation({
    required this.exerciseId,
    required this.suggestedWeightKg,
    required this.targets,
    required this.delta,
    required this.gateResult,
    required this.e1rm,
    required this.previousWeightKg,
    required this.explanation,
  });
}

/// Assembles a [LoadRecommendation] by running the full progression pipeline:
///
/// 1. Check safety gates.
/// 2. If gates blocked with deload: previousWeight * 0.7 (danger) or * 0.9.
/// 3. If gates blocked with maintain: previousWeight.
/// 4. Evaluate performance delta from [lastTopSet] (null -> maintenance).
/// 5. If progression + gates clear: predictLoad from e1rm, apply gate modifier, round.
/// 6. If maintenance: previousWeight.
/// 7. If regression: previousWeight * 0.92.
/// 8. If no data: null weight, "Not enough data" explanation.
LoadRecommendation buildRecommendation({
  required String exerciseId,
  required EquipmentClass equipment,
  required TargetParams targets,
  required double? e1rm,
  required double? previousWeightKg,
  required LoggedSet? lastTopSet,
  required double primaryMuscleFatigue,
  required AcwrZone? acwrZone,
  required double? readinessScore,
}) {
  // Step 1: Safety gates
  final gate = checkSafetyGates(
    primaryMuscleFatigue: primaryMuscleFatigue,
    acwrZone: acwrZone,
    readinessScore: readinessScore,
  );

  // Step 2 & 3: Handle blocked gates
  if (!gate.passed) {
    if (gate.action == GateAction.deload) {
      // ACWR danger -> 70%, other deload -> 90%
      final deloadFactor = gate.reason == GateReason.acwrDanger ? 0.7 : 0.9;
      final suggested = previousWeightKg != null
          ? roundToEquipment(previousWeightKg * deloadFactor, equipment)
          : null;
      return LoadRecommendation(
        exerciseId: exerciseId,
        suggestedWeightKg: suggested,
        targets: targets,
        delta: PerformanceDelta.maintenance,
        gateResult: gate,
        e1rm: e1rm,
        previousWeightKg: previousWeightKg,
        explanation: _deloadExplanation(gate, deloadFactor, suggested),
      );
    }

    if (gate.action == GateAction.maintain) {
      final suggested = previousWeightKg != null
          ? roundToEquipment(previousWeightKg, equipment)
          : null;
      return LoadRecommendation(
        exerciseId: exerciseId,
        suggestedWeightKg: suggested,
        targets: targets,
        delta: PerformanceDelta.maintenance,
        gateResult: gate,
        e1rm: e1rm,
        previousWeightKg: previousWeightKg,
        explanation: _maintainExplanation(gate, suggested),
      );
    }

    if (gate.action == GateAction.reduceLoad) {
      final suggested = previousWeightKg != null
          ? roundToEquipment(previousWeightKg * 0.9, equipment)
          : null;
      return LoadRecommendation(
        exerciseId: exerciseId,
        suggestedWeightKg: suggested,
        targets: targets,
        delta: PerformanceDelta.maintenance,
        gateResult: gate,
        e1rm: e1rm,
        previousWeightKg: previousWeightKg,
        explanation: _reduceLoadExplanation(gate, suggested),
      );
    }

    if (gate.action == GateAction.suggestAlternative) {
      final suggested = previousWeightKg != null
          ? roundToEquipment(previousWeightKg * 0.8, equipment)
          : null;
      return LoadRecommendation(
        exerciseId: exerciseId,
        suggestedWeightKg: suggested,
        targets: targets,
        delta: PerformanceDelta.maintenance,
        gateResult: gate,
        e1rm: e1rm,
        previousWeightKg: previousWeightKg,
        explanation:
            'Muscle fatigue is very high. Consider an alternative exercise '
            'or reduce load significantly.',
      );
    }
  }

  // Step 4: Evaluate performance delta
  final delta = lastTopSet != null
      ? evaluateDelta(
          reps: lastTopSet.reps,
          rpe: lastTopSet.rpe,
          targetRepsHigh: targets.targetRepsHigh,
          targetRpe: targets.targetRpe,
          targetRepsLow: targets.targetRepsLow,
        )
      : PerformanceDelta.maintenance;

  // Step 5: Progression + gates clear
  if (delta == PerformanceDelta.progression) {
    if (e1rm != null) {
      final targetMidReps =
          (targets.targetRepsLow + targets.targetRepsHigh) ~/ 2;
      final rawPredicted =
          predictLoad(e1rm: e1rm, targetReps: targetMidReps, targetRpe: targets.targetRpe);

      // Apply gate modifier to the increment over previous weight
      double suggested;
      if (gate.modifier < 1.0 && previousWeightKg != null) {
        final increment = rawPredicted - previousWeightKg;
        suggested = previousWeightKg + (increment * gate.modifier);
      } else {
        suggested = rawPredicted;
      }
      suggested = roundToEquipment(suggested, equipment);

      return LoadRecommendation(
        exerciseId: exerciseId,
        suggestedWeightKg: suggested,
        targets: targets,
        delta: delta,
        gateResult: gate,
        e1rm: e1rm,
        previousWeightKg: previousWeightKg,
        explanation: _progressionExplanation(suggested, previousWeightKg, gate),
      );
    }

    // No e1rm but have previous weight - suggest a small increment
    if (previousWeightKg != null) {
      final increment = 2.5 * gate.modifier;
      final suggested =
          roundToEquipment(previousWeightKg + increment, equipment);
      return LoadRecommendation(
        exerciseId: exerciseId,
        suggestedWeightKg: suggested,
        targets: targets,
        delta: delta,
        gateResult: gate,
        e1rm: e1rm,
        previousWeightKg: previousWeightKg,
        explanation: _progressionExplanation(suggested, previousWeightKg, gate),
      );
    }
  }

  // Step 6: Maintenance
  if (delta == PerformanceDelta.maintenance) {
    if (previousWeightKg == null && e1rm == null) {
      return _noDataRecommendation(
          exerciseId: exerciseId, targets: targets, gate: gate, e1rm: e1rm);
    }

    final suggested = previousWeightKg != null
        ? roundToEquipment(previousWeightKg, equipment)
        : null;
    return LoadRecommendation(
      exerciseId: exerciseId,
      suggestedWeightKg: suggested,
      targets: targets,
      delta: delta,
      gateResult: gate,
      e1rm: e1rm,
      previousWeightKg: previousWeightKg,
      explanation: suggested != null
          ? 'Maintain current load of ${suggested.toStringAsFixed(1)} kg. '
              'Performance is within target range.'
          : 'Not enough data to recommend a specific load.',
    );
  }

  // Step 7: Regression
  if (delta == PerformanceDelta.regression) {
    if (previousWeightKg == null) {
      return _noDataRecommendation(
          exerciseId: exerciseId, targets: targets, gate: gate, e1rm: e1rm);
    }
    final suggested =
        roundToEquipment(previousWeightKg * 0.92, equipment);
    return LoadRecommendation(
      exerciseId: exerciseId,
      suggestedWeightKg: suggested,
      targets: targets,
      delta: delta,
      gateResult: gate,
      e1rm: e1rm,
      previousWeightKg: previousWeightKg,
      explanation:
          'Performance regressed. Reducing load to ${suggested.toStringAsFixed(1)} kg '
          '(8% reduction) to rebuild confidence.',
    );
  }

  // Step 8: No data fallback
  return _noDataRecommendation(
      exerciseId: exerciseId, targets: targets, gate: gate, e1rm: e1rm);
}

LoadRecommendation _noDataRecommendation({
  required String exerciseId,
  required TargetParams targets,
  required GateResult gate,
  required double? e1rm,
}) {
  return LoadRecommendation(
    exerciseId: exerciseId,
    suggestedWeightKg: null,
    targets: targets,
    delta: PerformanceDelta.maintenance,
    gateResult: gate,
    e1rm: e1rm,
    previousWeightKg: null,
    explanation: 'Not enough data to make a load recommendation.',
  );
}

String _deloadExplanation(GateResult gate, double factor, double? suggested) {
  final pct = ((1 - factor) * 100).round();
  final reason = gate.reason == GateReason.acwrDanger
      ? 'Training load is dangerously high (ACWR danger zone)'
      : _gateReasonDescription(gate.reason);
  final weightStr =
      suggested != null ? ' Suggested: ${suggested.toStringAsFixed(1)} kg.' : '';
  return '$reason. Deloading by $pct%.$weightStr';
}

String _maintainExplanation(GateResult gate, double? suggested) {
  final reason = _gateReasonDescription(gate.reason);
  final weightStr = suggested != null
      ? ' Maintain ${suggested.toStringAsFixed(1)} kg.'
      : '';
  return '$reason. Maintaining current load.$weightStr';
}

String _reduceLoadExplanation(GateResult gate, double? suggested) {
  final reason = _gateReasonDescription(gate.reason);
  final weightStr = suggested != null
      ? ' Suggested: ${suggested.toStringAsFixed(1)} kg.'
      : '';
  return '$reason. Reducing load by 10%.$weightStr';
}

String _progressionExplanation(
    double suggested, double? previous, GateResult gate) {
  final base =
      'Great performance! Suggested load: ${suggested.toStringAsFixed(1)} kg';
  if (previous != null) {
    final diff = suggested - previous;
    final sign = diff >= 0 ? '+' : '';
    final dampNote = gate.modifier < 1.0
        ? ' (dampened by readiness — half-increment applied)'
        : '';
    return '$base ($sign${diff.toStringAsFixed(1)} kg from previous)$dampNote.';
  }
  return '$base.';
}

String _gateReasonDescription(GateReason? reason) {
  return switch (reason) {
    GateReason.muscleFatigue => 'Muscle fatigue is elevated',
    GateReason.acwrCaution => 'Training load is elevated (ACWR caution zone)',
    GateReason.acwrDanger => 'Training load is dangerously high (ACWR danger zone)',
    GateReason.lowReadiness => 'Readiness score is low',
    null => 'Safety gate triggered',
  };
}
