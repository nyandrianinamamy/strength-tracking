import '../models/daily_load.dart';
import '../models/ewma_state.dart';

// EWMA smoothing constants
// lambda = 2 / (N + 1)
const double _lambdaAcute = 2.0 / (7.0 + 1.0); // ≈ 0.25
const double _lambdaChronic = 2.0 / (28.0 + 1.0); // ≈ 0.0690

/// Returns the local calendar day represented by [date].
DateTime localCalendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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
  final todayDate = localCalendarDay(today);

  if (previous == null) {
    return EwmaState(
      acuteEwma: todayLoad,
      chronicEwma: todayLoad,
      lastComputedDate: todayDate,
    );
  }

  final lastDate = DateTime(
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

/// Aggregates load entries by local calendar day and returns them oldest-first.
List<DailyLoad> aggregateDailyLoads(
  Iterable<DailyLoad> loads, {
  DateTime? cutoff,
}) {
  final totals =
      <
        DateTime,
        ({
          double volumeLoad,
          double? sRpeLoad,
          double strengthLoadPoints,
          double metabolicLoadPoints,
          double isometricLoadPoints,
          double overallLoadPoints,
        })
      >{};
  for (final load in loads) {
    final day = localCalendarDay(load.date);
    final current = totals[day];
    totals[day] = (
      volumeLoad: (current?.volumeLoad ?? 0.0) + load.volumeLoad,
      sRpeLoad: load.sRpeLoad == null && current?.sRpeLoad == null
          ? null
          : (current?.sRpeLoad ?? 0.0) + (load.sRpeLoad ?? 0.0),
      strengthLoadPoints:
          (current?.strengthLoadPoints ?? 0.0) + load.strengthLoadPoints,
      metabolicLoadPoints:
          (current?.metabolicLoadPoints ?? 0.0) + load.metabolicLoadPoints,
      isometricLoadPoints:
          (current?.isometricLoadPoints ?? 0.0) + load.isometricLoadPoints,
      overallLoadPoints: (current?.overallLoadPoints ?? 0.0) + load.acwrLoad,
    );
  }

  final cutoffDay = cutoff == null ? null : localCalendarDay(cutoff);
  final result =
      totals.entries
          .where((entry) => cutoffDay == null || !entry.key.isBefore(cutoffDay))
          .map(
            (entry) => DailyLoad(
              date: entry.key,
              volumeLoad: entry.value.volumeLoad,
              sRpeLoad: entry.value.sRpeLoad,
              strengthLoadPoints: entry.value.strengthLoadPoints,
              metabolicLoadPoints: entry.value.metabolicLoadPoints,
              isometricLoadPoints: entry.value.isometricLoadPoints,
              overallLoadPoints: entry.value.overallLoadPoints,
            ),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  return result;
}

/// Recomputes EWMA from aggregated local-calendar-day loads.
EwmaState? recomputeEwmaFromDailyLoads(Iterable<DailyLoad> loads) {
  EwmaState? state;
  for (final load in aggregateDailyLoads(loads)) {
    state = updateEwma(
      previous: state,
      todayLoad: load.acwrLoad,
      today: load.date,
    );
  }
  return state;
}
