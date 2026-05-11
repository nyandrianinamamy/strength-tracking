/// Aggregated training load for one local calendar day.
///
/// Multiple workout sessions completed on the same local date are folded into
/// one [DailyLoad] before ACWR EWMA is recomputed.
class DailyLoad {
  /// Local calendar day for this aggregate load.
  final DateTime date;

  /// Sum of `weightKg * reps` across all completed sets on [date].
  final double volumeLoad;

  /// Optional session-RPE load summed across the same local calendar day.
  final double? sRpeLoad;

  const DailyLoad({
    required this.date,
    required this.volumeLoad,
    this.sRpeLoad,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'volumeLoad': volumeLoad,
    'sRpeLoad': sRpeLoad,
  };

  factory DailyLoad.fromJson(Map<String, dynamic> json) => DailyLoad(
    date: DateTime.parse(json['date'] as String),
    volumeLoad: (json['volumeLoad'] as num).toDouble(),
    sRpeLoad: (json['sRpeLoad'] as num?)?.toDouble(),
  );
}
