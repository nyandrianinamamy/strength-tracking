import '../models/enums.dart';
import '../models/ewma_state.dart';

// ---------------------------------------------------------------------------
// AcwrStatus
// ---------------------------------------------------------------------------

/// Snapshot of the current Acute:Chronic Workload Ratio.
class AcwrStatus {
  /// The raw ACWR value (acuteEwma / chronicEwma).
  final double ratio;

  /// Zone classification derived from [ratio].
  final AcwrZone zone;

  /// Acute EWMA at the time this status was computed.
  final double acuteEwma;

  /// Chronic EWMA at the time this status was computed.
  final double chronicEwma;

  /// Human-readable recommendation based on [zone].
  final String recommendation;

  const AcwrStatus({
    required this.ratio,
    required this.zone,
    required this.acuteEwma,
    required this.chronicEwma,
    required this.recommendation,
  });
}

// ---------------------------------------------------------------------------
// AcwrConfidenceLevel
// ---------------------------------------------------------------------------

/// Confidence level for the ACWR computation based on the days of data
/// available.
enum AcwrConfidenceLevel { low, full }

// ---------------------------------------------------------------------------
// Zone classification
// ---------------------------------------------------------------------------

/// Classifies an [AcwrStatus] from a raw [ratio]:
///
/// * < 0.80  → undertraining
/// * 0.80–1.30 → optimal
/// * 1.31–1.50 → caution
/// * > 1.50  → danger
AcwrStatus classifyAcwr(
  double ratio, {
  required double acuteEwma,
  required double chronicEwma,
}) {
  late AcwrZone zone;
  late String recommendation;

  if (ratio < 0.80) {
    zone = AcwrZone.undertraining;
    recommendation =
        'Your training load is low. Consider gradually increasing volume '
        'or intensity to build fitness.';
  } else if (ratio <= 1.30) {
    zone = AcwrZone.optimal;
    recommendation =
        'Your workload is well-balanced. Maintain current training stimulus '
        'for continued adaptation.';
  } else if (ratio <= 1.50) {
    zone = AcwrZone.caution;
    recommendation =
        'Training load is elevated. Monitor for early signs of overtraining '
        'and prioritise recovery.';
  } else {
    zone = AcwrZone.danger;
    recommendation =
        'Training load is dangerously high. Reduce volume immediately to '
        'lower injury risk.';
  }

  return AcwrStatus(
    ratio: ratio,
    zone: zone,
    acuteEwma: acuteEwma,
    chronicEwma: chronicEwma,
    recommendation: recommendation,
  );
}

// ---------------------------------------------------------------------------
// computeAcwr
// ---------------------------------------------------------------------------

/// Minimum chronic EWMA required to compute a meaningful ratio.
const double _minChronicThreshold = 1.0;

/// Computes the ACWR from an [EwmaState].
///
/// Returns `null` when [state.chronicEwma] is below the threshold (e.g. very
/// early in training) to avoid division by near-zero.
AcwrStatus? computeAcwr(EwmaState state) {
  if (state.chronicEwma < _minChronicThreshold) return null;

  final ratio = state.acuteEwma / state.chronicEwma;
  return classifyAcwr(
    ratio,
    acuteEwma: state.acuteEwma,
    chronicEwma: state.chronicEwma,
  );
}

// ---------------------------------------------------------------------------
// acwrConfidence
// ---------------------------------------------------------------------------

/// Returns the confidence level for the ACWR calculation based on [daysOfData].
///
/// * < 7  → `null` (insufficient data)
/// * 7–21 → [AcwrConfidenceLevel.low]
/// * > 21 → [AcwrConfidenceLevel.full]
AcwrConfidenceLevel? acwrConfidence(int daysOfData) {
  if (daysOfData < 7) return null;
  if (daysOfData <= 21) return AcwrConfidenceLevel.low;
  return AcwrConfidenceLevel.full;
}
