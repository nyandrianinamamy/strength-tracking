/// Predicts the training load for a target rep/RPE combination using the
/// inverse Epley formula.
///
/// Inverse Epley:
///   targetRMax = targetReps + (10 - targetRpe)
///   weight = e1rm / (1 + targetRMax / 30)
///
/// Example: e1RM=150, target 8 @ RPE 8
///   targetRMax = 8 + (10 - 8) = 10
///   weight = 150 / (1 + 10/30) = 150 / 1.333... ≈ 112.5
double predictLoad({
  required double e1rm,
  required int targetReps,
  required double targetRpe,
}) {
  final targetRMax = targetReps + (10.0 - targetRpe);
  return e1rm / (1 + targetRMax / 30);
}
