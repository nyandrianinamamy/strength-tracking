import '../models/enums.dart';

/// Parameters defining the target rep range and RPE for a given movement.
class TargetParams {
  final int targetRepsLow;
  final int targetRepsHigh;
  final double targetRpe;

  const TargetParams({
    required this.targetRepsLow,
    required this.targetRepsHigh,
    required this.targetRpe,
  });

  /// Returns default [TargetParams] for the given [MovementClass].
  factory TargetParams.defaultFor(MovementClass movement) =>
      switch (movement) {
        MovementClass.compoundLower =>
          const TargetParams(targetRepsLow: 6, targetRepsHigh: 10, targetRpe: 8.0),
        MovementClass.compoundUpper =>
          const TargetParams(targetRepsLow: 8, targetRepsHigh: 12, targetRpe: 8.0),
        MovementClass.isolation =>
          const TargetParams(targetRepsLow: 10, targetRepsHigh: 15, targetRpe: 8.5),
      };
}

/// Evaluates performance relative to targets.
///
/// - [progression]: reps >= [targetRepsHigh] AND rpe <= [targetRpe]
/// - [regression]: reps < ([targetRepsLow] ?? [targetRepsHigh] - 4) AND rpe >= 9.5
/// - [maintenance]: everything else
PerformanceDelta evaluateDelta({
  required int reps,
  required double rpe,
  required int targetRepsHigh,
  required double targetRpe,
  int? targetRepsLow,
}) {
  if (reps >= targetRepsHigh && rpe <= targetRpe) {
    return PerformanceDelta.progression;
  }

  final regressionThreshold = targetRepsLow ?? targetRepsHigh - 4;
  if (reps < regressionThreshold && rpe >= 9.5) {
    return PerformanceDelta.regression;
  }

  return PerformanceDelta.maintenance;
}
