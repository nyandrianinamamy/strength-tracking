import '../models/ewma_state.dart';

// EWMA smoothing constants
// lambda = 2 / (N + 1)
const double _lambdaAcute = 2.0 / (7.0 + 1.0); // ≈ 0.25
const double _lambdaChronic = 2.0 / (28.0 + 1.0); // ≈ 0.0690

/// Updates (or initialises) an [EwmaState] given a [todayLoad] on [today].
///
/// On first call (when [previous] is null) both EWMA values are seeded with
/// [todayLoad].
///
/// When there are skipped days between [previous.lastComputedDate] and [today],
/// the algorithm fast-forwards through those days using a load of 0 before
/// applying [todayLoad].
///
/// Formula applied each day:
///   ewma_new = lambda * load + (1 - lambda) * ewma_old
EwmaState updateEwma({
  EwmaState? previous,
  required double todayLoad,
  required DateTime today,
}) {
  // Normalise to UTC midnight for reliable day arithmetic
  final todayDate = DateTime.utc(today.year, today.month, today.day);

  if (previous == null) {
    return EwmaState(
      acuteEwma: todayLoad,
      chronicEwma: todayLoad,
      lastComputedDate: todayDate,
    );
  }

  final lastDate = DateTime.utc(
    previous.lastComputedDate.year,
    previous.lastComputedDate.month,
    previous.lastComputedDate.day,
  );

  double acute = previous.acuteEwma;
  double chronic = previous.chronicEwma;

  // Catch-up: iterate over any skipped days with load = 0
  final skippedDays = todayDate.difference(lastDate).inDays - 1;
  for (var i = 0; i < skippedDays; i++) {
    acute = _lambdaAcute * 0.0 + (1.0 - _lambdaAcute) * acute;
    chronic = _lambdaChronic * 0.0 + (1.0 - _lambdaChronic) * chronic;
  }

  // Apply today's load
  acute = _lambdaAcute * todayLoad + (1.0 - _lambdaAcute) * acute;
  chronic = _lambdaChronic * todayLoad + (1.0 - _lambdaChronic) * chronic;

  return EwmaState(
    acuteEwma: acute,
    chronicEwma: chronic,
    lastComputedDate: todayDate,
  );
}
