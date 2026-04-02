class CompletedSet {
  const CompletedSet({
    required this.exerciseId,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.completedAt,
    required this.note,
    this.durationSeconds = 0,
    this.rpe,
  });

  final String exerciseId;
  final int setNumber;
  final double weightKg;
  final int reps;
  final DateTime completedAt;
  final String note;
  final int durationSeconds;

  /// Per-set RPE (Rate of Perceived Exertion, 1–10 scale).
  /// Nullable for backward-compatibility with legacy data that has no per-set RPE.
  final double? rpe;

  CompletedSet copyWith({
    String? exerciseId,
    int? setNumber,
    double? weightKg,
    int? reps,
    DateTime? completedAt,
    String? note,
    int? durationSeconds,
    double? rpe,
    bool clearRpe = false,
  }) {
    return CompletedSet(
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rpe: clearRpe ? null : rpe ?? this.rpe,
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
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      rpe: (json['rpe'] as num?)?.toDouble(),
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
      'durationSeconds': durationSeconds,
      if (rpe != null) 'rpe': rpe,
    };
  }
}
