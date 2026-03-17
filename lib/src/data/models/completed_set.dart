class CompletedSet {
  const CompletedSet({
    required this.exerciseId,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.completedAt,
    required this.note,
  });

  final String exerciseId;
  final int setNumber;
  final double weightKg;
  final int reps;
  final DateTime completedAt;
  final String note;

  CompletedSet copyWith({
    String? exerciseId,
    int? setNumber,
    double? weightKg,
    int? reps,
    DateTime? completedAt,
    String? note,
  }) {
    return CompletedSet(
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }

  factory CompletedSet.fromJson(Map<String, dynamic> json) {
    return CompletedSet(
      exerciseId: json['exerciseId'] as String,
      setNumber: json['setNumber'] as int,
      weightKg: (json['weightKg'] as num).toDouble(),
      reps: json['reps'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'setNumber': setNumber,
      'weightKg': weightKg,
      'reps': reps,
      'completedAt': completedAt.toIso8601String(),
      'note': note,
    };
  }
}
