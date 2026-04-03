class LoggedSet {
  final String exerciseId;
  final double weightKg;
  final int reps;
  final double rpe;
  final DateTime completedAt;
  final bool rpeEstimated;

  LoggedSet({
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    required this.rpe,
    required this.completedAt,
    this.rpeEstimated = false,
  }) {
    if (rpe < 5 || rpe > 10) {
      throw ArgumentError('rpe must be between 5 and 10, got $rpe');
    }
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'weightKg': weightKg,
    'reps': reps,
    'rpe': rpe,
    'completedAt': completedAt.toIso8601String(),
    'rpeEstimated': rpeEstimated,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    exerciseId: json['exerciseId'] as String,
    weightKg: (json['weightKg'] as num).toDouble(),
    reps: json['reps'] as int,
    rpe: (json['rpe'] as num).toDouble(),
    completedAt: DateTime.parse(json['completedAt'] as String),
    rpeEstimated: json['rpeEstimated'] as bool? ?? false,
  );
}
