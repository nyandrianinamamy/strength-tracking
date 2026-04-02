class HrvRecord {
  final DateTime date;
  final double sdnn;
  final double? restingHeartRate;

  const HrvRecord({
    required this.date,
    required this.sdnn,
    this.restingHeartRate,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'sdnn': sdnn,
    'restingHeartRate': restingHeartRate,
  };

  factory HrvRecord.fromJson(Map<String, dynamic> json) => HrvRecord(
    date: DateTime.parse(json['date'] as String),
    sdnn: (json['sdnn'] as num).toDouble(),
    restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble(),
  );
}
