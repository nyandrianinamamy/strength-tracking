import 'package:test/test.dart';
import 'package:training_engine/src/fatigue/impulse_calculator.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  final sessionEnd = DateTime.utc(2026, 1, 1, 12);

  // Build a simple exercise with primary + synergist + stabilizer
  final exercise = EngineExercise(
    id: 'squat',
    name: 'Barbell Back Squat',
    muscleMap: [
      MuscleActivation(
        muscleId: 'quadriceps',
        role: MuscleRole.primary,
        coefficient: 1.0,
      ),
      MuscleActivation(
        muscleId: 'glutes',
        role: MuscleRole.synergist,
        coefficient: 0.6,
      ),
      MuscleActivation(
        muscleId: 'hamstrings',
        role: MuscleRole.stabilizer,
        coefficient: 0.3,
      ),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
  );

  final plank = EngineExercise(
    id: 'plank',
    name: 'Plank',
    muscleMap: [
      MuscleActivation(
        muscleId: 'core',
        role: MuscleRole.primary,
        coefficient: 1.0,
      ),
      MuscleActivation(
        muscleId: 'glutes',
        role: MuscleRole.stabilizer,
        coefficient: 0.2,
      ),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
  );

  // e1RM = 100 kg
  const e1rm = 100.0;

  // 4 sets x 10 reps @ 75 kg (75% e1RM) RPE 8
  List<LoggedSet> buildSets({
    int count = 4,
    double weightKg = 75.0,
    int reps = 10,
    double rpe = 8.0,
  }) => List.generate(
    count,
    (_) => LoggedSet(
      exerciseId: 'squat',
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      completedAt: sessionEnd,
    ),
  );

  group('calculateImpulses – stress distribution', () {
    test('primary muscle receives more stress than synergist', () {
      final impulses = calculateImpulses(
        sets: buildSets(),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');
      final glutes = impulses.firstWhere((i) => i.muscleId == 'glutes');
      final hams = impulses.firstWhere((i) => i.muscleId == 'hamstrings');

      expect(quads.magnitude, greaterThan(glutes.magnitude));
      expect(glutes.magnitude, greaterThan(hams.magnitude));
    });

    test('returns one impulse per muscle in muscleMap', () {
      final impulses = calculateImpulses(
        sets: buildSets(),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      expect(impulses.length, 3);
    });

    test('all impulse timestamps equal sessionEndedAt', () {
      final impulses = calculateImpulses(
        sets: buildSets(),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      for (final i in impulses) {
        expect(i.timestamp, sessionEnd);
      }
    });
  });

  group('calculateImpulses – RPE scaling', () {
    test('higher RPE produces higher magnitude (same volume)', () {
      final high = calculateImpulses(
        sets: buildSets(rpe: 10.0),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      final low = calculateImpulses(
        sets: buildSets(rpe: 7.0),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final highQuads = high.firstWhere((i) => i.muscleId == 'quadriceps');
      final lowQuads = low.firstWhere((i) => i.muscleId == 'quadriceps');

      expect(highQuads.magnitude, greaterThan(lowQuads.magnitude));
    });

    test('RPE ratio 10/7 is preserved proportionally in output', () {
      final high = calculateImpulses(
        sets: buildSets(rpe: 10.0),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      final low = calculateImpulses(
        sets: buildSets(rpe: 7.0),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final hq = high.firstWhere((i) => i.muscleId == 'quadriceps').magnitude;
      final lq = low.firstWhere((i) => i.muscleId == 'quadriceps').magnitude;

      // Both below cap so ratio should be 10/7
      if (hq < 100 && lq > 0) {
        expect(hq / lq, closeTo(10.0 / 7.0, 0.05));
      }
    });
  });

  group('calculateImpulses – typical hypertrophy session', () {
    test('4x10 @ RPE 8 at 75% e1RM yields F0 65-100 for primary', () {
      final impulses = calculateImpulses(
        sets: buildSets(count: 4, weightKg: 75.0, reps: 10, rpe: 8.0),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');
      expect(quads.magnitude, greaterThanOrEqualTo(65.0));
      expect(quads.magnitude, lessThanOrEqualTo(100.0));
    });
  });

  group('calculateImpulses – timed sets', () {
    test('duration-based plank stress creates core fatigue', () {
      final impulses = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            rpe: 7.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: plank,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final core = impulses.firstWhere((i) => i.muscleId == 'core');
      final glutes = impulses.firstWhere((i) => i.muscleId == 'glutes');

      expect(core.magnitude, greaterThan(0.0));
      expect(core.magnitude, greaterThan(glutes.magnitude));
    });

    test('longer timed sets produce more fatigue than shorter timed sets', () {
      List<FatigueImpulse> impulsesFor(int seconds) => calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: seconds,
            rpe: 7.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: plank,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final short = impulsesFor(30).firstWhere((i) => i.muscleId == 'core');
      final long = impulsesFor(90).firstWhere((i) => i.muscleId == 'core');

      expect(long.magnitude, greaterThan(short.magnitude));
    });
  });

  group('calculateImpulses – magnitude cap', () {
    test('magnitude is capped at 100 for extreme volume', () {
      // 20 sets x 15 reps @ RPE 10 at 100% e1RM is far above max
      final sets = List.generate(
        20,
        (_) => LoggedSet(
          exerciseId: 'squat',
          weightKg: 100.0,
          reps: 15,
          rpe: 10.0,
          completedAt: sessionEnd,
        ),
      );

      final impulses = calculateImpulses(
        sets: sets,
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      for (final i in impulses) {
        expect(i.magnitude, lessThanOrEqualTo(100.0));
        expect(i.magnitude, greaterThanOrEqualTo(0.0));
      }
    });

    test('magnitude is never negative', () {
      final impulses = calculateImpulses(
        sets: buildSets(rpe: 5.0, weightKg: 1.0, reps: 1),
        exercise: exercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      for (final i in impulses) {
        expect(i.magnitude, greaterThanOrEqualTo(0.0));
      }
    });
  });
}
