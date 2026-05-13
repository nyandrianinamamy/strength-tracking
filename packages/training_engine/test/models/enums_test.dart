import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  group('Enums', () {
    test('MuscleRole has 3 values', () {
      expect(MuscleRole.values.length, 3);
    });

    test('MuscleSize has 3 values', () {
      expect(MuscleSize.values.length, 3);
    });

    test('EquipmentClass has 5 values', () {
      expect(EquipmentClass.values.length, 5);
    });

    test('MovementClass has 3 values', () {
      expect(MovementClass.values.length, 3);
    });

    test('Sex has 2 values', () {
      expect(Sex.values.length, 2);
    });

    test('ExperienceLevel has 3 values', () {
      expect(ExperienceLevel.values.length, 3);
    });

    test('HypertrophyGoal has 3 values', () {
      expect(HypertrophyGoal.values.length, 3);
    });

    test('RecoveryPhase has 3 values', () {
      expect(RecoveryPhase.values.length, 3);
    });

    test('ReadinessConfidence has 4 values', () {
      expect(ReadinessConfidence.values.length, 4);
    });

    test('AcwrZone has 4 values', () {
      expect(AcwrZone.values.length, 4);
    });

    test('AcwrTrend has 3 values', () {
      expect(AcwrTrend.values.length, 3);
    });

    test('PerformanceDelta has 3 values', () {
      expect(PerformanceDelta.values.length, 3);
    });

    test('ExerciseLoadKind has 5 values', () {
      expect(ExerciseLoadKind.values.length, 5);
    });

    test('LocalFatigueKind has 4 values', () {
      expect(LocalFatigueKind.values.length, 4);
    });

    test('IntensityClass has 4 values', () {
      expect(IntensityClass.values.length, 4);
    });
  });

  group('MuscleActivation', () {
    test('constructs with valid coefficient', () {
      final ma = MuscleActivation(
        muscleId: 'biceps',
        role: MuscleRole.primary,
        coefficient: 0.9,
      );
      expect(ma.muscleId, 'biceps');
      expect(ma.role, MuscleRole.primary);
      expect(ma.coefficient, 0.9);
    });

    test('throws ArgumentError for coefficient < 0', () {
      expect(
        () => MuscleActivation(
          muscleId: 'biceps',
          role: MuscleRole.primary,
          coefficient: -0.1,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for coefficient > 1', () {
      expect(
        () => MuscleActivation(
          muscleId: 'biceps',
          role: MuscleRole.primary,
          coefficient: 1.1,
        ),
        throwsArgumentError,
      );
    });

    test('JSON roundtrip', () {
      final ma = MuscleActivation(
        muscleId: 'quads',
        role: MuscleRole.synergist,
        coefficient: 0.5,
      );
      final json = ma.toJson();
      final restored = MuscleActivation.fromJson(json);
      expect(restored.muscleId, ma.muscleId);
      expect(restored.role, ma.role);
      expect(restored.coefficient, ma.coefficient);
    });
  });

  group('UserProfile', () {
    late UserProfile profile;

    setUp(() {
      profile = UserProfile(
        sex: Sex.male,
        age: 28,
        bodyWeightKg: 80.0,
        experience: ExperienceLevel.intermediate,
        goal: HypertrophyGoal.hypertrophy,
        availableDays: [1, 3, 5],
        maxSessionDuration: const Duration(hours: 1, minutes: 30),
        createdAt: DateTime(2026, 1, 1),
      );
    });

    test('constructs correctly', () {
      expect(profile.sex, Sex.male);
      expect(profile.age, 28);
      expect(profile.bodyWeightKg, 80.0);
      expect(profile.experience, ExperienceLevel.intermediate);
      expect(profile.goal, HypertrophyGoal.hypertrophy);
      expect(profile.availableDays, [1, 3, 5]);
      expect(profile.maxSessionDuration, const Duration(hours: 1, minutes: 30));
    });

    test('copyWith works', () {
      final updated = profile.copyWith(age: 30);
      expect(updated.age, 30);
      expect(updated.sex, profile.sex);
    });

    test('JSON roundtrip', () {
      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.sex, profile.sex);
      expect(restored.age, profile.age);
      expect(restored.bodyWeightKg, profile.bodyWeightKg);
      expect(restored.experience, profile.experience);
      expect(restored.goal, profile.goal);
      expect(restored.availableDays, profile.availableDays);
      expect(restored.maxSessionDuration, profile.maxSessionDuration);
      expect(restored.createdAt, profile.createdAt);
    });
  });
}
