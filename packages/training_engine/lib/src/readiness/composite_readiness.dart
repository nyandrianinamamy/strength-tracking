import '../models/enums.dart';
import '../acwr/acwr_classifier.dart';

// ---------------------------------------------------------------------------
// ReadinessTier
// ---------------------------------------------------------------------------

/// Describes which data sources were available when computing readiness.
enum ReadinessTier {
  /// All three sources: ACWR, sleep, and HRV.
  full,

  /// ACWR and sleep only (no HRV data).
  noHrv,

  /// ACWR and HRV only (no sleep data).
  noSleep,

  /// ACWR data only.
  acwrOnly,

  /// Manual slider only (no objective data).
  manualOnly,

  /// No objective data and no manual slider – cold start.
  cold,
}

// ---------------------------------------------------------------------------
// ReadinessFlag
// ---------------------------------------------------------------------------

/// Notable flags that should be surfaced to the user alongside the score.
enum ReadinessFlag {
  /// Last night's sleep was below 5 h.
  acuteSleepDeprivation,

  /// Resting heart rate has been rising over the past 7 days.
  risingRestingHR,

  /// ACWR is in the danger zone (ratio > 1.50).
  acwrDangerZone,

  /// Insufficient data to compute a meaningful readiness score.
  coldStart,
}

// ---------------------------------------------------------------------------
// ReadinessScore
// ---------------------------------------------------------------------------

/// The composite readiness score and associated metadata.
class ReadinessScore {
  /// Overall readiness score (0–100).
  final double score;

  /// Confidence level of the score.
  final ReadinessConfidence confidence;

  /// Tier used to produce the score.
  final ReadinessTier tier;

  /// Per-component scores for transparency (keys: 'acwr', 'sleep', 'hrv',
  /// 'manual').
  final Map<String, double> componentScores;

  /// Any notable flags that should be surfaced to the user.
  final List<ReadinessFlag> flags;

  const ReadinessScore({
    required this.score,
    required this.confidence,
    required this.tier,
    required this.componentScores,
    required this.flags,
  });
}

// ---------------------------------------------------------------------------
// ACWR zone -> score
// ---------------------------------------------------------------------------

/// Maps an [AcwrZone] to a 0–100 numeric score.
double _acwrZoneScore(AcwrZone zone) {
  switch (zone) {
    case AcwrZone.optimal:
      return 92.5; // midpoint of 85–100
    case AcwrZone.undertraining:
      return 60.0; // midpoint of 50–70
    case AcwrZone.caution:
      return 37.5; // midpoint of 25–50
    case AcwrZone.danger:
      return 12.5; // midpoint of 0–25
  }
}

// ---------------------------------------------------------------------------
// Manual slider -> score
// ---------------------------------------------------------------------------

/// Maps a manual wellness slider value (1–5) to a 0–100 score.
double _manualSliderScore(double slider) {
  final s = slider.clamp(1.0, 5.0);
  // Specified mapping: 1->10, 2->30, 3->55, 4->75, 5->95
  const breakpoints = <double>[1.0, 2.0, 3.0, 4.0, 5.0];
  const scores = <double>[10.0, 30.0, 55.0, 75.0, 95.0];

  for (var i = 0; i < breakpoints.length - 1; i++) {
    if (s <= breakpoints[i + 1]) {
      final t = (s - breakpoints[i]) / (breakpoints[i + 1] - breakpoints[i]);
      return scores[i] + t * (scores[i + 1] - scores[i]);
    }
  }
  return scores.last;
}

// ---------------------------------------------------------------------------
// computeReadiness
// ---------------------------------------------------------------------------

