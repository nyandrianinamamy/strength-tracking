import 'package:test/test.dart';
import 'package:training_engine/src/e1rm/strength_baseline.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  group('categorizeExercise', () {
    // ---- Squat -----------------------------------------------------------
    test('barbell_back_squat → squat', () {
      expect(categorizeExercise('barbell_back_squat'), ExerciseCategory.squat);
    });
    test('front_squat → squat', () {
      expect(categorizeExercise('front_squat'), ExerciseCategory.squat);
    });
    test('hack_squat → squat', () {
      expect(categorizeExercise('hack_squat'), ExerciseCategory.squat);
    });
    test('goblet_squat → squat', () {
      expect(categorizeExercise('goblet_squat'), ExerciseCategory.squat);
    });
    test('leg_press → squat', () {
      expect(categorizeExercise('leg_press'), ExerciseCategory.squat);
    });
    test('walking_lunge → squat', () {
      expect(categorizeExercise('walking_lunge'), ExerciseCategory.squat);
    });
    test('bulgarian_split_squat → squat', () {
      expect(
        categorizeExercise('bulgarian_split_squat'),
        ExerciseCategory.squat,
      );
    });
    test('step_up → squat', () {
      expect(categorizeExercise('step_up'), ExerciseCategory.squat);
    });

    // ---- Bench -----------------------------------------------------------
    test('barbell_bench_press → bench', () {
      expect(
        categorizeExercise('barbell_bench_press'),
        ExerciseCategory.bench,
      );
    });
    test('incline_dumbbell_bench → bench', () {
      expect(
        categorizeExercise('incline_dumbbell_bench'),
        ExerciseCategory.bench,
      );
    });
    test('push_up → bench', () {
      expect(categorizeExercise('push_up'), ExerciseCategory.bench);
    });
    test('chest_dip → bench', () {
      expect(categorizeExercise('chest_dip'), ExerciseCategory.bench);
    });

    // ---- Deadlift --------------------------------------------------------
    test('barbell_deadlift → deadlift', () {
      expect(
        categorizeExercise('barbell_deadlift'),
        ExerciseCategory.deadlift,
      );
    });
    test('romanian_deadlift → deadlift', () {
      expect(
        categorizeExercise('romanian_deadlift'),
        ExerciseCategory.deadlift,
      );
    });
    test('rack_pull → deadlift', () {
      expect(categorizeExercise('rack_pull'), ExerciseCategory.deadlift);
    });
    test('sumo_deadlift → deadlift', () {
      expect(categorizeExercise('sumo_deadlift'), ExerciseCategory.deadlift);
    });
    test('nordic_curl → deadlift', () {
      expect(categorizeExercise('nordic_curl'), ExerciseCategory.deadlift);
    });

    // ---- Row -------------------------------------------------------------
    test('barbell_row → row', () {
      expect(categorizeExercise('barbell_row'), ExerciseCategory.row);
    });
    test('lat_pulldown → row', () {
      expect(categorizeExercise('lat_pulldown'), ExerciseCategory.row);
    });
    test('pull_up → row', () {
      expect(categorizeExercise('pull_up'), ExerciseCategory.row);
    });
    test('chin_up → row', () {
      expect(categorizeExercise('chin_up'), ExerciseCategory.row);
    });
    test('cable_row → row', () {
      expect(categorizeExercise('cable_row'), ExerciseCategory.row);
    });

    // ---- Overhead --------------------------------------------------------
    test('overhead_press → overhead', () {
      expect(
        categorizeExercise('overhead_press'),
        ExerciseCategory.overhead,
      );
    });
    test('dumbbell_shoulder_press → overhead', () {
      expect(
        categorizeExercise('dumbbell_shoulder_press'),
        ExerciseCategory.overhead,
      );
    });

    // ---- Isolation -------------------------------------------------------
    test('barbell_curl → isolation', () {
      expect(categorizeExercise('barbell_curl'), ExerciseCategory.isolation);
    });
    test('lateral_raise → isolation', () {
      expect(categorizeExercise('lateral_raise'), ExerciseCategory.isolation);
    });
    test('calf_raise → isolation', () {
      expect(categorizeExercise('calf_raise'), ExerciseCategory.isolation);
    });
    test('leg_curl → isolation (not a squat variant)', () {
      // "leg_curl" contains neither 'squat' nor 'leg_press' nor 'lunge' etc.
      expect(categorizeExercise('leg_curl'), ExerciseCategory.isolation);
    });
  });

  group('estimateBaselineE1rm', () {
    // ---- Table spot-checks -----------------------------------------------
    test('male beginner 80 kg squat → 60 kg', () {
      final result = estimateBaselineE1rm(
        category: ExerciseCategory.squat,
        sex: Sex.male,
        experience: ExperienceLevel.beginner,
        bodyWeightKg: 80.0,
      );
      // 0.75 × 80 = 60
      expect(result, closeTo(60.0, 0.001));
    });

    test('female intermediate bench at 65 kg → reasonable sub-BW value', () {
      final result = estimateBaselineE1rm(
        category: ExerciseCategory.bench,
        sex: Sex.female,
        experience: ExperienceLevel.intermediate,
        bodyWeightKg: 65.0,
      );
      // 0.50 × 65 = 32.5 — clearly sub-BW
      expect(result, closeTo(32.5, 0.001));
      expect(result, lessThan(65.0));
    });

    test('male advanced deadlift 90 kg bodyweight → 180 kg', () {
      final result = estimateBaselineE1rm(
        category: ExerciseCategory.deadlift,
        sex: Sex.male,
        experience: ExperienceLevel.advanced,
        bodyWeightKg: 90.0,
      );
      // 2.00 × 90 = 180
      expect(result, closeTo(180.0, 0.001));
    });

    test('female beginner overhead at 55 kg → 11 kg', () {
      final result = estimateBaselineE1rm(
        category: ExerciseCategory.overhead,
        sex: Sex.female,
        experience: ExperienceLevel.beginner,
        bodyWeightKg: 55.0,
      );
      // 0.20 × 55 = 11
      expect(result, closeTo(11.0, 0.001));
    });

    test('male intermediate row at 80 kg → 60 kg', () {
      final result = estimateBaselineE1rm(
        category: ExerciseCategory.row,
        sex: Sex.male,
        experience: ExperienceLevel.intermediate,
        bodyWeightKg: 80.0,
      );
      // 0.75 × 80 = 60
      expect(result, closeTo(60.0, 0.001));
    });

    test('female advanced isolation at 60 kg → 18 kg', () {
      final result = estimateBaselineE1rm(
        category: ExerciseCategory.isolation,
        sex: Sex.female,
        experience: ExperienceLevel.advanced,
        bodyWeightKg: 60.0,
      );
      // 0.30 × 60 = 18
      expect(result, closeTo(18.0, 0.001));
    });

    // ---- Conservative check ----------------------------------------------
    test('beginner baseline is always lower than advanced for same sex/BW', () {
      for (final cat in ExerciseCategory.values) {
        for (final sex in Sex.values) {
          const bw = 70.0;
          final beginner = estimateBaselineE1rm(
            category: cat,
            sex: sex,
            experience: ExperienceLevel.beginner,
            bodyWeightKg: bw,
          );
          final advanced = estimateBaselineE1rm(
            category: cat,
            sex: sex,
            experience: ExperienceLevel.advanced,
            bodyWeightKg: bw,
          );
          expect(
            beginner,
            lessThan(advanced),
            reason: 'beginner < advanced for $cat/$sex',
          );
        }
      }
    });

    test('result scales linearly with bodyweight', () {
      final at80 = estimateBaselineE1rm(
        category: ExerciseCategory.squat,
        sex: Sex.male,
        experience: ExperienceLevel.intermediate,
        bodyWeightKg: 80.0,
      );
      final at160 = estimateBaselineE1rm(
        category: ExerciseCategory.squat,
        sex: Sex.male,
        experience: ExperienceLevel.intermediate,
        bodyWeightKg: 160.0,
      );
      expect(at160, closeTo(at80 * 2, 0.001));
    });
  });
}
