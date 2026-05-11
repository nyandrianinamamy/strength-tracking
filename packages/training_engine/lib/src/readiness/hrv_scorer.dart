import 'dart:math';
import '../models/hrv_record.dart';

/// Minimum number of records required to compute an HRV score.
const int _minRecords = 3;

/// Look-back window in days.
const int _windowDays = 14;

/// RHR trend window in days.
const int _rhrTrendDays = 7;

/// RHR rising penalty threshold (bpm increase over 7 days).
const double _rhrRisingThreshold = 5.0;

/// HRV readiness score plus notable threshold signals.
class HrvScoreDetails {
  final double score;
  final bool risingRestingHeartRate;

  const HrvScoreDetails({
    required this.score,
    required this.risingRestingHeartRate,
  });
}

// ---------------------------------------------------------------------------
// scoreHrv
// ---------------------------------------------------------------------------

/// Computes a 0–100 HRV readiness score from recent [HrvRecord] entries.
///
/// Returns `null` when fewer than [_minRecords] entries are available.
///
/// ### Algorithm
/// 1. Compute the 14-day rolling mean (μ) and standard deviation (σ) of SDNN.
/// 2. Evaluate today's SDNN (most recent record) relative to the baseline:
///    * Within ±0.5 SD  → score in 70–100
///    * Between -1 SD and -0.5 SD → score in 50–70
///    * Below -1 SD  → score in 20–50
///    * Above +1 SD  → score in 80–100
/// 3. Apply RHR trend modifier: if RHR rises > 5 bpm over the past 7 days,
///    subtract 10 points.
/// 4. Clamp result to [0, 100].
double? scoreHrv(List<HrvRecord> records, DateTime now) {
  return scoreHrvDetailed(records, now)?.score;
}

/// Computes an HRV readiness score and threshold flags from recent HRV/RHR data.
HrvScoreDetails? scoreHrvDetailed(List<HrvRecord> records, DateTime now) {
  if (records.length < _minRecords) return null;

  final today = DateTime.utc(now.year, now.month, now.day);

  // --- 14-day window ---
  final windowRecords = records.where((r) {
    final d = DateTime.utc(r.date.year, r.date.month, r.date.day);
    final daysAgo = today.difference(d).inDays;
    return daysAgo >= 0 && daysAgo < _windowDays;
  }).toList();

  if (windowRecords.length < _minRecords) return null;

  // --- Mean and SD of SDNN ---
  final sdnnValues = windowRecords.map((r) => r.sdnn).toList();
  final mean = sdnnValues.reduce((a, b) => a + b) / sdnnValues.length;
  final variance =
      sdnnValues.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
      sdnnValues.length;
  final sd = sqrt(variance);

  // --- Today's SDNN: most recent record ---
  final sorted = List<HrvRecord>.from(windowRecords)
    ..sort((a, b) => b.date.compareTo(a.date));
  final todaySdnn = sorted.first.sdnn;

  // --- Z-score based scoring ---
  double score;
  if (sd == 0.0) {
    // All values identical – treat as baseline
    score = 85.0;
  } else {
    final z = (todaySdnn - mean) / sd;

    if (z >= 1.0) {
      // Above +1 SD → 80–100, linear interpolation (cap at 100)
      score = (80.0 + (z - 1.0) * 20.0).clamp(80.0, 100.0);
    } else if (z >= -0.5) {
      // Within (-0.5, +1.0] → 70–100
      // Map: z = -0.5 → 70, z = 1.0 → 100
      score = 70.0 + (z + 0.5) / 1.5 * 30.0;
    } else if (z >= -1.0) {
      // Between -1.0 and -0.5 → 50–70
      score = 50.0 + (z + 1.0) / 0.5 * 20.0;
    } else {
      // Below -1 SD → 20–50
      score = (50.0 + (z + 1.0) * 30.0).clamp(20.0, 50.0);
    }
  }

  // --- RHR trend modifier ---
  final risingRestingHeartRate = _hasRisingRestingHeartRate(
    windowRecords,
    today,
  );
  if (risingRestingHeartRate) {
    score -= 10.0;
  }

  return HrvScoreDetails(
    score: score.clamp(0.0, 100.0),
    risingRestingHeartRate: risingRestingHeartRate,
  );
}

/// Returns true if RHR has risen more than [_rhrRisingThreshold] bpm over the
/// past [_rhrTrendDays] days.
bool _hasRisingRestingHeartRate(List<HrvRecord> records, DateTime today) {
  final withRhr = records.where((r) => r.restingHeartRate != null).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  if (withRhr.length < 2) return false;

  // Filter to records within the 7-day window only
  final cutoff = today.subtract(const Duration(days: _rhrTrendDays));
  final inWindow = withRhr.where((r) {
    final d = DateTime.utc(r.date.year, r.date.month, r.date.day);
    return !d.isBefore(cutoff);
  }).toList();

  if (inWindow.length < 2) return false;

  final earliestRhr = inWindow.first.restingHeartRate!;
  final latestRhr = inWindow.last.restingHeartRate!;

  return (latestRhr - earliestRhr) > _rhrRisingThreshold;
}
