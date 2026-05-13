enum MuscleRole { primary, synergist, stabilizer }

enum MuscleSize { small, moderate, large }

enum EquipmentClass { barbell, dumbbell, cable, machine, bodyweight }

enum MovementClass { compoundLower, compoundUpper, isolation }

enum Sex { male, female }

enum ExperienceLevel { beginner, intermediate, advanced }

enum HypertrophyGoal { hypertrophy, strength, general }

enum RecoveryPhase { acute, recovering, ready }

enum ReadinessConfidence { high, moderate, low, unavailable }

enum AcwrZone { undertraining, optimal, caution, danger }

enum AcwrTrend { rising, stable, falling }

enum PerformanceDelta { progression, maintenance, regression }

/// Classification of exercise load type for fatigue modeling.
enum ExerciseLoadKind {
  /// Dynamic resistance exercises (squat, bench, curl, etc.)
  resistanceDynamic,

  /// Static isometric holds (plank, wall sit, dead hang, etc.)
  timedIsometric,

  /// Steady-state cardio (treadmill, bike, elliptical, etc.)
  cardioSteady,

  /// Mixed cardio with upper body involvement (rowing, jump rope, stair climber)
  cardioMixed,

  /// Mobility, stretching, skill work
  mobilitySkill,
}

/// Type of local fatigue produced by an exercise.
enum LocalFatigueKind {
  /// Traditional strength volume fatigue (requires e1RM for normalization).
  strengthVolume,

  /// Isometric hold fatigue (duration-based, no e1RM).
  isometricHold,

  /// Local aerobic fatigue from cardio (capped, no e1RM).
  cardioAerobicLocal,

  /// No local muscle fatigue (mobility/skill work).
  none,
}

/// Intensity classification for non-strength exercises.
enum IntensityClass {
  easy, // RPE 0-3, light effort
  moderate, // RPE 4-6, comfortable but challenging
  hard, // RPE 7-8, vigorous effort
  veryHard, // RPE 9-10, maximal sustainable effort
}