/// Computes a composite readiness score from the available data sources.
///
/// * [acwr]          – ACWR status (zone-based load metric).
/// * [sleepScore]    – 0–100 sleep score from [scoreSleep].
/// * [hrvScore]      – 0–100 HRV score from [scoreHrv].
/// * [manualSlider]  – User self-report on a 1–5 scale.
///
/// Returns a [ReadinessScore] with a blended score, confidence, tier,
/// per-component breakdowns, and any relevant flags.
ReadinessScore computeReadiness({
  AcwrStatus? acwr,
  double? sleepScore,
  double? hrvScore,
  double? manualSlider,
}) {
  final hasAcwr = acwr != null;
  final hasSleep = sleepScore != null;
  final hasHrv = hrvScore != null;
  final hasManual = manualSlider != null;

  final componentScores = <String, double>{};
  final flags = <ReadinessFlag>[];

  // -- Convert available sources to scores --
  double? acwrScoreValue;
  if (hasAcwr) {
    acwrScoreValue = _acwrZoneScore(acwr.zone);
    componentScores['acwr'] = acwrScoreValue;

    if (acwr.ratio > 1.50) {
      flags.add(ReadinessFlag.acwrDangerZone);
    }
  }

  double? manualScoreValue;
  if (hasManual) {
    manualScoreValue = _manualSliderScore(manualSlider);
    componentScores['manual'] = manualScoreValue;
  }

  if (hasSleep) componentScores['sleep'] = sleepScore;
  if (hasHrv) componentScores['hrv'] = hrvScore;

  // -- Determine tier --
  final ReadinessTier tier;
  if (hasAcwr && hasSleep && hasHrv) {
    tier = ReadinessTier.full;
  } else if (hasAcwr && hasSleep && !hasHrv) {
    tier = ReadinessTier.noHrv;
  } else if (hasAcwr && !hasSleep && hasHrv) {
    tier = ReadinessTier.noSleep;
  } else if (hasAcwr && !hasSleep && !hasHrv) {
    tier = ReadinessTier.acwrOnly;
  } else if (!hasAcwr && hasManual) {
    tier = ReadinessTier.manualOnly;
  } else {
    tier = ReadinessTier.cold;
  }

  // -- Cold start flag --
  if (!hasAcwr && !hasManual) {
    flags.add(ReadinessFlag.coldStart);
  }

  // -- Determine confidence --
  final ReadinessConfidence confidence;
  switch (tier) {
    case ReadinessTier.full:
      confidence = ReadinessConfidence.high;
      break;
    case ReadinessTier.noHrv:
    case ReadinessTier.noSleep:
      confidence = ReadinessConfidence.moderate;
      break;
    case ReadinessTier.acwrOnly:
    case ReadinessTier.manualOnly:
      confidence = ReadinessConfidence.low;
      break;
    case ReadinessTier.cold:
      confidence = ReadinessConfidence.unavailable;
      break;
  }

  // -- Build weight map for objective sources --
  final Map<String, double> weights = {};

  switch (tier) {
    case ReadinessTier.full:
      weights['acwr'] = 0.40;
      weights['sleep'] = 0.35;
      weights['hrv'] = 0.25;
      break;
    case ReadinessTier.noHrv:
      weights['acwr'] = 0.55;
      weights['sleep'] = 0.45;
      break;
    case ReadinessTier.noSleep:
      weights['acwr'] = 0.60;
      weights['hrv'] = 0.40;
      break;
    case ReadinessTier.acwrOnly:
      weights['acwr'] = 1.0;
      break;
    case ReadinessTier.manualOnly:
    case ReadinessTier.cold:
      // No objective sources
      break;
  }

  // -- Incorporate manual slider --
  double manualWeight = 0.0;
  if (hasManual) {
    final objectiveSources = weights.length;
    if (objectiveSources == 0) {
      manualWeight = 1.0;
    } else if (objectiveSources == 1) {
      manualWeight = 0.30;
    } else if (objectiveSources == 2) {
      manualWeight = 0.15;
    } else {
      manualWeight = 0.10;
    }
    weights['manual'] = manualWeight;
  }

  // -- Normalise weights to sum to 1.0 --
  final totalWeight = weights.values.fold(0.0, (s, w) => s + w);

  double score;
  if (totalWeight == 0.0) {
    // Truly cold start – no data
    score = 50.0;
  } else {
    score = 0.0;
    if (hasAcwr && weights.containsKey('acwr')) {
      score += (weights['acwr']! / totalWeight) * acwrScoreValue!;
    }
    if (hasSleep && weights.containsKey('sleep')) {
      score += (weights['sleep']! / totalWeight) * sleepScore;
    }
    if (hasHrv && weights.containsKey('hrv')) {
      score += (weights['hrv']! / totalWeight) * hrvScore;
    }
    if (hasManual && weights.containsKey('manual')) {
      score += (weights['manual']! / totalWeight) * manualScoreValue!;
    }
  }

  return ReadinessScore(
    score: score.clamp(0.0, 100.0),
    confidence: confidence,
    tier: tier,
    componentScores: componentScores,
    flags: flags,
  );
}
