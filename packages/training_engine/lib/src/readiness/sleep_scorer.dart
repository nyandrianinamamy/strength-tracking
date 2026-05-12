import 'dart:math';
import '../models/sleep_record.dart';

// ---------------------------------------------------------------------------
// Targets
// ---------------------------------------------------------------------------

/// Minimum total sleep duration for a score of 0 penalty.
const Duration _minTargetSleep = Duration(hours: 7);

/// Maximum total sleep duration (above this does not add more score).
const Duration _maxTargetSleep = Duration(hours: 9);

/// Acute deprivation threshold (below this last-night value, subtract 20 pts).
const Duration _acuteDeprivationThreshold = Duration(hours: 5);

const double _deepSleepTargetRatio = 0.15; // 15% of total
const double _remSleepTargetRatio = 0.20; // 20% of total

/// Look-back window in days.
const int _windowDays = 14;

/// Sleep readiness score plus notable threshold signals.
class SleepScoreDetails {
  final double score;
  final bool acuteSleepDeprivation;

  const SleepScoreDetails({
    required this.score,
    required this.acuteSleepDeprivation,
  });
}

// ---------------------------------------------------------------------------
// Exponential decay weight
// ---------------------------------------------------------------------------

/// Exponential-decay weight for a record that is [daysAgo] days old.
/// Older nights receive lower weight; today (daysAgo = 0) receives weight 1.
double _weight(int daysAgo) => exp(-0.1 * daysAgo);

// ---------------------------------------------------------------------------
// scoreSleep
// ---------------------------------------------------------------------------

/// Computes a 0–100 sleep readiness score from the most recent 14 nights.
///
/// Returns `null` when [records] is empty.
///
/// ### Weighting
/// Each record within the 14-day window is weighted by exponential decay
/// (recent nights count more). The weighted average is then scored along three
/// components:
///
/// * **Total duration** (60%): scored 0–100 vs 7–9 h target window.
/// * **Deep sleep ratio** (25%): target ≥ 15% of total sleep.
/// * **REM sleep ratio** (15%): target ≥ 20% of total sleep.
///
/// ### Acute penalty
/// If the most recent night's total sleep is below 5 h, 20 points are
/// subtracted from the final score before clamping.
double? scoreSleep(List<SleepRecord> records, DateTime now) {
  return scoreSleepDetailed(records, now)?.score;
}

/// Computes a sleep readiness score and threshold flags from recent sleep data.
SleepScoreDetails? scoreSleepDetailed(List<SleepRecord> records, DateTime now) {
  if (records.isEmpty) return null;

  final today = DateTime.utc(now.year, now.month, now.day);

  // Filter to 14-day window and compute weighted averages
  double weightedDurationScore = 0.0;
  double weightedDeepRatio = 0.0;
  double weightedRemRatio = 0.0;
  double totalWeight = 0.0;
  final windowRecords = <SleepRecord>[];

  for (final record in records) {
    final recordDate = DateTime.utc(
      record.date.year,
      record.date.month,
      record.date.day,
    );
    final daysAgo = today.difference(recordDate).inDays;
    if (daysAgo < 0 || daysAgo >= _windowDays) continue;

    windowRecords.add(record);
    final w = _weight(daysAgo);
    totalWeight += w;

    // -- Total duration score (0-100) --
    final totalH = record.totalSleep.inSeconds / 3600.0;
    final minH = _minTargetSleep.inSeconds / 3600.0;
    final maxH = _maxTargetSleep.inSeconds / 3600.0;
    final durationScore =
        ((totalH - minH) / (maxH - minH)).clamp(0.0, 1.0) * 100.0;
    weightedDurationScore += w * durationScore;

    // -- Deep sleep ratio --
    final totalSec = record.totalSleep.inSeconds;
    final deepRatio = totalSec > 0
        ? record.deepSleep.inSeconds / totalSec
        : 0.0;
    weightedDeepRatio += w * deepRatio;

    // -- REM sleep ratio --
    final remRatio = totalSec > 0 ? record.remSleep.inSeconds / totalSec : 0.0;
    weightedRemRatio += w * remRatio;
  }

  if (totalWeight == 0.0) return null;

  final avgDurationScore = weightedDurationScore / totalWeight;
  final avgDeepRatio = weightedDeepRatio / totalWeight;
  final avgRemRatio = weightedRemRatio / totalWeight;

  // -- Deep sleep component (0-100) --
  final deepScore =
      (avgDeepRatio / _deepSleepTargetRatio).clamp(0.0, 1.0) * 100.0;

  // -- REM sleep component (0-100) --
  final remScore = (avgRemRatio / _remSleepTargetRatio).clamp(0.0, 1.0) * 100.0;

  // -- Composite --
  double score = 0.60 * avgDurationScore + 0.25 * deepScore + 0.15 * remScore;

  // -- Acute penalty --
  // Find the most recent record
  final sorted = List<SleepRecord>.from(windowRecords)
    ..sort((a, b) => b.date.compareTo(a.date));
  final lastNight = sorted.first;
  final acuteSleepDeprivation =
      lastNight.totalSleep < _acuteDeprivationThreshold;
  if (acuteSleepDeprivation) {
    score -= 20.0;
  }

  return SleepScoreDetails(
    score: score.clamp(0.0, 100.0),
    acuteSleepDeprivation: acuteSleepDeprivation,
  );
}
