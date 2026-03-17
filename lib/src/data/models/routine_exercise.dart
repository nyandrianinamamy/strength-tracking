class RoutineExercise {
  const RoutineExercise({
    required this.exerciseId,
    required this.targetSets,
    required this.targetReps,
    required this.restSeconds,
    required this.order,
  });

  final String exerciseId;
  final int targetSets;
  final int targetReps;
  final int restSeconds;
  final int order;

  RoutineExercise copyWith({
    String? exerciseId,
    int? targetSets,
    int? targetReps,
    int? restSeconds,
    int? order,
  }) {
    return RoutineExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      restSeconds: restSeconds ?? this.restSeconds,
      order: order ?? this.order,
    );
  }

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      exerciseId: json['exerciseId'] as String,
      targetSets: json['targetSets'] as int,
      targetReps: json['targetReps'] as int,
      restSeconds: json['restSeconds'] as int,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'restSeconds': restSeconds,
      'order': order,
    };
  }
}
