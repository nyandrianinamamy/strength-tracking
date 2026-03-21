class RoutineExercise {
  const RoutineExercise({
    required this.exerciseId,
    required this.targetSets,
    required this.targetReps,
    required this.restSeconds,
    required this.order,
    this.targetDurationSeconds = 60,
  });

  final String exerciseId;
  final int targetSets;
  final int targetReps;
  final int restSeconds;
  final int order;
  final int targetDurationSeconds;

  RoutineExercise copyWith({
    String? exerciseId,
    int? targetSets,
    int? targetReps,
    int? restSeconds,
    int? order,
    int? targetDurationSeconds,
  }) {
    return RoutineExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      restSeconds: restSeconds ?? this.restSeconds,
      order: order ?? this.order,
      targetDurationSeconds: targetDurationSeconds ?? this.targetDurationSeconds,
    );
  }

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      exerciseId: json['exerciseId'] as String,
      targetSets: json['targetSets'] as int,
      targetReps: json['targetReps'] as int,
      restSeconds: json['restSeconds'] as int,
      order: json['order'] as int,
      targetDurationSeconds: json['targetDurationSeconds'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'restSeconds': restSeconds,
      'order': order,
      'targetDurationSeconds': targetDurationSeconds,
    };
  }
}
