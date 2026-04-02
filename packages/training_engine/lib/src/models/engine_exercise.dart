import 'enums.dart';
import 'muscle_activation.dart';

class EngineExercise {
  final String id;
  final String name;
  final List<MuscleActivation> muscleMap;
  final EquipmentClass equipment;
  final MovementClass movement;

  const EngineExercise({
    required this.id,
    required this.name,
    required this.muscleMap,
    required this.equipment,
    required this.movement,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleMap': muscleMap.map((m) => m.toJson()).toList(),
    'equipment': equipment.name,
    'movement': movement.name,
  };

  factory EngineExercise.fromJson(Map<String, dynamic> json) => EngineExercise(
    id: json['id'] as String,
    name: json['name'] as String,
    muscleMap: (json['muscleMap'] as List)
        .map((m) => MuscleActivation.fromJson(m as Map<String, dynamic>))
        .toList(),
    equipment: EquipmentClass.values.byName(json['equipment'] as String),
    movement: MovementClass.values.byName(json['movement'] as String),
  );
}
