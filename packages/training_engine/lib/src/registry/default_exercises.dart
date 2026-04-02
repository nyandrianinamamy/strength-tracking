import '../models/engine_exercise.dart';
import '../models/enums.dart';
import '../models/muscle_activation.dart';

/// The default exercise library shipped with the training engine.
/// Covers the major muscle groups with realistic activation coefficients.
final List<EngineExercise> defaultExercises = [
  // =========================================================================
  // CHEST (9)
  // =========================================================================
  EngineExercise(
    id: 'barbell_bench_press',
    name: 'Barbell Bench Press',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'serratus_anterior', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'dumbbell_bench_press',
    name: 'Dumbbell Bench Press',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'serratus_anterior', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'incline_barbell_bench',
    name: 'Incline Barbell Bench Press',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'serratus_anterior', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'incline_dumbbell_bench',
    name: 'Incline Dumbbell Bench Press',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'serratus_anterior', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'decline_bench_press',
    name: 'Decline Bench Press',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'serratus_anterior', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'cable_fly',
    name: 'Cable Fly',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'pec_deck',
    name: 'Pec Deck',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'dumbbell_fly',
    name: 'Dumbbell Fly',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'push_up',
    name: 'Push-Up',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'serratus_anterior', role: MuscleRole.stabilizer, coefficient: 0.2),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.compoundUpper,
  ),

  // =========================================================================
  // BACK (9)
  // =========================================================================
  EngineExercise(
    id: 'barbell_row',
    name: 'Barbell Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'dumbbell_row',
    name: 'Dumbbell Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'lat_pulldown',
    name: 'Lat Pulldown',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.3),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'cable_row',
    name: 'Cable Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'pull_up',
    name: 'Pull-Up',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.3),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'chin_up',
    name: 'Chin-Up',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.25),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 't_bar_row',
    name: 'T-Bar Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'barbell_deadlift',
    name: 'Barbell Deadlift',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'rack_pull',
    name: 'Rack Pull',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),

  // =========================================================================
  // SHOULDERS (8)
  // =========================================================================
  EngineExercise(
    id: 'overhead_press',
    name: 'Overhead Press',
    muscleMap: [
      MuscleActivation(muscleId: 'lateral_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'dumbbell_shoulder_press',
    name: 'Dumbbell Shoulder Press',
    muscleMap: [
      MuscleActivation(muscleId: 'lateral_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'lateral_raise',
    name: 'Lateral Raise',
    muscleMap: [
      MuscleActivation(muscleId: 'lateral_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'front_raise',
    name: 'Front Raise',
    muscleMap: [
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'lateral_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'face_pull',
    name: 'Face Pull',
    muscleMap: [
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.3),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'reverse_fly',
    name: 'Reverse Fly',
    muscleMap: [
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'cable_lateral_raise',
    name: 'Cable Lateral Raise',
    muscleMap: [
      MuscleActivation(muscleId: 'lateral_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'upright_row',
    name: 'Upright Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lateral_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),

  // =========================================================================
  // LEGS (12)
  // =========================================================================
  EngineExercise(
    id: 'barbell_back_squat',
    name: 'Barbell Back Squat',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
      MuscleActivation(muscleId: 'calves', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'front_squat',
    name: 'Front Squat',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.35),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.3),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'hack_squat',
    name: 'Hack Squat',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.35),
      MuscleActivation(muscleId: 'calves', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'goblet_squat',
    name: 'Goblet Squat',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.3),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'leg_press',
    name: 'Leg Press',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'leg_extension',
    name: 'Leg Extension',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'leg_curl',
    name: 'Leg Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'calves', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'romanian_deadlift',
    name: 'Romanian Deadlift',
    muscleMap: [
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'walking_lunge',
    name: 'Walking Lunge',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'calves', role: MuscleRole.stabilizer, coefficient: 0.2),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'bulgarian_split_squat',
    name: 'Bulgarian Split Squat',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'calf_raise',
    name: 'Standing Calf Raise',
    muscleMap: [
      MuscleActivation(muscleId: 'calves', role: MuscleRole.primary, coefficient: 1.0),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'seated_calf_raise',
    name: 'Seated Calf Raise',
    muscleMap: [
      MuscleActivation(muscleId: 'calves', role: MuscleRole.primary, coefficient: 1.0),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ARMS (9)
  // =========================================================================
  EngineExercise(
    id: 'barbell_curl',
    name: 'Barbell Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'dumbbell_curl',
    name: 'Dumbbell Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'hammer_curl',
    name: 'Hammer Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'preacher_curl',
    name: 'Preacher Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'cable_curl',
    name: 'Cable Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'tricep_pushdown',
    name: 'Tricep Pushdown',
    muscleMap: [
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'overhead_tricep_extension',
    name: 'Overhead Tricep Extension',
    muscleMap: [
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'skull_crusher',
    name: 'Skull Crusher',
    muscleMap: [
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'close_grip_bench',
    name: 'Close-Grip Bench Press',
    muscleMap: [
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  ),

  // =========================================================================
  // CORE (5)
  // =========================================================================
  EngineExercise(
    id: 'cable_crunch',
    name: 'Cable Crunch',
    muscleMap: [
      MuscleActivation(muscleId: 'core', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'hip_flexors', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'hanging_leg_raise',
    name: 'Hanging Leg Raise',
    muscleMap: [
      MuscleActivation(muscleId: 'core', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'hip_flexors', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'ab_wheel',
    name: 'Ab Wheel Rollout',
    muscleMap: [
      MuscleActivation(muscleId: 'core', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.stabilizer, coefficient: 0.25),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'plank',
    name: 'Plank',
    muscleMap: [
      MuscleActivation(muscleId: 'core', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.stabilizer, coefficient: 0.25),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'russian_twist',
    name: 'Russian Twist',
    muscleMap: [
      MuscleActivation(muscleId: 'core', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'hip_flexors', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // GLUTES (3 — standalone exercises for glute-focused sessions)
  // =========================================================================
  EngineExercise(
    id: 'hip_thrust',
    name: 'Barbell Hip Thrust',
    muscleMap: [
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.synergist, coefficient: 0.3),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'cable_kickback',
    name: 'Cable Kickback',
    muscleMap: [
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'sumo_deadlift',
    name: 'Sumo Deadlift',
    muscleMap: [
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),

  // =========================================================================
  // ADDITIONAL CHEST
  // =========================================================================
  EngineExercise(
    id: 'chest_dip',
    name: 'Chest Dip',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.compoundUpper,
  ),

  // =========================================================================
  // ADDITIONAL BACK
  // =========================================================================
  EngineExercise(
    id: 'seated_cable_row',
    name: 'Seated Cable Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'straight_arm_pulldown',
    name: 'Straight-Arm Pulldown',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.3),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ADDITIONAL LEGS
  // =========================================================================
  EngineExercise(
    id: 'step_up',
    name: 'Step-Up',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.6),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.35),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'nordic_curl',
    name: 'Nordic Hamstring Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.3),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.15),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ADDITIONAL ARMS
  // =========================================================================
  EngineExercise(
    id: 'concentration_curl',
    name: 'Concentration Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'diamond_push_up',
    name: 'Diamond Push-Up',
    muscleMap: [
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.compoundUpper,
  ),

  // =========================================================================
  // TRAPS / NECK
  // =========================================================================
  EngineExercise(
    id: 'barbell_shrug',
    name: 'Barbell Shrug',
    muscleMap: [
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'dumbbell_shrug',
    name: 'Dumbbell Shrug',
    muscleMap: [
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ADDITIONAL CORE
  // =========================================================================
  EngineExercise(
    id: 'cable_woodchop',
    name: 'Cable Woodchop',
    muscleMap: [
      MuscleActivation(muscleId: 'core', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.35),
      MuscleActivation(muscleId: 'hip_flexors', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ADDITIONAL CHEST
  // =========================================================================
  EngineExercise(
    id: 'machine_chest_press',
    name: 'Machine Chest Press',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'low_cable_fly',
    name: 'Low Cable Fly',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ADDITIONAL BACK
  // =========================================================================
  EngineExercise(
    id: 'wide_grip_pulldown',
    name: 'Wide-Grip Lat Pulldown',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'chest_supported_row',
    name: 'Chest-Supported Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundUpper,
  ),
  EngineExercise(
    id: 'single_arm_cable_row',
    name: 'Single-Arm Cable Row',
    muscleMap: [
      MuscleActivation(muscleId: 'lats', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.compoundUpper,
  ),

  // =========================================================================
  // ADDITIONAL SHOULDERS
  // =========================================================================
  EngineExercise(
    id: 'machine_lateral_raise',
    name: 'Machine Lateral Raise',
    muscleMap: [
      MuscleActivation(muscleId: 'lateral_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'cable_face_pull',
    name: 'Cable Face Pull',
    muscleMap: [
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ADDITIONAL LEGS
  // =========================================================================
  EngineExercise(
    id: 'sumo_squat',
    name: 'Sumo Squat',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.7),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'single_leg_press',
    name: 'Single-Leg Press',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.35),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.compoundLower,
  ),

  // =========================================================================
  // ADDITIONAL ARMS
  // =========================================================================
  EngineExercise(
    id: 'rope_pushdown',
    name: 'Rope Pushdown',
    muscleMap: [
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'incline_dumbbell_curl',
    name: 'Incline Dumbbell Curl',
    muscleMap: [
      MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.dumbbell,
    movement: MovementClass.isolation,
  ),

  // =========================================================================
  // ADDITIONAL TRAPS / UPPER BACK
  // =========================================================================
  EngineExercise(
    id: 'cable_shrug',
    name: 'Cable Shrug',
    muscleMap: [
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'forearms', role: MuscleRole.stabilizer, coefficient: 0.2),
    ],
    equipment: EquipmentClass.cable,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'reverse_pec_deck',
    name: 'Reverse Pec Deck',
    muscleMap: [
      MuscleActivation(muscleId: 'rear_deltoid', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'upper_trapezius', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.synergist, coefficient: 0.3),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.isolation,
  ),
  EngineExercise(
    id: 'good_morning',
    name: 'Good Morning',
    muscleMap: [
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),
  EngineExercise(
    id: 'trap_bar_deadlift',
    name: 'Trap Bar Deadlift',
    muscleMap: [
      MuscleActivation(muscleId: 'quadriceps', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'glutes', role: MuscleRole.synergist, coefficient: 0.7),
      MuscleActivation(muscleId: 'hamstrings', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'lats', role: MuscleRole.synergist, coefficient: 0.4),
      MuscleActivation(muscleId: 'core', role: MuscleRole.stabilizer, coefficient: 0.25),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  ),
];
