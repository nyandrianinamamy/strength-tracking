import 'enums.dart';

class MuscleActivation {
  final String muscleId;
  final MuscleRole role;
  final double coefficient;

  MuscleActivation({
    required this.muscleId,
    required this.role,
    required this.coefficient,
  }) {
    if (coefficient < 0 || coefficient > 1) {
      throw ArgumentError(
        'coefficient must be between 0 and 1, got $coefficient',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'muscleId': muscleId,
    'role': role.name,
    'coefficient': coefficient,
  };

  factory MuscleActivation.fromJson(Map<String, dynamic> json) =>
      MuscleActivation(
        muscleId: json['muscleId'] as String,
        role: MuscleRole.values.byName(json['role'] as String),
        coefficient: (json['coefficient'] as num).toDouble(),
      );
}
