/// Aggregated training load for one local calendar day.
///
/// Multiple workout sessions completed on the same local date are folded into
/// one [DailyLoad] before ACWR EWMA is recomputed.
class DailyLoad {
  /// Local calendar day for this aggregate load.
  final DateTime date;

  /// Sum of `weightKg * reps` across all completed sets on [date].
  /// Legacy field - kept for backward compatibility.
  final double volumeLoad;

  /// Optional session-RPE load summed across the same local calendar day.
  final double? sRpeLoad;

  // New load point fields for comprehensive load tracking

  /// Strength-specific load points (normalized relative to e1RM).
  /// Used for ACWR calculations for strength training.
  final double strengthLoadPoints;

  /// Metabolic/systemic load points from cardio activities.
  /// Formula: minutes × effort × metabolicMultiplier
  final double metabolicLoadPoints;

  /// Isometric hold load points.
  /// Formula: minutes × localRpe × 0.5
  final double isometricLoadPoints;

  /// Overall combined load points for ACWR.
  /// This is the primary metric for ACWR calculations.
  /// For strength-focused days: primarily strengthLoadPoints
  /// For cardio-focused days: primarily metabolicLoadPoints
  /// For mixed days: weighted combination
  final double overallLoadPoints;

  const DailyLoad({
    required this.date,
    this.volumeLoad = 0.0,
    this.sRpeLoad,
    this.strengthLoadPoints = 0.0,
    this.metabolicLoadPoints = 0.0,
    this.isometricLoadPoints = 0.0,
    double? overallLoadPoints,
  }) : overallLoadPoints = overallLoadPoints ?? 0.0;

  /// Factory constructor that computes overallLoadPoints from components.
  factory DailyLoad.fromComponents({
    required DateTime date,
    double volumeLoad = 0.0,
    double? sRpeLoad,
    double strengthLoadPoints = 0.0,
    double metabolicLoadPoints = 0.0,
    double isometricLoadPoints = 0.0,
  }) {
    return DailyLoad(
      date: date,
      volumeLoad: volumeLoad,
      sRpeLoad: sRpeLoad,
      strengthLoadPoints: strengthLoadPoints,
      metabolicLoadPoints: metabolicLoadPoints,
      isometricLoadPoints: isometricLoadPoints,
      overallLoadPoints:
          strengthLoadPoints + metabolicLoadPoints + isometricLoadPoints,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'volumeLoad': volumeLoad,
    'sRpeLoad': sRpeLoad,
    'strengthLoadPoints': strengthLoadPoints,
    'metabolicLoadPoints': metabolicLoadPoints,
    'isometricLoadPoints': isometricLoadPoints,
    'overallLoadPoints': overallLoadPoints,
  };

  factory DailyLoad.fromJson(Map<String, dynamic> json) {
    final volumeLoad = (json['volumeLoad'] as num?)?.toDouble() ?? 0.0;
    final strengthLoad =
        (json['strengthLoadPoints'] as num?)?.toDouble() ?? 0.0;
    final metabolicLoad =
        (json['metabolicLoadPoints'] as num?)?.toDouble() ?? 0.0;
    final isometricLoad =
        (json['isometricLoadPoints'] as num?)?.toDouble() ?? 0.0;

    // Legacy compatibility: if overallLoadPoints not present, compute from legacy volumeLoad
    final overallFromJson = (json['overallLoadPoints'] as num?)?.toDouble();
    double overall;
    if (overallFromJson != null) {
      overall = overallFromJson;
    } else if (strengthLoad > 0 || metabolicLoad > 0 || isometricLoad > 0) {
      overall = strengthLoad + metabolicLoad + isometricLoad;
    } else {
      overall = volumeLoad;
    }

    return DailyLoad(
      date: DateTime.parse(json['date'] as String),
      volumeLoad: volumeLoad,
      sRpeLoad: (json['sRpeLoad'] as num?)?.toDouble(),
      strengthLoadPoints: strengthLoad,
      metabolicLoadPoints: metabolicLoad,
      isometricLoadPoints: isometricLoad,
      overallLoadPoints: overall,
    );
  }

  /// Backward compatibility: returns volumeLoad as the legacy load metric.
  /// New code should use overallLoadPoints for ACWR calculations.
  double get legacyVolumeLoad => volumeLoad;

  double get acwrLoad => overallLoadPoints > 0 ? overallLoadPoints : volumeLoad;
}
