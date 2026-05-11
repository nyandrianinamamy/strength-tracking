import '../e1rm/formulas.dart';

class LoggedSet {
  final String exerciseId;
  final double weightKg;
  final int reps;
  final double rpe;
  final DateTime completedAt;
  final bool rpeEstimated;
  final int durationSeconds;

  LoggedSet({
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    required this.rpe,
    required this.completedAt,
    this.rpeEstimated = false,
    this.durationSeconds = 0,
  }) {
    validateStrengthRpe(rpe);
    if (durationSeconds < 0) {
      throw ArgumentError(
        'durationSeconds must be non-negative, got $durationSeconds',
      );
    }
  }

  bool get hasStrengthLoad => reps > 0;

  bool get hasTimedLoad => durationSeconds > 0;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'weightKg': weightKg,
    'reps': reps,
    'rpe': rpe,
    'completedAt': completedAt.toIso8601String(),
    'rpeEstimated': rpeEstimated,
    if (durationSeconds > 0) 'durationSeconds': durationSeconds,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    exerciseId: json['exerciseId'] as String,
    weightKg: (json['weightKg'] as num).toDouble(),
    reps: json['reps'] as int,
    rpe: (json['rpe'] as num).toDouble(),
    completedAt: DateTime.parse(json['completedAt'] as String),
    rpeEstimated: json['rpeEstimated'] as bool? ?? false,
    durationSeconds: json['durationSeconds'] as int? ?? 0,
  );
}
