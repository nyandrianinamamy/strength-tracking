class E1rmEstimate {
  final String exerciseId;
  final double value;
  final double rMax;
  final double confidence;
  final DateTime estimatedAt;
  final bool fromEstimatedRpe;

  const E1rmEstimate({
    required this.exerciseId,
    required this.value,
    required this.rMax,
    required this.confidence,
    required this.estimatedAt,
    required this.fromEstimatedRpe,
  });

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'value': value,
    'rMax': rMax,
    'confidence': confidence,
    'estimatedAt': estimatedAt.toIso8601String(),
    'fromEstimatedRpe': fromEstimatedRpe,
  };

  factory E1rmEstimate.fromJson(Map<String, dynamic> json) => E1rmEstimate(
    exerciseId: json['exerciseId'] as String,
    value: (json['value'] as num).toDouble(),
    rMax: (json['rMax'] as num).toDouble(),
    confidence: (json['confidence'] as num).toDouble(),
    estimatedAt: DateTime.parse(json['estimatedAt'] as String),
    fromEstimatedRpe: json['fromEstimatedRpe'] as bool,
  );
}
