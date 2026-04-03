class FatigueImpulse {
  final String muscleId;
  final double magnitude;
  final DateTime timestamp;

  const FatigueImpulse({
    required this.muscleId,
    required this.magnitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'muscleId': muscleId,
    'magnitude': magnitude,
    'timestamp': timestamp.toIso8601String(),
  };

  factory FatigueImpulse.fromJson(Map<String, dynamic> json) => FatigueImpulse(
    muscleId: json['muscleId'] as String,
    magnitude: (json['magnitude'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
