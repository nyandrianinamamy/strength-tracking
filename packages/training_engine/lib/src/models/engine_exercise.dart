import 'enums.dart';
import 'muscle_activation.dart';

class EngineExercise {
  final String id;
  final String name;
  final List<MuscleActivation> muscleMap;
  final EquipmentClass equipment;
  final MovementClass movement;

  // New fields for timed cardio fatigue model
  final ExerciseLoadKind loadKind;
  final LocalFatigueKind localFatigueKind;
  final double defaultEffortRpe;
  final double defaultLocalRpe;
  final double cardioLocalMultiplier;
  final double metabolicMultiplier;
  final double localFatigueCap;

  const EngineExercise({
    required this.id,
    required this.name,
    required this.muscleMap,
    required this.equipment,
    required this.movement,
    this.loadKind = ExerciseLoadKind.resistanceDynamic,
    this.localFatigueKind = LocalFatigueKind.strengthVolume,
    this.defaultEffortRpe = 5.0,
    this.defaultLocalRpe = 7.0,
    this.cardioLocalMultiplier = 1.0,
    this.metabolicMultiplier = 1.0,
    this.localFatigueCap = 100.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleMap': muscleMap.map((m) => m.toJson()).toList(),
    'equipment': equipment.name,
    'movement': movement.name,
    'loadKind': loadKind.name,
    'localFatigueKind': localFatigueKind.name,
    'defaultEffortRpe': defaultEffortRpe,
    'defaultLocalRpe': defaultLocalRpe,
    'cardioLocalMultiplier': cardioLocalMultiplier,
    'metabolicMultiplier': metabolicMultiplier,
    'localFatigueCap': localFatigueCap,
  };

  factory EngineExercise.fromJson(Map<String, dynamic> json) => EngineExercise(
    id: json['id'] as String,
    name: json['name'] as String,
    muscleMap: (json['muscleMap'] as List)
        .map((m) => MuscleActivation.fromJson(m as Map<String, dynamic>))
        .toList(),
    equipment: EquipmentClass.values.byName(json['equipment'] as String),
    movement: MovementClass.values.byName(json['movement'] as String),
    loadKind: _parseLoadKind(json['loadKind']),
    localFatigueKind: _parseLocalFatigueKind(json['localFatigueKind']),
    defaultEffortRpe: (json['defaultEffortRpe'] as num?)?.toDouble() ?? 5.0,
    defaultLocalRpe: (json['defaultLocalRpe'] as num?)?.toDouble() ?? 7.0,
    cardioLocalMultiplier:
        (json['cardioLocalMultiplier'] as num?)?.toDouble() ?? 1.0,
    metabolicMultiplier:
        (json['metabolicMultiplier'] as num?)?.toDouble() ?? 1.0,
    localFatigueCap:
        (json['localFatigueCap'] as num?)?.toDouble() ??
        _defaultFatigueCap(json['localFatigueKind']),
  );

  static ExerciseLoadKind _parseLoadKind(dynamic value) {
    if (value == null) return ExerciseLoadKind.resistanceDynamic;
    try {
      return ExerciseLoadKind.values.byName(value as String);
    } catch (_) {
      return ExerciseLoadKind.resistanceDynamic;
    }
  }

  static LocalFatigueKind _parseLocalFatigueKind(dynamic value) {
    if (value == null) return LocalFatigueKind.strengthVolume;
    try {
      return LocalFatigueKind.values.byName(value as String);
    } catch (_) {
      return LocalFatigueKind.strengthVolume;
    }
  }

  static double _defaultFatigueCap(dynamic value) {
    // Legacy compatibility: if no localFatigueCap specified, infer from kind
    if (value == null) return 100.0;
    final kind = _parseLocalFatigueKind(value);
    switch (kind) {
      case LocalFatigueKind.cardioAerobicLocal:
        return 60.0;
      case LocalFatigueKind.isometricHold:
        return 85.0;
      case LocalFatigueKind.strengthVolume:
      case LocalFatigueKind.none:
        return 100.0;
    }
  }
}
