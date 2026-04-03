import '../models/enums.dart';

/// High-level exercise categories used for cold-start e1RM estimation.
/// These map exercise IDs to strength-to-bodyweight ratio tables.
enum ExerciseCategory { squat, bench, deadlift, row, overhead, isolation }

/// Categorizes an exercise by [exerciseId] using keyword matching.
///
/// Mapping rules (first match wins):
/// - Contains 'squat', 'leg_press', 'lunge', 'split_squat', 'step_up' → [ExerciseCategory.squat]
/// - Contains 'bench', 'chest_press', 'push_up', 'chest_dip' → [ExerciseCategory.bench]
/// - Contains 'deadlift', 'rdl', 'romanian', 'rack_pull', 'nordic' → [ExerciseCategory.deadlift]
/// - Contains 'row', 'pulldown', 'pull_up', 'chin_up', 'cable_row', 'seated_cable' → [ExerciseCategory.row]
/// - Contains 'overhead', 'shoulder_press', 'ohp' → [ExerciseCategory.overhead]
/// - Everything else → [ExerciseCategory.isolation]
ExerciseCategory categorizeExercise(String exerciseId) {
  final id = exerciseId.toLowerCase();

  // Squat pattern
  if (id.contains('squat') ||
      id.contains('leg_press') ||
      id.contains('lunge') ||
      id.contains('split_squat') ||
      id.contains('step_up')) {
    return ExerciseCategory.squat;
  }

  // Bench pattern
  if (id.contains('bench') ||
      id.contains('chest_press') ||
      id.contains('push_up') ||
      id.contains('chest_dip')) {
    return ExerciseCategory.bench;
  }

  // Deadlift pattern
  if (id.contains('deadlift') ||
      id.contains('rdl') ||
      id.contains('romanian') ||
      id.contains('rack_pull') ||
      id.contains('nordic')) {
    return ExerciseCategory.deadlift;
  }

  // Row / pull pattern
  if (id.contains('row') ||
      id.contains('pulldown') ||
      id.contains('pull_up') ||
      id.contains('chin_up') ||
      id.contains('cable_row') ||
      id.contains('seated_cable')) {
    return ExerciseCategory.row;
  }

  // Overhead / shoulder press pattern
  if (id.contains('overhead_press') ||
      id.contains('shoulder_press') ||
      id.contains('ohp') ||
      id.contains('overhead')) {
    return ExerciseCategory.overhead;
  }

  return ExerciseCategory.isolation;
}

/// Strength-to-bodyweight ratio table.
///
/// Conservative values that intentionally underestimate so the algorithm
/// can ramp up quickly from a safe starting load.
///
/// Keyed as [ExerciseCategory][Sex][ExperienceLevel].
const Map<ExerciseCategory, Map<Sex, Map<ExperienceLevel, double>>> _bwRatioTable = {
  ExerciseCategory.squat: {
    Sex.male: {
      ExperienceLevel.beginner: 0.75,
      ExperienceLevel.intermediate: 1.25,
      ExperienceLevel.advanced: 1.75,
    },
    Sex.female: {
      ExperienceLevel.beginner: 0.50,
      ExperienceLevel.intermediate: 0.85,
      ExperienceLevel.advanced: 1.25,
    },
  },
  ExerciseCategory.bench: {
    Sex.male: {
      ExperienceLevel.beginner: 0.50,
      ExperienceLevel.intermediate: 0.85,
      ExperienceLevel.advanced: 1.25,
    },
    Sex.female: {
      ExperienceLevel.beginner: 0.30,
      ExperienceLevel.intermediate: 0.50,
      ExperienceLevel.advanced: 0.75,
    },
  },
  ExerciseCategory.deadlift: {
    Sex.male: {
      ExperienceLevel.beginner: 0.85,
      ExperienceLevel.intermediate: 1.50,
      ExperienceLevel.advanced: 2.00,
    },
    Sex.female: {
      ExperienceLevel.beginner: 0.60,
      ExperienceLevel.intermediate: 1.00,
      ExperienceLevel.advanced: 1.50,
    },
  },
  ExerciseCategory.row: {
    Sex.male: {
      ExperienceLevel.beginner: 0.45,
      ExperienceLevel.intermediate: 0.75,
      ExperienceLevel.advanced: 1.10,
    },
    Sex.female: {
      ExperienceLevel.beginner: 0.30,
      ExperienceLevel.intermediate: 0.50,
      ExperienceLevel.advanced: 0.80,
    },
  },
  ExerciseCategory.overhead: {
    Sex.male: {
      ExperienceLevel.beginner: 0.35,
      ExperienceLevel.intermediate: 0.60,
      ExperienceLevel.advanced: 0.85,
    },
    Sex.female: {
      ExperienceLevel.beginner: 0.20,
      ExperienceLevel.intermediate: 0.40,
      ExperienceLevel.advanced: 0.60,
    },
  },
  ExerciseCategory.isolation: {
    Sex.male: {
      ExperienceLevel.beginner: 0.15,
      ExperienceLevel.intermediate: 0.25,
      ExperienceLevel.advanced: 0.40,
    },
    Sex.female: {
      ExperienceLevel.beginner: 0.10,
      ExperienceLevel.intermediate: 0.18,
      ExperienceLevel.advanced: 0.30,
    },
  },
};

/// Estimates a cold-start e1RM (kg) from demographic and category information.
///
/// Multiplies the strength-to-bodyweight ratio from [_bwRatioTable] by
/// [bodyWeightKg]. The result is intentionally conservative — the adaptive
/// algorithm will ramp up from a safe baseline.
double estimateBaselineE1rm({
  required ExerciseCategory category,
  required Sex sex,
  required ExperienceLevel experience,
  required double bodyWeightKg,
}) {
  final ratio = _bwRatioTable[category]![sex]![experience]!;
  return ratio * bodyWeightKg;
}
